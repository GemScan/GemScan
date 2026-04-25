# Tasks — GemmaKit Inference Engine

> **Spec:** `specs/02_inference_engine.md` | **Milestone:** M2 — GemmaKit Inference Engine | **Depends on:** M0

## Milestone Summary
M2 implements the full on-device inference stack inside GemmaKit: the `InferenceEngine` public actor that agents call, both backends (`MLXInferenceBackend` for Apple Silicon and `LlamaCppInferenceBackend` as a llama.cpp fallback), `ModelLoader` for download and SHA-256-verified caching, and the four specialist inference components (`WhisperASR`, `AudioSealDetector`, `SMSTriage`, `TextEmbedder`) that back the voice and text agent fast paths. No agent logic is wired in M2 — this milestone is purely the inference primitives that M3 agents consume.

## Prerequisites
- `tasks/00_project_conventions.md` — M0 must be complete (`GemScanError`, `ModelTier`, `AgentTask`/`AgentResult` types, SwiftLint baseline)

## Progress Tracker
| Status | Count |
|--------|-------|
| ✅ Done | 22 |
| 🔄 In progress | 0 |
| ⬜ Not started | 0 |

Update this table as tasks complete. Each task row also has a status checkbox.

---

## Tasks

### Group: Package & Core Types

---

#### ✅ T-02-001 · GemmaKit Package.swift

| Field | Value |
|---|---|
| **Type** | SCAFFOLD |
| **Priority** | P0 (blocking) |
| **Spec ref** | §2 — GemmaKit Package Structure (Package.swift) |
| **Depends on** | T-00-001 |
| **Estimated effort** | S (< 1 hr) |
| **Files to create/modify** | `ios/App/GemmaKit/Package.swift` |

**What to build:**
Create `ios/App/GemmaKit/Package.swift` exactly as specified in Spec 02 §2. Set `swift-tools-version: 5.9`, `platforms: [.iOS(.v16)]`. Declare one library product `GemmaKit`. Add three package dependencies with exact version pins: `mlx-swift-examples` at `"1.18.0"` from `https://github.com/ml-explore/mlx-swift-examples`, `llama.cpp` at `"b3442"` from `https://github.com/ggerganov/llama.cpp`, and `sqlite-vec-swift` at `"0.1.1"` from `https://github.com/asg017/sqlite-vec-swift`. The `GemmaKit` target must link all three products: `MLXLLM` (from mlx-swift-examples), `llama` (from llama.cpp), and `SQLiteVec` (from sqlite-vec-swift). Set `path: "Sources"`. Add the release optimisation flag: `swiftSettings: [.unsafeFlags(["-O"], .when(configuration: .release))]`. Add a `GemmaKitTests` test target with `dependencies: ["GemmaKit"]` and `path: "Tests"`.

**Acceptance criteria:**
- [ ] `swift package resolve` in `ios/App/GemmaKit/` exits 0 and resolves all three dependencies
- [ ] `swift build -c release` in `ios/App/GemmaKit/` exits 0 on an empty `Sources/` directory with a stub Swift file
- [ ] `Package.swift` contains no `^` or range-based version specifiers — all versions use `.exact()`
- [ ] `swift package show-dependencies` lists `mlx-swift-examples`, `llama.cpp`, and `sqlite-vec-swift`

**Apple compliance (Spec 00 §11):**
- [ ] §11.4 — SPM only; no CocoaPods (per Spec 00 §10)
- [ ] §11.1 — `platforms: [.iOS(.v16)]` ensures the minimum deployment target is enforced at the package level

---

#### ✅ T-02-002 · ModelTier + GrammarConstraint

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P0 (blocking) |
| **Spec ref** | §5 — Grammar-Constrained Decoding; Spec 00 §4 — ModelTier Enum |
| **Depends on** | T-02-001, T-00-005 |
| **Estimated effort** | M (1–3 hr) |
| **Files to create/modify** | `ios/App/GemmaKit/Sources/Inference/ModelTier.swift`, `ios/App/GemmaKit/Sources/Inference/GrammarConstraint.swift` |

**What to build:**
`ModelTier.swift` already exists from T-00-005 in the Agents/ directory — move or extend it in `Sources/Inference/ModelTier.swift` with the `preferredArtifact` computed property that returns a `ModelArtifact` struct containing `filename: String`, `remoteURL: URL`, `sha256: String`, and `format: ArtifactFormat` (`.mlx` or `.gguf`). For `.e2b`, `preferredArtifact` returns the MLX artifact `GemScan/gemma-4-e2b-it-GemScan-mlx-4bit` if running on Apple Silicon (check `ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] == nil`), else the GGUF fallback. Create `ios/App/GemmaKit/Sources/Inference/GrammarConstraint.swift` with the `GrammarConstraint` struct as specified in Spec 02 §5: `let gbnf: String`, `private let grammar: OpaquePointer` (typed as `llama_grammar*`), `static func fromJSONSchema(_ schema: [String: Any]) -> GrammarConstraint` (calls a `JSONSchemaToGBNF.convert` helper that you implement with basic JSON Schema → GBNF conversion for `object`, `string`, `number`, `boolean` types), and `func accepts(_ partial: String) -> Bool` (returns `true` for MLX path — post-hoc validation; performs GBNF incremental check for llama.cpp path).

**Acceptance criteria:**
- [ ] `ModelTier.e2b.preferredArtifact.format` returns `.gguf` when `SIMULATOR_DEVICE_NAME` env var is set
- [ ] `ModelTier.e2b.preferredArtifact.format` returns `.mlx` on a real device (Apple Silicon)
- [ ] `GrammarConstraint.fromJSONSchema(["type": "object", "properties": ["verdict": ["type": "string"]]])` produces a non-empty `gbnf` string
- [ ] `GrammarConstraint.accepts("anything")` returns `true` on the MLX path (no-op validation)

**Apple compliance (Spec 00 §11):**
- [ ] §11.1 — `GrammarConstraint` stores an `OpaquePointer` (C pointer); verify its lifecycle in `deinit` calls `llama_grammar_free` to prevent memory leaks
- [ ] §11.2 — No memory leaks from `llama_grammar*` pointer (Instruments Leaks on grammar creation + disposal cycle)

---

### Group: Inference Backends

---

#### ✅ T-02-003 · InferenceBackend protocol + MLXInferenceBackend

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P0 (blocking) |
| **Spec ref** | §4 — InferenceBackend Protocol, MLXInferenceBackend |
| **Depends on** | T-02-001, T-02-002 |
| **Estimated effort** | L (3–6 hr) |
| **Files to create/modify** | `ios/App/GemmaKit/Sources/Inference/InferenceBackend.swift`, `ios/App/GemmaKit/Sources/Inference/MLXInferenceBackend.swift` |

