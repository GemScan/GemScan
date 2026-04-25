# Spec 02 — Inference Engine (GemmaKit)

GemmaKit is the shared Swift package that owns all on-device inference. It is linked by the main app target and by all iOS extensions.

---

## 1. Models

| Model | Role | Effective params | Q4_K_M RAM | First-token target | Decode target |
|---|---|---|---|---|---|
| Gemma 4 E2B | Always-on screening | 2.3 B | ≤ 1.8 GB | ≤ 400 ms | 15–25 tok/s |
| Gemma 4 E4B | Deep analysis (on demand) | 4.5 B | ≤ 3.2 GB | ≤ 900 ms | 8–15 tok/s |
| DistilBERT SMS Triage | Extension binary classifier | 66 M | ≤ 5 MB | ≤ 100 ms | N/A (single pass) |

### Hugging Face Artifact IDs

```
GemScan/gemma-4-e2b-it-GemScan-q4km.gguf        (~1.5 GB, llama.cpp fallback)
GemScan/gemma-4-e4b-it-GemScan-q4km.gguf        (~3.0 GB, llama.cpp fallback)
GemScan/gemma-4-e2b-it-GemScan-mlx-4bit         (MLX native, primary iOS runtime)
GemScan/gemma-4-e4b-it-GemScan-mlx-4bit         (MLX native + TurboQuant KV cache)
GemScan/sms-triage-distilbert.mlpackage          (Core ML, iOS SMS Filter extension)
```

---

## 2. GemmaKit Package Structure

```
ios/App/GemmaKit/Sources/
├── Inference/
│   ├── InferenceEngine.swift        # Public actor — the single entry point for all inference
│   ├── MLXInferenceBackend.swift    # MLX Swift implementation (primary on Apple Silicon)
│   ├── LlamaCppInferenceBackend.swift  # llama.cpp fallback
│   ├── ModelLoader.swift            # Download, verify, cache model weights
│   ├── ModelTier.swift              # Enum: .e2b | .e4b | .distilbert
│   ├── TokenStream.swift            # AsyncStream<String> wrapper for streaming tokens
│   └── GrammarConstraint.swift      # GBNF grammar loading and application
├── Agents/                          # See spec 03
├── MCP/                             # See spec 04
├── Router/                          # See spec 03
└── Extensions/                      # Extension bridges — see spec 05
```

---

## 3. InferenceEngine Actor

```swift
// ios/App/GemmaKit/Sources/Inference/InferenceEngine.swift

import Foundation
import os

public actor InferenceEngine {
    public static let shared = InferenceEngine()

    private var e2bBackend: InferenceBackend?
    private var e4bBackend: InferenceBackend?
    private let loader = ModelLoader()
    private let logger = Logger(subsystem: "com.gemscan", category: "InferenceEngine")

    // MARK: - Public API

    /// Load E2B on app launch. Call once from AppDelegate / SceneDelegate.
    public func warmUpE2B() async throws {
        guard e2bBackend == nil else { return }
        try checkMemory(required: ModelTier.e2b.expectedRAMBytes)
        e2bBackend = try await loader.load(tier: .e2b)
        logger.info("E2B loaded: \(ModelTier.e2b.expectedRAMBytes / 1_048_576) MB")
    }

    /// Load E4B on demand (called by Orchestrator when confidence < threshold).
    public func loadE4BIfNeeded() async throws {
        guard e4bBackend == nil else { return }
        try checkMemory(required: ModelTier.e4b.expectedRAMBytes)
        try checkThermal()
        e4bBackend = try await loader.load(tier: .e4b)
        logger.info("E4B loaded on demand")
    }

    /// Unload E4B to reclaim memory (called after analysis session ends).
    public func unloadE4B() {
        e4bBackend = nil
        logger.info("E4B unloaded")
    }

    /// Run inference. Streams tokens via the `onToken` callback.
    public func generate(
        prompt: String,
        grammar: GrammarConstraint?,
        tier: ModelTier,
        maxTokens: Int = 512,
        onToken: @escaping (String) -> Void
    ) async throws -> String {
        let backend = try backend(for: tier)
        let start = ContinuousClock.now

        let output = try await backend.generate(
            prompt: prompt,
            grammar: grammar,
            maxTokens: maxTokens,
            onToken: onToken
        )

        let latencyMs = Int(ContinuousClock.now - start, in: .milliseconds)
        logger.info("generate: tier=\(tier), latency=\(latencyMs)ms, tokens=\(output.split(separator: " ").count)")
        return output
    }

    // MARK: - Private

    private func backend(for tier: ModelTier) throws -> InferenceBackend {
        switch tier {
        case .e2b:
            guard let b = e2bBackend else { throw GemScanError.modelNotLoaded(tier: .e2b) }
            return b
        case .e4b:
            guard let b = e4bBackend else { throw GemScanError.modelNotLoaded(tier: .e4b) }
            return b
        case .distilbert:
            throw GemScanError.modelNotLoaded(tier: .distilbert) // DistilBERT has its own path
        }
    }

    private func checkMemory(required: Int) throws {
        let available = ProcessInfo.processInfo.physicalMemory - currentRSS()
        guard available > Int(Double(required) * 1.2) else {
            throw GemScanError.oomRejected(
                requestedBytes: required,
                availableBytes: Int(available)
            )
        }
    }

    private func checkThermal() throws {
        let state = ProcessInfo.processInfo.thermalState
        guard state < .serious else {
            logger.warning("Thermal state \(state.rawValue) — refusing E4B load")
            throw GemScanError.modelNotLoaded(tier: .e4b)
        }
    }

    private func currentRSS() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? info.resident_size : 0
    }
}
```

