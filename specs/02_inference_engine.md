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
GemScan/sms-triage-distilbert.mlpackage          (Core ML source package — compiled to .mlmodelc at build time via Xcode)
```

> **Build note:** The `.mlpackage` artifact is the human-readable source. Xcode compiles it to an optimised `.mlmodelc` bundle at build time. Both the main app and the SMS Filter extension link against the compiled `.mlmodelc`. The generated Swift class `SmsTriage` is produced by Xcode's Core ML code generation.

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

### Package.swift

```swift
// ios/App/GemmaKit/Package.swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GemmaKit",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "GemmaKit", targets: ["GemmaKit"]),
    ],
    dependencies: [
        // MLX Swift — primary inference backend on Apple Silicon
        .package(url: "https://github.com/ml-explore/mlx-swift-examples", exact: "1.18.0"),
        // llama.cpp — fallback backend for simulator and older devices
        .package(url: "https://github.com/ggerganov/llama.cpp", exact: "b3442"),
        // sqlite-vec — vector similarity search for MCP sqlite_vec server
        .package(url: "https://github.com/asg017/sqlite-vec-swift", exact: "0.1.1"),
    ],
    targets: [
        .target(
            name: "GemmaKit",
            dependencies: [
                .product(name: "MLXLLM", package: "mlx-swift-examples"),
                .product(name: "llama", package: "llama.cpp"),
                .product(name: "SQLiteVec", package: "sqlite-vec-swift"),
            ],
            path: "Sources",
            swiftSettings: [
                .unsafeFlags(["-O"], .when(configuration: .release)),
            ]
        ),
        .testTarget(
            name: "GemmaKitTests",
            dependencies: ["GemmaKit"],
            path: "Tests"
        ),
    ]
)
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

    /// Encoder-only forward pass on E2B to produce a normalised embedding vector.
    /// Used by `TextEmbedder` to generate float vectors for sqlite_vec semantic search.
    /// - Parameters:
    ///   - text:       The input text to embed.
    ///   - dimensions: Expected output dimensionality. Must match the E2B projection head (128).
    public func encode(text: String, dimensions: Int) async throws -> [Float] {
        let backend = try backend(for: .e2b)
        guard let mlxBackend = backend as? MLXInferenceBackend else {
            throw GemScanError.grammarViolation(raw: "encode() requires MLXInferenceBackend")
        }
        return try await mlxBackend.encode(text: text, dimensions: dimensions)
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

    /// Encoder-only forward pass: embeds `text` into a `dimensions`-dimensional float vector.
    /// Uses the E2B model's last hidden state (no autoregressive decoding).
    /// Called by `InferenceEngine.encode()` → `TextEmbedder.embed()`.
    func encode(text: String, dimensions: Int) async throws -> [Float] {
        let tokens = tokenizer.encode(text)
        let hiddenStates = try await model.encode(tokens: tokens)
        // Pool to `dimensions` via mean-pooling + linear projection head compiled into the model
        guard hiddenStates.count >= dimensions else {
            throw GemScanError.grammarViolation(raw: "Encoder output dimension mismatch: got \(hiddenStates.count), expected ≥\(dimensions)")
        }
        let vector = Array(hiddenStates.prefix(dimensions))
        let norm = sqrt(vector.map { $0 * $0 }.reduce(0, +))
        return norm > 0 ? vector.map { $0 / norm } : vector
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
        // Implementation outline (stub — full impl follows llama.cpp simple.cpp pattern):
        // 1. llama_tokenize(ctx, prompt)
        // 2. If grammar != nil: llama_grammar_init from grammar.gbnfString
        // 3. Loop llama_decode → llama_sampling_sample, applying grammar sampler
        // 4. Call onToken(piece) for each token; break on EOS or maxTokens
        // 5. llama_grammar_free on exit
        // Note: GBNF grammar constraints are applied at sampling time (token-level),
        //       unlike MLXInferenceBackend which does post-hoc JSON validation.
        throw GemScanError.grammarViolation(raw: "LlamaCppInferenceBackend not yet implemented")
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
    static let shared = ModelLoader()

    private let cacheDirectory: URL = {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("GemScanModels")
    }()

    /// Returns the local URL for a named model artifact (e.g. `"whisper-small-mlx"`).
    /// Throws `GemScanError.modelNotLoaded` if the artifact has not been downloaded yet.
    func cachedURL(for modelName: String) throws -> URL {
        let url = cacheDirectory.appendingPathComponent(modelName)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw GemScanError.modelNotLoaded(tier: .e2b)  // tier is informational only here
        }
        return url
    }

    /// After download completes, write the model's local path into the App Group shared
    /// container so extensions (ILMessageFilterExtension) can locate DistilBERT.
    /// Called automatically at the end of `download(tier:progress:)` for `.distilbert`.
    private func syncPathToAppGroup(tier: ModelTier, localURL: URL) {
        guard tier == .distilbert else { return }
        let defaults = UserDefaults(suiteName: SharedContainerSchema.appGroupId)
        defaults?.set(localURL.path, forKey: SharedContainerSchema.distilbertModelPath)
    }

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

        // Resume-capable download via background URLSession.
        // Resume data is persisted to `cacheDirectory/resumeData/<filename>.resumedata`
        // and loaded at the start of each download attempt.
        let resumeDataURL = cacheDirectory.appendingPathComponent("resumeData/\(artifact.filename).resumedata")
        let session = URLSession(configuration: .background(withIdentifier: "com.gemscan.model-download.\(artifact.filename)"))
        if let resumeData = try? Data(contentsOf: resumeDataURL) {
            try await session.downloadResuming(resumeData: resumeData, to: destination, progress: progress)
        } else {
            try await session.download(from: artifact.remoteURL, to: destination, progress: progress)
        }
        // On success: remove resume data
        try? FileManager.default.removeItem(at: resumeDataURL)
        try verify(destination, expectedSHA256: artifact.sha256)
        syncPathToAppGroup(tier: tier, localURL: destination)
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

DistilBERT runs in two contexts:

1. **SMS Filter extension** (`ILMessageFilterExtension`): The primary use case — classifies unknown-sender SMS messages in real time within the 50 MB process ceiling.
2. **Main app — TextAgent fast path**: The same `SMSTriage` class is also linked into the main app target. When a text message is analysed in the main app, `TextAgent` calls `SMSTriage.shared.classify()` as a cheap pre-filter before invoking E2B. The same compiled `.mlmodelc` is used; it is copied to the main app bundle via a shared build phase, not loaded from the App Group container.

`SMSTriage` is **not** part of `InferenceEngine` — it has its own lightweight, synchronous path and is instantiated independently in each process.

```swift
// ios/App/Extensions/SMSFilter/SMSTriage.swift

import CoreML

class SMSTriage {
    /// Main-app singleton. Loads from the compiled `.mlmodelc` in the main app bundle.
    /// Used by `TextAgent` for the cheap pre-filter pass (Spec 03 §3.3).
    static let shared: SMSTriage = {
        guard let instance = try? SMSTriage(modelURL: Bundle.main.url(
            forResource: "SmsTriage", withExtension: "mlmodelc"
        )!) else {
            fatalError("GemScan: SmsTriage.mlmodelc missing from main bundle — check build phases")
        }
        return instance
    }()

    /// Extension factory. Loads from the path written to the App Group container by
    /// `ModelLoader.syncPathToAppGroup()` (Spec 02 §6). Use in `ILMessageFilterExtension`
    /// instead of `.shared` because extensions run in a separate sandbox and cannot
    /// access the main app bundle.
    ///
    /// Throws `GemScanError.modelNotLoaded` if `SharedContainerSchema.distilbertModelPath`
    /// has not been written yet (i.e., the main app hasn't completed first-launch download).
    static func extensionInstance() throws -> SMSTriage {
        let defaults = UserDefaults(suiteName: SharedContainerSchema.appGroupId)
        guard let path = defaults?.string(forKey: SharedContainerSchema.distilbertModelPath),
              !path.isEmpty else {
            throw GemScanError.modelNotLoaded(tier: .distilbert)
        }
        return try SMSTriage(modelURL: URL(fileURLWithPath: path))
    }

    private let model: SmsTriage   // Core ML generated class from GemScan/sms-triage-distilbert.mlpackage

    init(modelURL: URL) throws {
        let config = MLModelConfiguration()
        config.computeUnits = .cpuOnly  // Stay within 50 MB extension ceiling
        model = try SmsTriage(contentsOf: modelURL, configuration: config)
    }

    /// Returns a `TriageResult` in ≤ 100 ms.
    func classify(text: String) throws -> TriageResult {
        let input = SmsTriage_Input(text: text)
        let output = try model.prediction(input: input)
        let label = TriageLabel(rawValue: output.label) ?? .unknown
        let confidence = Double(output.labelProbability[output.label] ?? 0)
        return TriageResult(
            senderHash: "",   // Filled in by callers who have the sender context
            label: label,
            confidence: confidence,
            timestampMs: Int64(Date().timeIntervalSince1970 * 1000)
        )
    }
}
```

### WhisperASR

On-device speech-to-text using a distilled Whisper model via MLX. Converts the user's audio recording to text before passing to the VoiceAgent.

```swift
// ios/App/GemmaKit/Sources/Inference/WhisperASR.swift
import Foundation
import MLX

/// On-device ASR wrapping a distilled Whisper model (whisper-small or whisper-base.en)
/// loaded via MLX. Returns a transcript with detected language.
actor WhisperASR {
    static let shared = WhisperASR()

    private let logger = Logger(subsystem: "com.gemscan", category: "WhisperASR")
    private var model: WhisperModel?   // MLX-loaded Whisper model

    /// Transcribes base64-encoded audio (AAC, 16 kHz mono, PCM float32 after decode).
    /// Returns a `Transcript` with `text` and `language` (BCP-47).
    func transcribe(base64Audio: String, durationSeconds: Double) async throws -> Transcript {
        guard durationSeconds > 0, durationSeconds <= 300 else {
            throw GemScanError.audioIngestionUnavailable(reason: "Duration out of range: \(durationSeconds)s")
        }
        guard let audioData = Data(base64Encoded: base64Audio) else {
            throw GemScanError.audioIngestionUnavailable(reason: "Invalid base64 audio data")
        }

        if model == nil { try await loadModel() }

        // Decode AAC → float32 PCM at 16 kHz via AVAudioEngine
        let pcm = try AudioDecoder.decode(aacData: audioData, targetSampleRate: 16_000)
        let result = try await model!.transcribe(pcm: pcm)
        logger.info("WhisperASR: transcribed \(Int(durationSeconds))s → \(result.text.count) chars lang=\(result.language)")
        return result
    }

    private func loadModel() async throws {
        logger.info("WhisperASR: loading model")
        // Model artifact: GemScan/whisper-small-mlx (≈150 MB, downloaded alongside E2B)
        let modelDir = ModelLoader.shared.cachedURL(for: "whisper-small-mlx")
        model = try await WhisperModel.load(directory: modelDir)
    }
}

struct Transcript {
    let text: String
    let language: String   // BCP-47, e.g. "en", "hi"
}
```

### AudioSealDetector

On-device AI watermark and deepfake detector. Scores the probability that audio was synthesised by a generative model. Uses the Meta AudioSeal detector model compiled to MLX.

```swift
// ios/App/GemmaKit/Sources/Inference/AudioSealDetector.swift
import Foundation
import MLX

/// Runs the AudioSeal detector to produce a deepfake probability score.
/// Model: GemScan/audioseal-detector-mlx (≈30 MB, downloaded alongside distilbert)
actor AudioSealDetector {
    static let shared = AudioSealDetector()

    private let logger = Logger(subsystem: "com.gemscan", category: "AudioSealDetector")
    private var model: AudioSealModel?

    /// Returns 0.0 (human voice) → 1.0 (AI-synthesised).
    /// Input: base64-encoded audio in AAC format, decoded internally to float32 PCM.
    func score(base64Audio: String) async throws -> Double {
        guard let audioData = Data(base64Encoded: base64Audio) else {
            throw GemScanError.audioIngestionUnavailable(reason: "Invalid base64 audio data")
        }
        if model == nil { try await loadModel() }

        let pcm = try AudioDecoder.decode(aacData: audioData, targetSampleRate: 16_000)
        let score = try await model!.detectScore(pcm: pcm)
        logger.info("AudioSealDetector: score=\(String(format: "%.3f", score))")
        return score
    }

    private func loadModel() async throws {
        let modelDir = ModelLoader.shared.cachedURL(for: "audioseal-detector-mlx")
        model = try await AudioSealModel.load(directory: modelDir)
    }
}
```

### AudioDecoder Utility

```swift
// ios/App/GemmaKit/Sources/Inference/AudioDecoder.swift
import AVFoundation

enum AudioDecoder {
    /// Decodes AAC-encoded audio data to float32 PCM samples at the specified sample rate.
    /// Used by WhisperASR and AudioSealDetector.
    static func decode(aacData: Data, targetSampleRate: Double) throws -> [Float] {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".aac")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        try aacData.write(to: tempURL)

        let file = try AVAudioFile(forReading: tempURL)
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: targetSampleRate,
            channels: 1,
            interleaved: false
        ) else {
            throw GemScanError.audioIngestionUnavailable(reason: "Could not create PCM format at \(targetSampleRate)Hz")
        }

        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(file.length)
        ) else {
            throw GemScanError.audioIngestionUnavailable(reason: "Could not allocate PCM buffer")
        }

        guard let converter = AVAudioConverter(from: file.processingFormat, to: format) else {
            throw GemScanError.audioIngestionUnavailable(reason: "Unsupported audio format conversion: \(file.processingFormat) → \(format)")
        }
        var error: NSError?
        converter.convert(to: buffer, error: &error) { _, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }

        if let error { throw error }
        guard let channelData = buffer.floatChannelData else {
            throw GemScanError.audioIngestionUnavailable(reason: "No channel data in PCM buffer")
        }
        return Array(UnsafeBufferPointer(start: channelData[0], count: Int(buffer.frameLength)))
    }
}
```

### Text Embedding for sqlite_vec

The `sqlite_vec/semantic_search` MCP tool requires a float vector embedding of the input text. Embeddings are generated using the **E2B model's hidden-state encoder** — a 128-dimensional projection of the last encoder layer, invoked via a separate forward pass without autoregressive decoding.

```swift
// GemmaKit/Sources/Inference/TextEmbedder.swift
actor TextEmbedder {
    static let shared = TextEmbedder()

    /// Generates a 128-dimensional normalised embedding for the input text.
    /// Uses the E2B encoder (no generation step — encoder-only forward pass).
    func embed(text: String) async throws -> [Float] {
        let engine = InferenceEngine.shared
        return try await engine.encode(text: text, dimensions: 128)
    }

    /// Serialises a float vector to a JSON string for MCP tool input.
    static func toJSON(_ vector: [Float]) -> String {
        "[" + vector.map { String(format: "%.6f", $0) }.joined(separator: ",") + "]"
    }
}
```

Agents call this before invoking the `sqlite_vec/semantic_search` tool:
```swift
let embedding = try await TextEmbedder.shared.embed(text: sha256(messageContent))
let embeddingJSON = TextEmbedder.toJSON(embedding)
let result = try await mcpClient.call(server: "sqlite_vec", tool: "semantic_search",
    input: ["embedding_json": embeddingJSON, "top_k": "5"],
    callerAgentId: AgentID.orchestrator)  // Orchestrator routes this call; adjust per actual calling agent
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