**What to build:**
Create `ios/App/GemmaKit/Sources/Inference/InferenceBackend.swift` defining the `InferenceBackend` protocol with three method requirements: `generate(prompt:grammar:maxTokens:onToken:) async throws -> String`, `generateVision(imageBase64:textPrompt:grammar:maxTokens:onToken:) async throws -> String`, and `encode(text:dimensions:) async throws -> [Float]`. Create `ios/App/GemmaKit/Sources/Inference/MLXInferenceBackend.swift` as an `actor` conforming to `InferenceBackend`. The `init(modelDirectory: URL)` must call `LLMModelFactory.load(directory: modelDirectory, dtype: .float16)` from `MLXLLM`. Implement `generate()` with the token streaming loop from Spec 02 §4: `tokenizer.encode(prompt)` → `model.generate(tokens:maxTokens:)` async for-loop → `tokenizer.decode([token])` per token → `onToken(piece)` → break if `grammar?.accepts(output) == false`. Implement `generateVision()` validating the base64 image with `Data(base64Encoded:)` and calling `model.generateVision(imageData:textTokens:maxTokens:)`. Implement `encode()` with mean-pooling and L2-normalisation as in Spec 02 §4: take `hiddenStates.prefix(dimensions)`, compute `sqrt(sum(x^2))`, divide each element by norm.

**Acceptance criteria:**
- [ ] `MLXInferenceBackend` compiles as an `actor` (not a class or struct) — verified by `xcodebuild build`
- [ ] `generateVision()` throws `GemScanError.audioIngestionUnavailable(reason: "Invalid base64 image")` for invalid base64 input
- [ ] `encode()` returns a vector of exactly `dimensions` elements
- [ ] `encode()` returns a vector with L2-norm ≈ 1.0 (±0.001) — verified in T-02-014

**Apple compliance (Spec 00 §11):**
- [ ] §11.1 — `MLXInferenceBackend` is an `actor`; all mutable state (`model`, `tokenizer`) is actor-isolated; no `nonisolated` mutable variables
- [ ] §11.1 — `onToken` closure captured in `generate()` uses `@escaping` — verify no retain cycles with `[weak self]` if `self` is captured

---

#### ✅ T-02-004 · LlamaCppInferenceBackend

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P0 (blocking) |
| **Spec ref** | §4 — LlamaCppInferenceBackend (full generate() implementation) |
| **Depends on** | T-02-001, T-02-002 |
| **Estimated effort** | L (3–6 hr) |
| **Files to create/modify** | `ios/App/GemmaKit/Sources/Inference/LlamaCppInferenceBackend.swift` |

**What to build:**
Create `ios/App/GemmaKit/Sources/Inference/LlamaCppInferenceBackend.swift` as an `actor` conforming to `InferenceBackend`. In `init(modelPath: URL)`: call `llama_model_default_params()`, `llama_load_model_from_file(modelPath.path, mparams)` with `guard let m = ... else { throw GemScanError.modelNotLoaded(tier: .e2b) }`, then `llama_context_default_params()` with `cparams.n_ctx = 4096`, `cparams.n_batch = 512`, `llama_new_context_with_model(m, cparams)` with `guard let c`. Implement `deinit` calling `llama_free(ctx)` then `llama_free_model(model)`. Implement `generate()` exactly as in Spec 02 §4: (1) tokenize with `llama_tokenize`, (2) build sampler chain with `llama_sampler_chain_init`, insert grammar sampler first if `grammar != nil` via `llama_sampler_init_grammar(model, grammar.gbnf, "root")`, then `llama_sampler_init_temp(0.1)`, `llama_sampler_init_top_p(0.95, 1)`, `llama_sampler_init_greedy()`, (3) prefill batch with all prompt tokens requesting logits only for the last, (4) autoregressive decode loop using `llama_sampler_sample`, `llama_token_is_eog` stop check, `llama_token_to_piece`, and (5) `llama_kv_cache_clear(ctx)` at the end. `generateVision()` and `encode()` must throw `GemScanError.grammarViolation(raw: "LlamaCppInferenceBackend does not support this operation")`.

**Acceptance criteria:**
- [ ] `deinit` calls `llama_free(ctx)` and `llama_free_model(model)` — verified by Instruments Leaks showing zero leaks after backend init + deinit
- [ ] `generateVision()` throws `GemScanError.grammarViolation` (XCTest: `XCTAssertThrowsError`)
- [ ] Sampler chain inserts grammar sampler first when `grammar != nil` (XCTest: verify via log output or mock sampler)
- [ ] `llama_kv_cache_clear(ctx)` is called after every `generate()` call, even if it throws (use `defer`)

**Apple compliance (Spec 00 §11):**
- [ ] §11.1 — `model` and `ctx` are `OpaquePointer` properties on an `actor`; no unsynchronised access possible
- [ ] §11.2 — `deinit` frees both C pointers; Instruments Leaks confirms zero leaks on init/deinit cycle
- [ ] §11.1 — No force-unwraps; all `llama_*` functions with nullable returns use `guard let`

---

### Group: Model Loading

---

#### ✅ T-02-005 · ModelLoader actor

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P0 (blocking) |
| **Spec ref** | §6 — ModelLoader (full implementation) |
| **Depends on** | T-02-002 |
| **Estimated effort** | L (3–6 hr) |
| **Files to create/modify** | `ios/App/GemmaKit/Sources/Inference/ModelLoader.swift` |

**What to build:**
Create `ios/App/GemmaKit/Sources/Inference/ModelLoader.swift` as an `actor` with `static let shared = ModelLoader()`. Implement `cacheDirectory` as `FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("GemScanModels")`. Implement all public methods from Spec 02 §6: `isDownloadedByName(_ modelName: String) throws -> Bool` (check file exists and has size > 0), `downloadByName(_ modelName: String, progress: @escaping (Double) -> Void) async throws` (look up signed manifest, create background URLSession with identifier `"com.gemscan.model-download.\(modelName)"`, download to `cacheDirectory/modelName`, call `verify`), `isDownloaded(tier: ModelTier) throws -> Bool` (check `tier.preferredArtifact.filename` file exists and has size > 0), `cachedURL(for modelName: String) throws -> URL` (return URL or throw `modelNotLoaded`), `load(tier: ModelTier) async throws -> InferenceBackend` (dispatch to `MLXInferenceBackend` for `.mlx` format, `LlamaCppInferenceBackend` for `.gguf`, call `verify` before loading), `download(tier: ModelTier, progress: @escaping (Double) -> Void) async throws` (resume-capable background URLSession, load resume data from `resumeData/<filename>.resumedata`, save on suspend, delete on success, call `syncPathToAppGroup` for `.distilbert`), and `private func verify(_ url: URL, expectedSHA256: String) throws` using `CryptoKit.SHA256.hash(data:)` — delete the file and throw `modelNotLoaded` on mismatch.

**Acceptance criteria:**
- [ ] `isDownloadedByName("whisper-small-mlx")` returns `false` when the file does not exist (XCTest)
- [ ] `verify()` deletes the file and throws when SHA-256 doesn't match (XCTest: write 4 bytes to a temp file, call verify with wrong hash, assert file is deleted)
- [ ] `syncPathToAppGroup(tier: .distilbert, localURL:)` writes the path to `UserDefaults(suiteName: SharedContainerSchema.appGroupId)` under `SharedContainerSchema.distilbertModelPath` (XCTest)
- [ ] `load(tier: .e2b)` throws `GemScanError.modelNotLoaded(tier: .e2b)` when the file is absent (XCTest)