---

## 4. InferenceBackend Protocol

```swift
protocol InferenceBackend {
    func generate(
        prompt: String,
        grammar: GrammarConstraint?,
        maxTokens: Int,
        onToken: @escaping (String) -> Void
    ) async throws -> String
}
```

### MLXInferenceBackend

Primary backend on Apple Silicon. Uses `mlx-swift-examples`'s `LLMModelFactory`.

```swift
import MLX
import MLXNN
import MLXRandom

actor MLXInferenceBackend: InferenceBackend {
    private let model: LLMModel
    private let tokenizer: Tokenizer

    init(modelDirectory: URL) async throws {
        (model, tokenizer) = try await LLMModelFactory.load(
            directory: modelDirectory,
            dtype: .float16               // MLX 4-bit quantised weights
        )
    }

    func generate(
        prompt: String,
        grammar: GrammarConstraint?,
        maxTokens: Int,
        onToken: @escaping (String) -> Void
    ) async throws -> String {
        let tokens = tokenizer.encode(prompt)
        var output = ""
        for await token in model.generate(tokens: tokens, maxTokens: maxTokens) {
            let piece = tokenizer.decode([token])
            onToken(piece)
            output += piece
            if grammar?.accepts(output) == false { break }  // Grammar-constrained stop
        }
        return output
    }
}
```

### LlamaCppInferenceBackend

Fallback for simulator, older devices, or when MLX is unavailable. Wraps `llama.cpp` via a C-bridging header.

```swift
actor LlamaCppInferenceBackend: InferenceBackend {
    private let ctx: OpaquePointer    // llama_context*

    init(modelPath: URL, grammar: GrammarConstraint? = nil) throws {
        var params = llama_context_default_params()
        params.n_ctx = 4096
        params.n_batch = 512
        // Load model via llama.cpp C API
        let model = llama_load_model_from_file(modelPath.path, llama_model_default_params())
        guard let model else { throw GemScanError.modelNotLoaded(tier: .e2b) }
        guard let ctx = llama_new_context_with_model(model, params) else {
            throw GemScanError.modelNotLoaded(tier: .e2b)
        }
        self.ctx = ctx
    }

    func generate(prompt: String, grammar: GrammarConstraint?, maxTokens: Int, onToken: @escaping (String) -> Void) async throws -> String {
        // llama_tokenize → llama_decode → loop llama_sampling_sample
        // Apply GBNF grammar via llama_grammar_init if grammar != nil
        // Full implementation follows llama.cpp simple.cpp pattern
        fatalError("Implement via llama.cpp C bridge")
    }
}
```

---

## 5. Grammar-Constrained Decoding

All agent tool-call outputs are constrained with GBNF grammars generated from the JSON schema of each tool. This prevents hallucinated or malformed tool calls from quantised E2B.

```swift
// GrammarConstraint.swift
struct GrammarConstraint {
    let gbnf: String
    private let grammar: OpaquePointer   // llama_grammar*

    static func fromJSONSchema(_ schema: [String: Any]) -> GrammarConstraint {
        // Convert JSON Schema to GBNF string
        // Reference: llama.cpp/grammars/README.md conversion rules
        let gbnf = JSONSchemaToGBNF.convert(schema)
        return GrammarConstraint(gbnf: gbnf)
    }

    /// Enforce during decoding by passing grammar to llama_sampling_sample or MLX sampler
    func accepts(_ partial: String) -> Bool { /* GBNF incremental validation */ true }
}
```

---

## 6. ModelLoader

Handles download, SHA-256 verification, and local caching.