**Apple compliance (Spec 00 §11):**
- [ ] §11.2 — Background URLSession with identifier `"com.gemscan.model-download.*"` used for all downloads; no foreground URLSession for model weights
- [ ] §11.4 — Background download modes declared in `Info.plist` (`background-processing`)
- [ ] §11.6 — `syncPathToAppGroup` uses `UserDefaults(suiteName:)` with App Group ID, never `UserDefaults.standard` (SwiftLint `no_nsuserdefaults_direct` rule)

---

### Group: InferenceEngine Actor

---

#### ✅ T-02-006 · InferenceEngine actor

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P0 (blocking) |
| **Spec ref** | §3 — InferenceEngine Actor (full implementation) |
| **Depends on** | T-02-003, T-02-004, T-02-005 |
| **Estimated effort** | L (3–6 hr) |
| **Files to create/modify** | `ios/App/GemmaKit/Sources/Inference/InferenceEngine.swift` |

**What to build:**
Create `ios/App/GemmaKit/Sources/Inference/InferenceEngine.swift` as `public actor InferenceEngine` with `public static let shared = InferenceEngine()`. Declare private state: `private var e2bBackend: InferenceBackend?`, `private var e4bBackend: InferenceBackend?`, `private let loader = ModelLoader()`, `private let logger = Logger(subsystem: "com.gemscan", category: "InferenceEngine")`. Implement all public methods exactly as in Spec 02 §3: `warmUpE2B()` (guard e2bBackend == nil, checkMemory, loader.load(.e2b)), `loadE4BIfNeeded()` (guard e4bBackend == nil, checkMemory, checkThermal, download if !isDownloaded, loader.load(.e4b)), `unloadE4B()` (set e4bBackend = nil), `generate(prompt:grammar:tier:maxTokens:onToken:)` (call `backend(for: tier)`, measure latency with `ContinuousClock.now`, log tier + latency + token count), `generateVision(imageBase64:textPrompt:grammar:task:maxTokens:onToken:)` (loadE4BIfNeeded, guard MLXInferenceBackend cast, measure latency), `encode(text:dimensions:)` (guard MLXInferenceBackend cast), `isMLXAvailable: Bool { e2bBackend is MLXInferenceBackend }`. Implement private helpers `backend(for:)`, `checkMemory(required:)` (query `ProcessInfo.processInfo.physicalMemory - currentRSS()`, require 1.2× headroom), `checkThermal()` (reject if `thermalState >= .serious`), and `currentRSS()` using `mach_task_basic_info` as specified.

**Acceptance criteria:**
- [ ] `warmUpE2B()` called twice does not load the backend twice (guard `e2bBackend == nil` prevents double-load)
- [ ] `generateVision()` throws `GemScanError.grammarViolation` when `e4bBackend` is a `LlamaCppInferenceBackend` (XCTest: inject mock llama.cpp backend)
- [ ] `checkThermal()` throws `GemScanError.modelNotLoaded(tier: .e4b)` when `thermalState >= .serious` (XCTest: mock `ProcessInfo`)
- [ ] `isMLXAvailable` returns `false` when `e2bBackend` is `LlamaCppInferenceBackend` (XCTest)
- [ ] `generate()` logs `"generate: tier=e2b, latency=…ms, tokens=…"` at `.info` level (XCTest: capture Logger output)

**Apple compliance (Spec 00 §11):**
- [ ] §11.1 — `InferenceEngine` is an `actor`; `e2bBackend` and `e4bBackend` are actor-isolated; no `nonisolated(unsafe)` usage
- [ ] §11.2 — `checkMemory(required:)` enforces 1.2× headroom rule before every model load; OOM rejection logged at `.warning`
- [ ] §11.1 — `currentRSS()` uses `mach_task_basic_info` without force-unwraps; returns 0 on failure

---

### Group: Audio Components

---

#### ✅ T-02-007 · AudioDecoder

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P1 (high) |
| **Spec ref** | §8 — AudioDecoder Utility |
| **Depends on** | T-00-006 |
| **Estimated effort** | M (1–3 hr) |
| **Files to create/modify** | `ios/App/GemmaKit/Sources/Inference/AudioDecoder.swift` |

**What to build:**
Create `ios/App/GemmaKit/Sources/Inference/AudioDecoder.swift` as an `enum AudioDecoder` with one static method `decode(aacData: Data, targetSampleRate: Double) throws -> [Float]`. Implement exactly as in Spec 02 §8: write `aacData` to a temp file at `FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".aac")` with a `defer { try? FileManager.default.removeItem(at: tempURL) }` cleanup, open with `AVAudioFile(forReading:)`, create `AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: targetSampleRate, channels: 1, interleaved: false)` using `guard let` with a descriptive `GemScanError.audioIngestionUnavailable(reason:)` throw, allocate `AVAudioPCMBuffer` using `guard let`, create `AVAudioConverter(from: file.processingFormat, to: format)` using `guard let`, call `converter.convert(to:error:inputBlock:)`, check `NSError?`, and extract `buffer.floatChannelData![0]` into a `[Float]` array via `UnsafeBufferPointer`. All four `guard let` points must use descriptive error messages for `audioIngestionUnavailable`.

**Acceptance criteria:**
- [ ] `AudioDecoder.decode(aacData: invalidData, targetSampleRate: 16_000)` throws `GemScanError.audioIngestionUnavailable` (XCTest with random bytes as input)
- [ ] The temp file is deleted after `decode()` completes, even when an error is thrown (XCTest: verify temp file absent after call)
- [ ] Zero force-unwraps in `AudioDecoder.swift` — `swiftlint lint` `force_unwrapping` rule passes
- [ ] `floatChannelData` access in the success path uses a safe unwrap (guard let or `if let`)

**Apple compliance (Spec 00 §11):**
- [ ] §11.1 — No force-unwraps (`!`) anywhere in the file (SwiftLint `force_unwrapping` rule)
- [ ] §11.2 — Temp file always cleaned up in `defer` block — no temp file accumulation in `tmp/` directory

---

#### ✅ T-02-008 · WhisperModel actor

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P1 (high) |
| **Spec ref** | §8 — WhisperModel (artifact directory structure, full transcription pipeline) |
| **Depends on** | T-02-001 |
| **Estimated effort** | XL (> 6 hr) |
| **Files to create/modify** | `ios/App/GemmaKit/Sources/Inference/WhisperModel.swift` |