```swift
actor ModelLoader {
    private let cacheDirectory: URL = {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("GemScanModels")
    }()

    func load(tier: ModelTier) async throws -> InferenceBackend {
        let artifact = tier.preferredArtifact  // .mlx or .gguf depending on availability
        let localURL = cacheDirectory.appendingPathComponent(artifact.filename)

        if !FileManager.default.fileExists(atPath: localURL.path) {
            throw GemScanError.modelNotLoaded(tier: tier)  // Caller (onboarding) must download first
        }

        try verify(localURL, expectedSHA256: artifact.sha256)

        switch artifact.format {
        case .mlx:
            return try await MLXInferenceBackend(modelDirectory: localURL)
        case .gguf:
            return try LlamaCppInferenceBackend(modelPath: localURL)
        }
    }

    func download(tier: ModelTier, progress: @escaping (Double) -> Void) async throws {
        let artifact = tier.preferredArtifact
        let destination = cacheDirectory.appendingPathComponent(artifact.filename)
        try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        // Resume-capable download via URLSession with background configuration
        let session = URLSession(configuration: .background(withIdentifier: "com.gemscan.model-download"))
        try await session.download(from: artifact.remoteURL, to: destination, progress: progress)
        try verify(destination, expectedSHA256: artifact.sha256)
    }

    private func verify(_ url: URL, expectedSHA256: String) throws {
        let data = try Data(contentsOf: url)
        let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        guard hash == expectedSHA256 else {
            try? FileManager.default.removeItem(at: url)  // Delete corrupted file
            throw GemScanError.modelNotLoaded(tier: .e2b)  // Trigger re-download
        }
    }
}
```

---

## 7. Chat Template Verification

**The most common post-fine-tune bug is chat-template drift.** Before shipping any model artifact, run:

```python
# scripts/export/verify_chat_template.py
from transformers import AutoTokenizer
import subprocess, json

tokenizer = AutoTokenizer.from_pretrained("GemScan/gemma-4-e2b-it-GemScan-q4km")

messages = [
    {"role": "user", "content": "Is this SMS a scam? 'Your bank account is locked.'"}
]
python_output = tokenizer.apply_chat_template(
    messages, tokenize=False, add_generation_prompt=True
)

# Run the same through the on-device tokeniser via a test harness
# (Xcode unit test that outputs the tokenised string to stdout)
xcode_output = subprocess.check_output(
    ["xcodebuild", "test", "-scheme", "GemmaKitTests",
     "-only-testing", "GemmaKitTests/ChatTemplateTests/testTemplateMatchesPython",
     "TEST_INPUT=" + json.dumps(messages)],
    cwd="../ios/App"
).decode()

assert python_output.strip() in xcode_output, (
    f"Chat template mismatch!\nPython: {python_output}\nSwift: {xcode_output}"
)
print("✅ Chat template matches")
```

---

## 8. DistilBERT SMS Triage (Extension-Only Path)

DistilBERT runs **only** in the iOS SMS Filter extension. It is not part of `InferenceEngine` — it has its own tight, memory-constrained path.

```swift
// ios/App/Extensions/SMSFilter/SMSTriage.swift

import CoreML

class SMSTriage {
    private let model: SmsTriage   // Core ML generated class from GemScan/sms-triage-distilbert.mlpackage

    init() throws {
        let config = MLModelConfiguration()
        config.computeUnits = .cpuOnly  // Stay within 50 MB extension ceiling
        model = try SmsTriage(configuration: config)
    }

    /// Returns (isScam: Bool, confidence: Float) in ≤ 100 ms
    func classify(_ text: String) throws -> (isScam: Bool, confidence: Float) {
        let input = SmsTriage_Input(text: text)
        let output = try model.prediction(input: input)
        return (output.label == "scam", Float(output.labelProbability["scam"] ?? 0))
    }
}
```

---

## 9. Performance Monitoring Hooks

All inference calls must emit performance signals for the monitoring layer (see `specs/08_logging_and_monitoring.md`).

```swift
// Wrap every generate() call
let metrics = InferenceMetrics(tier: tier, taskId: task.id)
metrics.start()
let output = try await engine.generate(prompt: prompt, tier: tier, maxTokens: 512) { token in
    metrics.recordToken()
    onToken(token)
}
metrics.finish(outputLength: output.count)
MetricsCollector.shared.record(metrics)
```

`InferenceMetrics` must capture:
- `firstTokenLatencyMs` — time from `start()` to first `recordToken()` call
- `totalLatencyMs` — time from `start()` to `finish()`
- `tokensPerSecond` — computed from token count and total latency
- `peakRSSBytes` — sampled at `finish()`
- `modelTier` — e2b or e4b
- `escalated` — whether this call resulted from E2B→E4B escalation