**What to build:**
Create `ios/App/GemmaKit/Sources/Inference/WhisperModel.swift` exactly as in Spec 02 §8. The `static func load(directory: URL) async throws -> WhisperModel` factory must check all three required files (`config.json`, `vocab.json`, `model.safetensors`) exist with `guard FileManager.default.fileExists` before loading; throw `GemScanError.modelNotLoaded(tier: .e2b)` for any missing file. Implement `transcribe(pcm: [Float]) async throws -> Transcript` with the five-step pipeline: (1) pad/trim PCM to 480,000 samples (30 s at 16 kHz), (2) compute 80-channel log-Mel spectrogram using `MLX.stft`, `MLX.abs`, `MLX.matmul` with the `mel_filters` weight, and dynamic-range clamping, (3) `encoderForward(mel:)` with two `conv1d` layers and 6 transformer blocks, (4) `decoderForward(tokenIds:encoderOut:)` greedy search starting from `[sotToken, englishToken, transcribeToken]` for up to 448 iterations, and (5) detokenize with `WhisperTokenizer.decode`, filtering out special tokens. Implement `WhisperConfig` (Decodable, `CodingKeys` mapping `n_mels`, `d_model`, `encoder_layers`, `encoder_attention_heads`, `decoder_layers`) and `WhisperTokenizer` with `isSpecial(_ token: Int32) -> Bool { token >= 50257 }` and BPE space-marker replacement `"Ġ" → " "`.

**Acceptance criteria:**
- [ ] `WhisperModel.load(directory:)` throws when `config.json` is absent from the directory (XCTest: delete config, assert throw)
- [ ] `WhisperModel.load(directory:)` throws when `model.safetensors` is absent (XCTest)
- [ ] `WhisperTokenizer.isSpecial(50257)` returns `true`; `isSpecial(100)` returns `false`
- [ ] `WhisperTokenizer.decode([])` returns `""` without throwing

**Apple compliance (Spec 00 §11):**
- [ ] §11.1 — `WhisperModel` is an `actor`; `weights`, `config`, `tokenizer` are actor-isolated
- [ ] §11.1 — No force-unwraps; all `MLXArray` indexing and weight lookups use `guard let` or `!` with a justifying comment explaining why the key is guaranteed present

---

#### ✅ T-02-009 · AudioSealModel actor

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P1 (high) |
| **Spec ref** | §8 — AudioSealModel (artifact directory structure, detectScore pipeline) |
| **Depends on** | T-02-001 |
| **Estimated effort** | L (3–6 hr) |
| **Files to create/modify** | `ios/App/GemmaKit/Sources/Inference/AudioSealModel.swift` |

**What to build:**
Create `ios/App/GemmaKit/Sources/Inference/AudioSealModel.swift` as an `actor` exactly as in Spec 02 §8. The `static func load(directory: URL) async throws -> AudioSealModel` factory must guard on both `config.json` and `model.safetensors` being present. Implement `detectScore(pcm: [Float]) async throws -> Double` with the four-step pipeline: (1) reshape PCM to `[1, samples, 1]` with `MLXArray(pcm).reshaped(1, pcm.count, 1)`, (2) apply initial `MLX.conv1d` with `detector.conv.weight` and `detector.conv.bias` with `padding: 3` (same padding for kernel 7), followed by `MLX.gelu`, (3) eight residual layers using `detector.layers.N.weight` and `detector.layers.N.bias` with `padding: 1` and a residual skip connection `h = h + MLX.gelu(MLX.conv1d(h, ...))`, (4) mean-pool over the time axis (`h.mean(axis: 1)`), then linear classifier with `detector.classifier.weight` and `detector.classifier.bias`, sigmoid of `logits[0, 1]`. Implement `AudioSealConfig` as a `Decodable` struct with `CodingKeys` mapping `hidden_size` → `hiddenSize`, `num_layers` → `numLayers`, `sample_rate` → `sampleRate`.

**Acceptance criteria:**
- [ ] `AudioSealModel.load(directory:)` throws `GemScanError.modelNotLoaded` when `model.safetensors` is absent (XCTest)
- [ ] `detectScore` output is in `[0.0, 1.0]` range for synthetic sine-wave PCM input (XCTest: T-02-018)
- [ ] `AudioSealConfig` decodes correctly from `{"hidden_size":64,"num_layers":8,"sample_rate":16000}` (XCTest)
- [ ] Residual skip connection is correctly implemented: each layer adds `gelu(conv1d(h))` to `h`, not replaces

**Apple compliance (Spec 00 §11):**
- [ ] §11.1 — `AudioSealModel` is an `actor`; all MLX operations are actor-isolated
- [ ] §11.1 — No force-unwraps; weight dictionary lookups use `!` only with a comment stating the key is guaranteed by the verified artifact structure

---

#### ✅ T-02-010 · WhisperASR + AudioSealDetector wrappers

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P1 (high) |
| **Spec ref** | §8 — WhisperASR, AudioSealDetector |
| **Depends on** | T-02-005, T-02-007, T-02-008, T-02-009 |
| **Estimated effort** | M (1–3 hr) |
| **Files to create/modify** | `ios/App/GemmaKit/Sources/Inference/WhisperASR.swift`, `ios/App/GemmaKit/Sources/Inference/AudioSealDetector.swift` |

**What to build:**
Create `ios/App/GemmaKit/Sources/Inference/WhisperASR.swift` as an `actor` with `static let shared = WhisperASR()` and `private var model: WhisperModel?`. Implement `transcribe(base64Audio: String, durationSeconds: Double) async throws -> Transcript`: guard `durationSeconds > 0 && durationSeconds <= 300` throwing `audioIngestionUnavailable(reason: "Duration out of range: \(durationSeconds)s")`, guard `Data(base64Encoded: base64Audio)` throwing `audioIngestionUnavailable(reason: "Invalid base64 audio data")`, call `loadModel()` if `model == nil`, decode AAC via `AudioDecoder.decode(aacData:targetSampleRate: 16_000)`, call `model!.transcribe(pcm:)`, log `"WhisperASR: transcribed \(Int(durationSeconds))s → \(result.text.count) chars lang=\(result.language)"`. The `loadModel()` method implements the lazy-download pattern: `ModelLoader.shared.isDownloadedByName("whisper-small-mlx")` → `downloadByName` if false → `cachedURL(for: "whisper-small-mlx")` → `WhisperModel.load(directory:)`. Create `AudioSealDetector.swift` with the same lazy-download pattern for `"audioseal-detector-mlx"` and `AudioSealModel.load`, implementing `score(base64Audio: String) async throws -> Double` using `AudioDecoder.decode` then `model!.detectScore(pcm:)`.

**Acceptance criteria:**
- [ ] `WhisperASR.transcribe(base64Audio: "AAAA", durationSeconds: 0)` throws `audioIngestionUnavailable` (XCTest)
- [ ] `WhisperASR.transcribe(base64Audio: "AAAA", durationSeconds: 400)` throws `audioIngestionUnavailable` (XCTest)
- [ ] `AudioSealDetector.score(base64Audio: invalidBase64)` throws `audioIngestionUnavailable` (XCTest)
- [ ] `WhisperASR.loadModel()` is called only once even when `transcribe()` is called twice concurrently (XCTest: concurrent calls, assert `WhisperModel.load` called once)

**Apple compliance (Spec 00 §11):**
- [ ] §11.1 — Lazy `model` initialisation inside an `actor` is safe; no concurrent initialisation race (actor serialises calls)
- [ ] §11.3 — `logger.info` in `transcribe()` logs only character count and language, never the transcript text itself

---

### Group: SMS & Text Components

---

#### ✅ T-02-011 · SMSTriage

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P1 (high) |
| **Spec ref** | §8 — DistilBERT SMS Triage (Extension-Only Path, SMSTriage implementation) |
| **Depends on** | T-00-005 |
| **Estimated effort** | M (1–3 hr) |
| **Files to create/modify** | `ios/App/GemmaKit/Sources/Inference/SMSTriage.swift` |

**What to build:**
Create `ios/App/GemmaKit/Sources/Inference/SMSTriage.swift`. Implement `static let shared: SMSTriage` as a lazy singleton that loads from `Bundle.main.url(forResource: "SmsTriage", withExtension: "mlmodelc")` — use `guard let url = Bundle.main.url(...)` and `guard let instance = try? SMSTriage(modelURL: url)` then call `fatalError("GemScan: SmsTriage.mlmodelc missing from main bundle — check build phases")` if either guard fails. Implement `static func extensionInstance() throws -> SMSTriage`: use `UserDefaults(suiteName: SharedContainerSchema.appGroupId)`, guard the path string exists and is non-empty, throwing `GemScanError.modelNotLoaded(tier: .distilbert)` otherwise, then return `try SMSTriage(modelURL: URL(fileURLWithPath: path))`. Implement `init(modelURL: URL) throws` creating `MLModelConfiguration()` with `computeUnits = .cpuOnly` and constructing `SmsTriage(contentsOf: modelURL, configuration: config)`. Implement `classify(text: String) throws -> TriageResult`: construct `SmsTriage_Input(text: text)`, call `model.prediction(input:)`, map `output.label` to `TriageLabel(rawValue:) ?? .unknown`, and return `TriageResult(senderHash: "", label: label, confidence: confidence, timestampMs: Int64(Date().timeIntervalSince1970 * 1000))` — `senderHash` is always `""` (by design: SMS Filter extensions do not receive sender identity).

**Acceptance criteria:**
- [ ] `TriageResult.senderHash` is always `""` in `classify()` output — never populated (XCTest)
- [ ] `extensionInstance()` throws `GemScanError.modelNotLoaded(tier: .distilbert)` when the App Group key is absent (XCTest: use a fresh `UserDefaults(suiteName:)` with no key set)
- [ ] `MLModelConfiguration.computeUnits == .cpuOnly` is set before loading the model (XCTest: inspect config)
- [ ] `classify()` returns a `TriageLabel` in `{.safe, .junk, .transaction, .promotion, .unknown}` for any string input

**Apple compliance (Spec 00 §11):**
- [ ] §11.2 — `.cpuOnly` compute units enforced — DistilBERT must not use GPU/ANE in extensions to stay within the 50 MB memory ceiling
- [ ] §11.6 — `UserDefaults(suiteName: SharedContainerSchema.appGroupId)` used, never `UserDefaults.standard` (SwiftLint `no_nsuserdefaults_direct` rule)

---

#### ✅ T-02-012 · TextEmbedder

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P2 (standard) |
| **Spec ref** | §8 — Text Embedding for sqlite_vec |
| **Depends on** | T-02-006 |
| **Estimated effort** | S (< 1 hr) |
| **Files to create/modify** | `ios/App/GemmaKit/Sources/Inference/TextEmbedder.swift` |

**What to build:**
Create `ios/App/GemmaKit/Sources/Inference/TextEmbedder.swift` as an `actor TextEmbedder` with `static let shared = TextEmbedder()`. Implement `func embed(text: String) async throws -> [Float]` that calls `InferenceEngine.shared.encode(text: text, dimensions: 128)` and returns the result. Implement `static func toJSON(_ vector: [Float]) -> String` that produces a compact JSON array string: `"[" + vector.map { String(format: "%.6f", $0) }.joined(separator: ",") + "]"`. This exact format is required by the `sqlite_vec/semantic_search` MCP tool. Include an inline comment on `embed()` noting that callers should pass `sha256(messageContent)` rather than raw message text, as this embedding may be logged or stored in the sqlite_vec index.

**Acceptance criteria:**
- [ ] `TextEmbedder.toJSON([0.5, -0.3])` returns `"[0.500000,-0.300000]"` with six decimal places (XCTest)
- [ ] `TextEmbedder.toJSON([])` returns `"[]"` without throwing (XCTest)
- [ ] `embed()` calls `InferenceEngine.shared.encode(text:dimensions:)` with `dimensions: 128` (XCTest: verify via mock InferenceEngine)
- [ ] `TextEmbedder` is an `actor` (compile-time verification by calling `await TextEmbedder.shared.embed(text:)`)

**Apple compliance (Spec 00 §11):**
- [ ] §11.3 — `embed()` docstring instructs callers to hash message content before embedding; raw text must not be passed to this function

---

#### ✅ T-02-013 · TokenStream

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P1 (high) |
| **Spec ref** | §2 — GemmaKit Package Structure (TokenStream.swift listed as Inference layer file) |
| **Depends on** | T-02-001 |
| **Estimated effort** | S (< 1 hr) |
| **Files to create/modify** | `ios/App/GemmaKit/Sources/Inference/TokenStream.swift` |

**What to build:**
Create `ios/App/GemmaKit/Sources/Inference/TokenStream.swift`. Implement a `struct TokenStream` with a static factory method `static func makeStream() -> (stream: AsyncStream<String>, continuation: AsyncStream<String>.Continuation)` that calls `AsyncStream<String>.makeStream()` and returns the tuple. Add a convenience method `static func collect(from continuation: AsyncStream<String>.Continuation, onToken: @escaping (String) -> Void) -> (String) -> Void` that returns a closure suitable for passing as the `onToken` parameter to `InferenceEngine.generate()` — the closure calls `continuation.yield(token)` and also calls `onToken(token)` for live streaming. Document that callers must call `continuation.finish()` when generation is done to terminate the `AsyncStream`. This type is used by agents in M3 to bridge `InferenceEngine`'s callback-based token streaming into async sequence iteration.

**Acceptance criteria:**
- [ ] `TokenStream.makeStream()` returns a non-nil `stream` and `continuation` (XCTest)
- [ ] Yielding 3 tokens via `continuation.yield` and then calling `continuation.finish()` causes the `AsyncStream` to emit exactly 3 elements (XCTest: `for await token in stream`)
- [ ] `TokenStream` compiles as a `struct` (value type) — no `actor` or `class` keyword
- [ ] `npx tsc --noEmit` is unaffected (Swift-only file)

**Apple compliance (Spec 00 §11):**
- [ ] §11.1 — `AsyncStream.Continuation` is `Sendable`; `TokenStream` struct is implicitly `Sendable`; `SWIFT_STRICT_CONCURRENCY=complete` build passes

---

### Group: Tests

---

#### ✅ T-02-014 · InferenceEngine unit tests

| Field | Value |
|---|---|
| **Type** | TEST |
| **Priority** | P1 (high) |
| **Spec ref** | §3 — InferenceEngine Actor (checkMemory, checkThermal, generateVision guard, encode) |
| **Depends on** | T-02-006 |
| **Estimated effort** | L (3–6 hr) |
| **Files to create/modify** | `ios/App/GemmaKit/Tests/InferenceEngineTests.swift` |

**What to build:**
Create `ios/App/GemmaKit/Tests/InferenceEngineTests.swift` with four test cases. `testRSSCheckRejectsOversizedModel()`: construct a test `InferenceEngine` with a `MockModelLoader` that returns an `expectedRAMBytes` larger than available memory (mock `currentRSS()` to return `ProcessInfo.processInfo.physicalMemory - 100`); call `warmUpE2B()` and assert it throws `GemScanError.oomRejected`. `testThermalGuardDowngradesToE2B()`: mock `ProcessInfo.processInfo.thermalState` to `.serious` (inject via a testable `ThermalStateProvider` protocol); call `loadE4BIfNeeded()` and assert it throws `GemScanError.modelNotLoaded(tier: .e4b)`. `testGenerateVisionRejectsLlamaCppBackend()`: inject a `MockLlamaCppBackend` as `e4bBackend`; call `generateVision(imageBase64:textPrompt:grammar:task:maxTokens:onToken:)` and assert it throws `GemScanError.grammarViolation`. `testEncodeReturns128FloatVector()`: inject a `MockMLXBackend` that returns a pre-computed 128-float vector; call `encode(text: "test", dimensions: 128)` and assert the result has exactly 128 elements and an L2-norm ≈ 1.0 (tolerance 0.001).

**Acceptance criteria:**
- [ ] All four test methods pass under `xcodebuild test -scheme GemmaKitTests -only-testing GemmaKitTests/InferenceEngineTests`
- [ ] `testRSSCheckRejectsOversizedModel` asserts `GemScanError.oomRejected` is thrown (not a different error)
- [ ] `testGenerateVisionRejectsLlamaCppBackend` asserts `GemScanError.grammarViolation` is thrown
- [ ] L2-norm of the returned vector in `testEncodeReturns128FloatVector` is between 0.999 and 1.001

**Apple compliance (Spec 00 §11):**
- [ ] §11.2 — `testRSSCheckRejectsOversizedModel` directly validates the 1.2× headroom requirement from Spec 00 §7
- [ ] §11.1 — `testThermalGuardDowngradesToE2B` validates the thermal guard from Spec 00 §7

---

#### ✅ T-02-015 · ModelLoader tests

| Field | Value |
|---|---|
| **Type** | TEST |
| **Priority** | P1 (high) |
| **Spec ref** | §6 — ModelLoader (`isDownloadedByName`, `verify`, `syncPathToAppGroup`) |
| **Depends on** | T-02-005 |
| **Estimated effort** | M (1–3 hr) |
| **Files to create/modify** | `ios/App/GemmaKit/Tests/ModelLoaderTests.swift` |

**What to build:**
Create `ios/App/GemmaKit/Tests/ModelLoaderTests.swift` with three test methods. `testIsDownloadedReturnsFalseForMissingFile()`: instantiate a `ModelLoader` with a temp cache directory; call `isDownloadedByName("nonexistent-model")` and assert `false`. `testVerifySHA256FailsOnCorruptedFile()`: write 16 bytes of zeros to a temp file, call `verify(tempURL, expectedSHA256: "correcthashhere")` on the `ModelLoader`, assert it throws, and assert the temp file no longer exists at the path after the throw (verify the corrupted-file deletion behaviour from Spec 02 §6). `testSyncPathToAppGroupWritesDistilbertPath()`: call `syncPathToAppGroup(tier: .distilbert, localURL: URL(fileURLWithPath: "/tmp/test-path"))`, then read `UserDefaults(suiteName: SharedContainerSchema.appGroupId)?.string(forKey: SharedContainerSchema.distilbertModelPath)` and assert it equals `"/tmp/test-path"`. Use `addTeardownBlock` to clear the App Group default after the test.

**Acceptance criteria:**
- [ ] All three tests pass under `xcodebuild test -scheme GemmaKitTests -only-testing GemmaKitTests/ModelLoaderTests`
- [ ] `testVerifySHA256FailsOnCorruptedFile` asserts the file is deleted (not just that an error is thrown)
- [ ] `testSyncPathToAppGroupWritesDistilbertPath` cleans up App Group defaults in `addTeardownBlock`
- [ ] `testIsDownloadedReturnsFalseForMissingFile` uses a fresh temp directory, not the real `GemScanModels` cache

**Apple compliance (Spec 00 §11):**
- [ ] §11.6 — `testSyncPathToAppGroupWritesDistilbertPath` directly validates that `UserDefaults(suiteName:)` is used (not `UserDefaults.standard`)
- [ ] §11.2 — `testVerifySHA256FailsOnCorruptedFile` validates the corrupted-file cleanup behaviour that prevents disk space accumulation

---

#### ✅ T-02-016 · SMSTriage tests

| Field | Value |
|---|---|
| **Type** | TEST |
| **Priority** | P1 (high) |
| **Spec ref** | §8 — DistilBERT SMS Triage (`classify`, `extensionInstance`, `senderHash` by-design behaviour) |
| **Depends on** | T-02-011 |
| **Estimated effort** | M (1–3 hr) |
| **Files to create/modify** | `ios/App/GemmaKit/Tests/SMSTriageTests.swift` |

**What to build:**
Create `ios/App/GemmaKit/Tests/SMSTriageTests.swift` with three test methods. `testClassifyReturnsSenderHashEmpty()`: load `SMSTriage` using a mock `.mlmodelc` path (or a MockSmsTriage in the test target), call `classify(text: "Your account has been locked.")`, and assert `result.senderHash == ""` — this is a permanent by-design assertion documenting that the extension never receives sender identity. `testClassifyReturnsTriage LabelInValidRange()`: call `classify(text: "Congratulations, you've won!")` and assert `result.label` is one of `{.safe, .junk, .transaction, .promotion, .unknown}`, and `result.confidence` is in `0.0...1.0`. `testExtensionInstanceThrowsWhenPathMissing()`: use a fresh `UserDefaults(suiteName: "com.gemscan.test-app-group")` with no value set for `SharedContainerSchema.distilbertModelPath`; inject this into `extensionInstance()` via a testable parameter; assert it throws `GemScanError.modelNotLoaded(tier: .distilbert)`.

**Acceptance criteria:**
- [ ] `testClassifyReturnsSenderHashEmpty` asserts `senderHash == ""` — this assertion must not be removed or skipped
- [ ] `testClassifyReturnsTriage LabelInValidRange` asserts `result.confidence >= 0.0 && result.confidence <= 1.0`
- [ ] `testExtensionInstanceThrowsWhenPathMissing` passes with a clean test-scoped UserDefaults instance
- [ ] All three tests pass under `xcodebuild test -scheme GemmaKitTests -only-testing GemmaKitTests/SMSTriageTests`

**Apple compliance (Spec 00 §11):**
- [ ] §11.2 — `testClassifyReturnsTriage LabelInValidRange` indirectly validates the `.cpuOnly` compute constraint (if the model runs at all in the test target, it used CPU)
- [ ] §11.3 — `testClassifyReturnsSenderHashEmpty` locks in the privacy-by-design requirement that extensions never receive sender identity

---

#### ✅ T-02-017 · AudioDecoder tests

| Field | Value |
|---|---|
| **Type** | TEST |
| **Priority** | P2 (standard) |
| **Spec ref** | §8 — AudioDecoder Utility |
| **Depends on** | T-02-007 |
| **Estimated effort** | M (1–3 hr) |
| **Files to create/modify** | `ios/App/GemmaKit/Tests/AudioDecoderTests.swift`, `ios/App/GemmaKit/Tests/Resources/test_1s_16khz.aac` |

**What to build:**
Create `ios/App/GemmaKit/Tests/AudioDecoderTests.swift` with three test methods. `testDecodeValidAACReturnsNonEmptyPCM()`: bundle a synthesised 1-second 16 kHz AAC test file as `test_1s_16khz.aac` in the test target resources (generate it in a test setup script using `AVAudioEngine`), load it with `Data(contentsOf:)`, call `AudioDecoder.decode(aacData:targetSampleRate: 16_000)`, and assert the result is non-empty and has approximately 16,000 samples (allow ±500 for encoder/decoder rounding). `testDecodeInvalidBase64ThrowsAudioIngestion()`: call `AudioDecoder.decode(aacData: Data([0x00, 0x01, 0x02]), targetSampleRate: 16_000)` (invalid AAC data) and assert it throws `GemScanError.audioIngestionUnavailable`. `testDecodeOutputSampleRateIs16kHz()`: use the bundled test AAC file at 8 kHz original sample rate and confirm the output array length is consistent with 16 kHz resampling (≥ 14,000 samples for a 1-second clip after rate conversion).

**Acceptance criteria:**
- [ ] All three tests pass under `xcodebuild test -scheme GemmaKitTests -only-testing GemmaKitTests/AudioDecoderTests`
- [ ] `testDecodeValidAACReturnsNonEmptyPCM` asserts sample count between 15,500 and 16,500
- [ ] `testDecodeInvalidBase64ThrowsAudioIngestion` asserts the thrown error is `GemScanError.audioIngestionUnavailable`
- [ ] The bundled test AAC file is tracked in git (it is small, < 20 KB)

**Apple compliance (Spec 00 §11):**
- [ ] §11.2 — `testDecodeValidAACReturnsNonEmptyPCM` validates that no temp files remain after the call (check `FileManager.default.temporaryDirectory` before and after)

---

#### ✅ T-02-018 · WhisperModel + AudioSealModel factory tests

| Field | Value |
|---|---|
| **Type** | TEST |
| **Priority** | P2 (standard) |
| **Spec ref** | §8 — WhisperModel (load factory), AudioSealModel (load factory, detectScore) |
| **Depends on** | T-02-008, T-02-009 |
| **Estimated effort** | M (1–3 hr) |
| **Files to create/modify** | `ios/App/GemmaKit/Tests/WhisperModelTests.swift`, `ios/App/GemmaKit/Tests/AudioSealModelTests.swift` |

**What to build:**
Create `ios/App/GemmaKit/Tests/WhisperModelTests.swift` with two methods. `testWhisperModelLoadThrowsWhenConfigMissing()`: create a temp directory containing only `vocab.json` and `model.safetensors` (empty placeholders), call `WhisperModel.load(directory:)`, and assert it throws `GemScanError.modelNotLoaded`. `testWhisperModelLoadThrowsWhenWeightsMissing()`: create a temp directory with only `config.json` and `vocab.json`, call `WhisperModel.load(directory:)`, assert it throws. Create `ios/App/GemmaKit/Tests/AudioSealModelTests.swift` with two methods. `testAudioSealModelLoadThrowsWhenWeightsMissing()`: create a temp directory with only `config.json`, call `AudioSealModel.load(directory:)`, assert it throws `GemScanError.modelNotLoaded`. `testAudioSealModelScoreReturnsBetweenZeroAndOne()`: if a real `audioseal-detector-mlx` artifact is available in the test environment, load it and call `detectScore(pcm: sineWavePCM)` where `sineWavePCM` is a 1-second 440 Hz sine wave at 16 kHz; assert the result is in `0.0...1.0`. Skip this test if the artifact is not present (`XCTSkipIf`).

**Acceptance criteria:**
- [ ] `testWhisperModelLoadThrowsWhenConfigMissing` asserts `GemScanError.modelNotLoaded` is thrown
- [ ] `testAudioSealModelLoadThrowsWhenWeightsMissing` asserts `GemScanError.modelNotLoaded` is thrown
- [ ] `testAudioSealModelScoreReturnsBetweenZeroAndOne` returns a value in `[0.0, 1.0]` or is skipped cleanly with `XCTSkip`
- [ ] All four tests pass under `xcodebuild test -scheme GemmaKitTests`

**Apple compliance (Spec 00 §11):**
- [ ] §11.1 — Factory tests directly validate the `guard FileManager.default.fileExists` branches that prevent forced loading of missing artifacts

---

### Group: Documentation & Validation

---

#### ✅ T-02-019 · Inference engine DocC

| Field | Value |
|---|---|
| **Type** | DOCUMENT |
| **Priority** | P2 (standard) |
| **Spec ref** | §3 — InferenceEngine Actor (public API); §4 — InferenceBackend Protocol; §8 — WhisperModel artifact structure |
| **Depends on** | T-02-006, T-02-003, T-02-008 |
| **Estimated effort** | M (1–3 hr) |
| **Files to create/modify** | `ios/App/GemmaKit/Sources/Inference/InferenceEngine.swift`, `ios/App/GemmaKit/Sources/Inference/MLXInferenceBackend.swift`, `ios/App/GemmaKit/Sources/Inference/WhisperModel.swift`, `ios/App/GemmaKit/Sources/GemmaKit.docc/Inference.md` |

**What to build:**
Add `///` DocC comments to all `public` methods on `InferenceEngine`: `warmUpE2B()` (document the call-once-from-AppDelegate requirement), `loadE4BIfNeeded()` (document the thermal check and OOM guard), `unloadE4B()` (document when to call it — after an analysis session to reclaim memory), `generate()` (document the `grammar` parameter and the `maxTokens` default), `generateVision()` (document the MLX-only constraint and the `isMLXAvailable` check callers must perform), `encode()` (document the 128-dimensional output and L2-norm guarantee), `isMLXAvailable` (document when it returns false — simulator, llama.cpp path). Create `GemmaKit.docc/Inference.md` as a DocC article titled "Inference Engine" explaining the backend selection logic: MLX path (Apple Silicon, real device) vs llama.cpp path (simulator, Intel, older devices), and when each is active. Document the `whisper-small-mlx` artifact directory structure (list required files: `config.json`, `vocab.json`, `model.safetensors`).

**Acceptance criteria:**
- [ ] `xcodebuild docbuild -scheme GemmaKit` exits 0 with no undocumented public symbols in `Inference/`
- [ ] `generateVision()` DocC comment explicitly states "MLX-only: throws `GemScanError.grammarViolation` on llama.cpp backend"
- [ ] `isMLXAvailable` DocC comment explains the two conditions when it returns `false`
- [ ] `Inference.md` article exists and contains a "Backend Selection" section

**Apple compliance (Spec 00 §11):**
- [ ] N/A — documentation task; no runtime behavior changes

---

#### ✅ T-02-020 · Inference engine Apple compliance

| Field | Value |
|---|---|
| **Type** | VALIDATE |
| **Priority** | P1 (high) |
| **Spec ref** | §11.1 — Swift Concurrency; §11.2 — Memory and Performance; §11.7 — Task Completion Definition |
| **Depends on** | T-02-003, T-02-004, T-02-005, T-02-006, T-02-007, T-02-014, T-02-015 |
| **Estimated effort** | L (3–6 hr) |
| **Files to create/modify** | PR description (Apple Compliance Notes), `ios/App/GemmaKit/Tests/PerformanceTests.swift` (XCTMemoryMetric) |

**What to build:**
Run the full M2 compliance checklist. (1) Run Instruments Leaks template on a model load → generate 20 tokens → unload cycle for both E2B (MLX) and E2B (llama.cpp) backends; assert zero leaks. (2) Verify RSS delta after E2B load is ≤ 1.8 GB using an `XCTMemoryMetric` performance test in `PerformanceTests.swift`: call `measure(metrics: [XCTMemoryMetric()]) { await InferenceEngine.shared.warmUpE2B() }` and assert `averageMemoryUsage ≤ 1_887_436_800` bytes. (3) Run `xcodebuild analyze -scheme GemmaKit` on all files in `Sources/Inference/` — zero analyzer issues required. (4) Build GemmaKit with `SWIFT_STRICT_CONCURRENCY=complete` and resolve any new concurrency warnings in `InferenceEngine.swift`, `MLXInferenceBackend.swift`, `LlamaCppInferenceBackend.swift`, `ModelLoader.swift`. (5) Run `swiftlint lint --strict ios/App/GemmaKit/Sources/Inference/` — zero errors. (6) Check `AudioDecoder.swift` has zero `!` operators (SwiftLint `force_unwrapping` rule — no exceptions).

**Acceptance criteria:**
- [ ] Instruments Leaks shows zero leaks after full load/generate/unload cycle (both MLX and llama.cpp paths)
- [ ] `XCTMemoryMetric` performance test: E2B RSS delta ≤ 1,887,436,800 bytes (1.8 GB)
- [ ] `xcodebuild analyze -scheme GemmaKit` exits 0 on all Inference/ files
- [ ] `SWIFT_STRICT_CONCURRENCY=complete` build produces zero new warnings on modified files
- [ ] `swiftlint lint --strict ios/App/GemmaKit/Sources/Inference/` exits 0
- [ ] PR description contains "Apple Compliance Notes" section with §11.1 and §11.2 verified with specific tooling used

**Apple compliance (Spec 00 §11):**
- [ ] §11.1 — `SWIFT_STRICT_CONCURRENCY=complete` verified clean on all Inference/ actors
- [ ] §11.1 — SwiftLint `force_unwrapping` passes on `AudioDecoder.swift` (zero exceptions allowed)
- [ ] §11.2 — Instruments Leaks: zero leaks on E2B load/infer/unload cycle
- [ ] §11.2 — E2B RSS delta ≤ 1.8 GB confirmed by `XCTMemoryMetric`

---

#### ✅ T-02-021 · Chat template verification script

| Field | Value |
|---|---|
| **Type** | VALIDATE |
| **Priority** | P2 (standard) |
| **Spec ref** | §7 — Chat Template Verification |
| **Depends on** | T-02-001 |
| **Estimated effort** | M (1–3 hr) |
| **Files to create/modify** | `scripts/verify-chat-template.py`, `scripts/requirements-verify.txt` |

**What to build:**
Create `scripts/verify-chat-template.py` as specified in Spec 02 §7. The script loads the model tokenizer via `transformers.AutoTokenizer.from_pretrained(model_id)`, applies the chat template with a test prompt, and compares the tokenized output against a known-good reference file. Create `scripts/requirements-verify.txt` with `transformers>=4.40`, `torch`, `sentencepiece`. The script accepts `--model-id` and `--reference-file` arguments. It must exit 0 if tokenization matches the reference exactly, exit 1 with a diff otherwise. This ensures on-device tokenization (Swift) matches the Python reference tokenizer before shipping model artifacts. Add a `# Usage` comment at the top of the script.

**Acceptance criteria:**
- [ ] `python scripts/verify-chat-template.py --model-id google/gemma-2-2b-it --reference-file fixtures/gemma-chat-template.json` exits 0 when tokenization matches
- [ ] Script exits 1 and prints a diff when tokenization does not match
- [ ] `scripts/requirements-verify.txt` contains all required Python dependencies
- [ ] Script runs with Python 3.11+ (no syntax errors)

**Apple compliance (Spec 00 §11):**
- [ ] N/A — offline verification script; no native code

---

#### ✅ T-02-022 · Performance monitoring hooks wiring

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P1 (high) |
| **Spec ref** | §9 — Performance Monitoring Hooks |
| **Depends on** | T-02-006, T-00-014 |
| **Estimated effort** | S (< 1 hr) |
| **Files to create/modify** | `ios/App/GemmaKit/Sources/Inference/InferenceEngine.swift` |

**What to build:**
Wire `InferenceMetrics` (defined in T-00-014) into `InferenceEngine.generate()` and `InferenceEngine.generateVision()`. At the start of each method, capture `let start = ContinuousClock.now`. After generation completes, construct an `InferenceMetrics` with `firstTokenLatencyMs` (time to first `onToken` callback), `totalLatencyMs` (total wall-clock time), `tokensPerSecond` (token count / total seconds), `peakRSSBytes` (from `currentRSS()`), `modelTier`, and `escalated: false` (escalation flag set by OrchestratorAgent, not here). Call `MetricsCollector.shared.record(metrics)` — define `MetricsCollector` as a minimal `actor` with `static let shared` and a `func record(_ metrics: InferenceMetrics)` method that stores to an internal array (the full `MetricsStore` ring buffer is built in M8, T-08-004). Log `"generate: tier=\(tier), latency=\(totalLatencyMs)ms, tokens=\(tokenCount)"` at `.info` level.

**Acceptance criteria:**
- [ ] `generate()` emits an `InferenceMetrics` to `MetricsCollector.shared` after every call (XCTest with mock collector)
- [ ] `firstTokenLatencyMs` is measured from call start to first `onToken` invocation
- [ ] `tokensPerSecond` equals `tokenCount / (totalLatencyMs / 1000.0)` (±0.1 tolerance in XCTest)
- [ ] `MetricsCollector` is an `actor` with `Sendable` conformance

**Apple compliance (Spec 00 §11):**
- [ ] §11.1 — `MetricsCollector` is an `actor`; no data races on the metrics array
