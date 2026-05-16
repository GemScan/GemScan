# GemScan iOS Specification: Gemma 4 E2B 4-bit Modality-Aware Weighted Scam Detection

## 0. Purpose

This specification converts the notebook `10_6_prompt_ablation_classic_gemma_e2b_4_bit(2).ipynb` into an implementation plan for the existing GemScan repository.

The target implementation is a native iOS modality-aware scam detection path exposed through the existing Next.js + Capacitor app shell and implemented inside the existing Swift `GemmaKit` package. Text input uses the marker-extraction model call directly. Image and other non-text modalities first run context extraction, then use the same marker-extraction and scoring path.

The notebook was an experiment. The app implementation must be a deterministic production pipeline:

1. User provides text, a screenshot/image, or another supported modality.
2. If the user clicks **Check this text**, the app skips context extraction and uses the user-entered text directly as `{{INPUT_SUMMARY}}`.
3. If the input is an image/screenshot, Gemma 4 E2B 4-bit first transcribes the visible image text using the OCR-style image context prompt.
4. Future non-text modalities must also perform a modality-specific context-extraction step before marker extraction.
5. Gemma 4 E2B runs one fixed marker-extraction prompt against the input summary.
6. The app parses marker JSON into binary feature statuses.
7. The app applies the notebook's fixed feature weights.
8. The app sums the weighted score.
9. The app returns `scam` when `totalScore >= 0.22`; otherwise it returns `safe`.

## 1. Source Notebook Behavior to Preserve

### 1.1 Keep

Preserve these runtime behaviors from the notebook:

- Model family/display name: `Gemma4:E2B`.
- Quantization concept: `4-bit`.
- Runtime temperature: `0.0` / deterministic generation.
- Maximum generation size for notebook-equivalent prompts: `700` new tokens unless the native backend requires a higher internal cap.
- Modality-aware inference flow:
  - Text input: single text-only structured marker extraction call.
  - Image/non-text input: context extraction first, then text-only structured marker extraction.
- Robust JSON parsing from raw model output.
- Missing, malformed, absent, false, no, empty, or parse-failed marker values normalize to absent.
- Nested marker objects with `{ "status": "present" | "absent", "evidence": "..." }` are supported.
- Score threshold is inclusive: score equal to threshold is `scam`.

### 1.2 Remove

Do not implement these notebook-only concerns in the app runtime:

- Prompt ablation.
- Loading prompts from `PROMPTS_PATH`.
- Multiple prompts per image.
- Prompt IDs, prompt names, or prompt rankings.
- Pandas dataframes.
- Google Drive paths.
- Colab package installation.
- Weights & Biases logging.
- CSV prediction checkpoints.
- Dataset loading from `/scam/` and `/safe/` directories.
- Offline evaluation metrics in the mobile runtime.
- Batch processing for multiple prompts.

Evaluation tooling can exist in tests or future scripts, but it must not be part of the user-facing inference path.

## 2. Existing Repository Integration Points

The current repo is not a greenfield app. Implement this spec by refactoring the existing components below.

### 2.1 Current app architecture

- Web shell: `src/app`, `src/components`, `src/lib/gemma`.
- Native bridge: `ios/App/App/GemmaPlugin.swift`.
- Shared Swift inference package: `ios/App/GemmaKit`.
- Agent entry point: `ios/App/GemmaKit/Sources/Agents/OrchestratorAgent.swift`.
- Screenshot specialist: `ios/App/GemmaKit/Sources/Agents/ImageAgent.swift`.
- Inference engine: `ios/App/GemmaKit/Sources/Inference/InferenceEngine.swift`.
- MLX backend: `ios/App/GemmaKit/Sources/Inference/MLXInferenceBackend.swift`.
- Model registry: `ios/App/GemmaKit/Sources/Inference/MLXModelDownloader.swift`.
- Bridge types: `src/lib/gemma/types.ts` and `ios/App/GemmaKit/Sources/Agents/AgentTask.swift` / `AgentResult.swift`.

### 2.2 Current model decision

Use the repo's current single-model iOS direction:

- `ModelTier.e2b` remains the only app model tier.
- Native model source remains `mlx-community/gemma-4-e2b-it-4bit` through `MLXModelRegistry`.
- Do not add E4B escalation for this implementation.
- Do not add Python, PyTorch, transformers, bitsandbytes, pandas, or W&B to the iOS app.

The notebook's `google/gemma-4-E2B-it` + BitsAndBytes NF4 path is the Python reference. The iOS implementation uses the existing MLX 4-bit artifact because that is the repo's native runtime.

### 2.3 Bridge bug to fix before image work

The TypeScript native bridge currently calls:

```ts
NativeBridge.analyse({ task })
```

Therefore `GemmaPlugin.swift` must decode `call.getObject("task")`, not the whole `call.options` dictionary. The current implementation attempts to decode the root `call.options` as `AgentTask`, which will fail if Capacitor passes `{ task: ... }`.

Required fix in `ios/App/App/GemmaPlugin.swift`:

```swift
guard let taskObject = call.getObject("task"),
      let payloadJSON = try? JSONSerialization.data(withJSONObject: taskObject) else {
    call.reject("Missing or invalid task", "INVALID_TASK")
    return
}

let task = try JSONDecoder().decode(AgentTask.self, from: payloadJSON)
```

Do this fix as part of the implementation because screenshot analysis depends on the same bridge path.

## 3. Runtime Pipeline

### 3.1 End-to-end sequence

```text
Next.js UI
  -> user clicks "Check this text" OR submits image/screenshot
  -> build AgentTask from input modality
  -> GemmaPluginNative.analyse(task)
  -> GemmaPlugin.swift decodes AgentTask
  -> OrchestratorAgent.dispatch(task)

Text path:
  -> Text/URL agent uses the user text directly as INPUT_SUMMARY
  -> InferenceEngine.generate(text-only MARKER_EXTRACTION_PROMPT with user text)

Image path:
  -> ImageAgent.analyse(task)
  -> InferenceEngine.generateVision(image + IMAGE_CONTEXT_PROMPT)
  -> use returned transcription as INPUT_SUMMARY
  -> InferenceEngine.generate(text-only MARKER_EXTRACTION_PROMPT with transcription)

Shared scoring path:
  -> ScamMarkerParser.parse(rawMarkerOutput)
  -> WeightedScamScorer.score(features)
  -> build AgentResult(verdict, confidence, reasoning, scoring metadata)
  -> GemmaPlugin returns AgentResult to TypeScript
  -> VerdictCard renders result
```

### 3.2 Image task type

Use the existing canonical task type:

```ts
type AgentTaskType = "analyseScreenshot"
```

Use the existing image payload shape:

```ts
{ type: "image", base64: string, mimeType: "image/jpeg" | "image/png" }
```

The `base64` field must contain raw base64 only. It must not include the `data:image/png;base64,` prefix. The MIME type carries that information.

### 3.3 Timeout rules

Text analysis performs one model call and may keep the existing text timeout.

Image/screenshot analysis performs two model calls, so the UI must create screenshot tasks with a longer timeout than text tasks:

```ts
timeoutMs: 120_000
```

The Swift side must still enforce the current `InferenceEngine` timeout guards.

### 3.4 Modality routing rule

The runtime must route inputs by modality before any prompt is built:

- **Text / "Check this text"**: do not run image context extraction, OCR, Vision OCR, or `generateVision`. Insert the user text directly into the marker extraction prompt as `{{INPUT_SUMMARY}}`, run feature extraction, score present markers, and return the threshold verdict.
- **Image / screenshot**: first run `IMAGE_CONTEXT_PROMPT` with the image using `generateVision`; treat the model output as the input summary for marker extraction.
- **Other future non-text modalities**: first run a modality-specific context extraction prompt/tool to produce plain text, then pass only that text summary into the same marker extraction prompt.

Only the marker extraction prompt may produce scam-marker JSON. Context extraction prompts must not classify, score, or label the content.

## 4. Prompts

Create a dedicated prompt container in Swift:

```text
ios/App/GemmaKit/Sources/Agents/Prompts/ModalityWeightedScamPrompts.swift
```

Do not reuse the existing direct-verdict `ImageAgentPrompts.analyseScreenshot` prompt for this notebook-derived path.

### 4.1 Stage A: image text transcription prompt

Use this prompt exactly as the image + text prompt for the first model call:

```swift
let IMAGE_CONTEXT_PROMPT = """
Transcribe all visible text in the image.

Rules:
- Copy the text as closely as possible.
- Preserve the reading order from top to bottom and left to right.
- Include sender/header text, message body, timestamps, links, buttons, warnings, labels, and visible replies.
- Preserve spelling, punctuation, capitalization, line breaks, phone numbers, emails, links, and money amounts when possible.
- Do not summarize.
- Do not classify the message.
- Do not judge whether it is legitimate, suspicious, safe, scam, phishing, or fraud.
- Do not infer or guess text that is not visible.
- If text is visible but unreadable, write [unclear].
- If text is cut off, write [cut off].
- Return plain text only.

VISIBLE TEXT:
"""
```

### 4.2 Stage B: single fixed marker extraction prompt

This implementation must not perform prompt ablation. Use one static text-only prompt for every modality after an input summary exists.

- For **text input**, `{{INPUT_SUMMARY}}` is the user-entered text from **Check this text**.
- For **image input**, `{{INPUT_SUMMARY}}` is the Stage A transcription returned from `IMAGE_CONTEXT_PROMPT`.
- For **future non-text modalities**, `{{INPUT_SUMMARY}}` is the modality-specific extracted plain-text context.

The marker extraction prompt must be this exact Prompt 2 conservative binary extractor:

```text
Extract structured observations from the following summary.

Important:
This is not a classification task. Do not say whether the message is scam, safe, suspicious, legitimate, or fraudulent. Only mark whether specific observable features are present or absent.

Be conservative:
- Mark "present" only when the summary explicitly supports it.
- Mark "absent" when the summary does not explicitly support it.
- Do not infer hidden motives.
- Do not treat possibilities as facts.
- If the feature is unclear, missing, cropped out, unverifiable, or not stated, mark "absent".
- Evidence must be one short string, never a list or array.
- Use only one "evidence" key per field.
- Do not recommend actions.
- Output only valid JSON with no surrounding text.
- Ignore phone/app UI text as evidence, such as Text Message, Delete, Reply, Forward, More, Report Spam, or warnings like "If you did not expect this message..."
- For unknown_sender, mark present for a raw email, bare phone number, unknown/unsaved contact, blank/hidden sender, or sender/header that does not match the claimed brand. Mark absent for a short code or sender name that appears to match one routine brand OTP or marketing message. Do not use app spam warnings, footer addresses, or body signatures as sender proof.
- For foreign_sender, mark present only when the summary directly shows non-USA origin evidence such as a non-US country/location, non-US country code, foreign address, foreign currency, foreign domain, or stated non-US origin.
- For impersonation, mark present when unknown_sender is present and the message names a brand, company, service, platform, agency, support team, authority, or executive in a job, prize, reward, survey, account, billing, subscription, payment, support, or security story. Mark absent for person-only messages and ordinary ads, coupons, donations, events, rentals, tours, tickets, or routine messages from a matching sender.
- For windfall, mark present for unusually high pay, free money, prizes, grants, lottery, inheritance, large rewards, valuable survey rewards, or too-good-to-be-true offers. Mark absent for normal discounts, coupons, sale prices, loyalty rewards, gift cards for donations, donation incentives, move-in specials, tickets, tours, or routine marketing.
- For opportunity, mark present only for jobs, remote tasks, recruiting, freelance work, business offers, investment offers, partnerships, or easy-earning offers. Mark absent for shopping, tickets, tours, apartments, cruises, events, coupons, donations, surveys, or ordinary ads.
- For pretexting, mark present for a wrong-number story, prior-relationship story, job story, prize story, survey-reward story, account issue, bill, subscription, renewal, payment issue, delivery, order, refund, or grant used to get a reply, click, payment, or information. Do not prove the story false. Mark absent for ordinary ads, sales, coupons, donation drives, event notices, rentals, tours, tickets, OTP codes, or opt-out text.
- For urgency, mark present for final warnings, threats, penalties, account loss, data loss, blocked access, deletion, payment failure, forced billing, emergency, secrecy, or act-now pressure tied to account, money, safety, prize, job, survey reward, or sensitive information. Mark absent for normal sale deadlines, coupon expiration, event dates, ticket dates, donation deadlines, appointment times, rental promos, or verification-code expiration.
- For sensitive_info, mark present when the message asks the recipient to provide, enter, update, review, confirm, or verify passwords, codes, account details, payment details, bank/card data, ID, SSN, documents, private data, name, identity, or relationship information. Mark absent when a verification code is only shown and the message does not ask the recipient to share or enter it.
- For financial_transfer, mark present when the recipient is asked to pay, send money, approve a charge, pay a fee/invoice, buy gift cards, send crypto, provide payment/banking details, or accept an auto-debit/charge. Mark absent for prices, discounts, gift cards, rewards, coupons, donation incentives, sweepstakes entries, or non-money donations.
- For external_action, mark present for a visible URL, link, domain, website, QR code, app download, phone/email contact, outside messaging/social channel, or button/action text such as review, update, apply, join, book, take survey, or visit site. The current SMS/email channel itself does not count.

Summary:
{{INPUT_SUMMARY}}

Use this exact JSON object and these exact keys. For each "status", replace "present | absent" with exactly one value: "present" or "absent".

{
  "unknown_sender": {
    "status": "present | absent",
    "evidence": ""
  },
  "foreign_sender": {
    "status": "present | absent",
    "evidence": ""
  },
  "impersonation": {
    "status": "present | absent",
    "evidence": ""
  },
  "windfall": {
    "status": "present | absent",
    "evidence": ""
  },
  "opportunity": {
    "status": "present | absent",
    "evidence": ""
  },
  "pretexting": {
    "status": "present | absent",
    "evidence": ""
  },
  "urgency": {
    "status": "present | absent",
    "evidence": ""
  },
  "sensitive_info": {
    "status": "present | absent",
    "evidence": ""
  },
  "financial_transfer": {
    "status": "present | absent",
    "evidence": ""
  },
  "external_action": {
    "status": "present | absent",
    "evidence": ""
  }
}
```

## 5. Feature Schema and Scoring

Create the scoring model in Swift under:

```text
ios/App/GemmaKit/Sources/Agents/Scoring/WeightedScamScorer.swift
```

If the `Scoring` directory does not exist, create it and ensure the Swift package target includes it automatically through the existing `Sources` path.

### 5.1 Feature keys

Define one canonical enum:

```swift
public enum ScamFeatureKey: String, Codable, CaseIterable, Sendable {
    case unknownSender = "unknown_sender"
    case foreignSender = "foreign_sender"
    case impersonation = "impersonation"
    case windfall = "windfall"
    case opportunity = "opportunity"
    case pretexting = "pretexting"
    case urgency = "urgency"
    case sensitiveInfo = "sensitive_info"
    case financialTransfer = "financial_transfer"
    case externalAction = "external_action"
}
```

Do not use alternate runtime names. The JSON keys, weights, parser, tests, and UI details must all use these raw values.

### 5.2 Weights

The app must use the notebook weights exactly:

```swift
public static let weights: [ScamFeatureKey: Double] = [
    .unknownSender: 0.0635,
    .foreignSender: 0.0353,
    .impersonation: 0.1667,
    .windfall: 0.0617,
    .opportunity: 0.0794,
    .pretexting: 0.2143,
    .urgency: 0.0970,
    .sensitiveInfo: 0.1235,
    .financialTransfer: 0.1146,
    .externalAction: 0.0441,
]
```

### 5.3 Threshold

```swift
public static let scamThreshold: Double = 0.22
```

Classification is inclusive:

```swift
let verdict: ScamVerdict = totalScore >= scamThreshold ? .scam : .safe
```

Do not return `.suspicious` from this notebook-derived weighted scoring path.

### 5.4 Score report types

Add typed scoring DTOs:

```swift
public enum ScamFeatureStatus: String, Codable, Sendable {
    case present
    case absent
}

public struct ScamFeatureObservation: Codable, Sendable {
    public let key: ScamFeatureKey
    public let status: ScamFeatureStatus
    public let evidence: String
}

public struct ScamFeatureScore: Codable, Sendable {
    public let key: ScamFeatureKey
    public let status: ScamFeatureStatus
    public let weight: Double
    public let contribution: Double
}

public struct WeightedScamScoreReport: Codable, Sendable {
    public let type: String              // always "weightedScamScore"
    public let totalScore: Double
    public let threshold: Double
    public let verdict: ScamVerdict
    public let features: [ScamFeatureScore]
    public let validationWarnings: [String]
    public let validJSON: Bool
}
```

### 5.5 Evidence privacy rule

The notebook stores extracted summaries and raw outputs in CSV. The app must not persist raw user text, raw extracted context, or raw model outputs in the normal `AgentResult` because text and screenshots may contain phone numbers, emails, account numbers, or other personal data.

Implementation rule:

- The text/image agent may keep the full input summary and raw marker output in local variables while building the result.
- `AgentResult` may include `WeightedScamScoreReport` without raw input summary text.
- Evidence strings must not be persisted unless redacted and truncated.
- If evidence is added later, redact phone numbers, emails, URLs, and long numeric IDs before putting it in `AgentResult` or Zustand storage.

## 6. JSON Parsing and Normalization

Create:

```text
ios/App/GemmaKit/Sources/Agents/Scoring/ScamMarkerParser.swift
```

### 6.1 Required parser behavior

The parser must match the notebook's robustness:

1. Try to parse the full raw output as JSON.
2. If that fails, extract the first balanced JSON object from the raw string.
3. The balanced-object extractor must be quote-aware and escape-aware.
4. Parse the extracted object as JSON.
5. If parsing still fails, return all ten features as absent with `validJSON = false` and a validation warning.
6. For each feature:
   - If the JSON value is an object, read `status`.
   - If the JSON value is a direct boolean/string/number, normalize that value directly.
   - Values `present`, `yes`, `true`, and `1` map to present.
   - Values `absent`, `no`, `false`, `0`, empty, missing, null, malformed, or unknown map to absent.
7. Missing feature keys must not throw. They must become absent and add a validation warning.

### 6.2 Parser output

```swift
public struct ScamMarkerParseResult: Sendable {
    public let observations: [ScamFeatureObservation]
    public let validJSON: Bool
    public let warnings: [String]
}
```

### 6.3 Markdown fence handling

Even though the prompt forbids markdown, the parser must handle model output like:

````text
```json
{ ... }
```
````

The balanced JSON object extractor is sufficient if implemented correctly.

## 7. Native Vision Inference Requirement

The current `InferenceEngine.generate(...)` accepts text prompts. The notebook requires image + prompt inference for Stage A. Add a vision-capable method through the inference stack.

### 7.1 Add image input type

Create:

```text
ios/App/GemmaKit/Sources/Inference/VisionInput.swift
```

```swift
public struct VisionInput: Sendable {
    public let base64: String
    public let mimeType: ImageMIMEType

    public init(base64: String, mimeType: ImageMIMEType) {
        self.base64 = base64
        self.mimeType = mimeType
    }
}
```

Use the existing `ImageMIMEType` enum from `AgentTask.swift` if visibility allows. If visibility becomes awkward, move `ImageMIMEType` to its own file and keep the raw values unchanged.

### 7.2 Extend `InferenceBackend`

Update `ios/App/GemmaKit/Sources/Inference/InferenceBackend.swift`:

```swift
public protocol InferenceBackend: Sendable {
    var isLoaded: Bool { get async }
    func loadModel(tier: ModelTier) async throws
    func unloadModel() async
    func generate(prompt: String, grammar: GrammarConstraint?, maxTokens: Int) async throws -> AsyncStream<String>
    func generateVision(prompt: String, image: VisionInput, maxTokens: Int) async throws -> AsyncStream<String>
}
```

### 7.3 Extend `InferenceEngine`

Add:

```swift
public func generateVision(
    prompt: String,
    image: VisionInput,
    modelTier: ModelTier,
    tokenHandler: (@Sendable (String) -> Void)? = nil
) async throws -> String
```

Behavior:

- Apply the same thermal guard as `generate`.
- Apply the same RSS guard as `generate`.
- Require E2B to be loaded.
- Use `maxTokens = 700` for this notebook-derived call unless overridden by an internal constant.
- Accumulate the stream into a full string.
- Log latency and token count.
- Do not store the image or extracted context in logs.

### 7.4 MLX backend implementation

Update `MLXInferenceBackend.generateVision(...)` to use the MLX Swift multimodal image input API provided by the existing `MLXLLM` / `MLXLMCommon` dependencies.

Implementation requirements:

- Decode base64 into image bytes.
- Preserve screenshot orientation.
- Do not crop.
- Do not apply contrast/sharpness hallucination-prone enhancements.
- Use the Stage A prompt as the text component.
- Return an `AsyncStream<String>` like `generate(...)`.
- If current MLX dependency APIs cannot accept image input, throw a dedicated `GemScanError.unsupportedModality("vision")` rather than silently performing OCR-only analysis.

### 7.5 llama.cpp fallback

The current llama.cpp backend is not the primary path for iOS. If it is not configured with a multimodal projector, `generateVision(...)` may throw `GemScanError.unsupportedModality("vision")`.

Do not fake Stage A with Vision OCR as a replacement for Gemma image extraction. Vision OCR can be an optional tool, but the notebook-derived pipeline requires the model to inspect the image.

## 8. ImageAgent Refactor

Replace the current direct-verdict image prompt flow in:

```text
ios/App/GemmaKit/Sources/Agents/ImageAgent.swift
```

### 8.1 New ImageAgent flow

`ImageAgent.analyse(task:)` must do the following:

1. Validate payload is `.image(base64Data, mimeType)`.
2. Build `VisionInput`.
3. Call `inferenceEngine.generateVision(prompt: imageContextPrompt, image: visionInput, modelTier: .e2b)`.
4. Trim the returned context summary.
5. Build the single marker extraction prompt with `{{INPUT_SUMMARY}}` replaced by the summary.
6. Call `inferenceEngine.generate(task: markerPrompt, modelTier: .e2b, grammar: markerExtractionGrammar)`.
7. Parse marker JSON using `ScamMarkerParser`.
8. Score using `WeightedScamScorer`.
9. Generate deterministic user-facing reasoning bullets from the top present markers.
10. Return `AgentResult` with:
    - `agentId = AgentID.imageAgent`
    - `verdict = .scam` or `.safe`
    - `confidence = distance-derived decision confidence`
    - `reasoning = deterministic bullets`
    - `language = "en"`
    - `toolCallsLog = []` unless real MCP tools are actually invoked
    - `modelTier = .e2b`
    - `lowConfidenceFallback = false`
    - `weightedScoreReport = report`

### 8.2 Do not use existing MCP placeholders as required inputs

The existing `ImageAgent` has placeholder methods for OCR, URL reputation, and vector search. For this notebook-derived implementation:

- Do not block on MCP integration.
- Do not include placeholder MCP text in the marker extraction prompt.
- Do not require URL reputation or vector search to classify the image.
- Do not let incomplete MCP tooling change the weighted score.

Future MCP enrichment can be added later, but the scoring algorithm in this spec must remain independent and deterministic.

### 8.3 Deterministic reasoning generation

Do not run a third LLM call to generate explanations. Build simple deterministic bullets from the score report.

Feature display labels:

```swift
unknown_sender       -> "The sender is not clearly verified."
foreign_sender       -> "The message shows a non-US sender or location clue."
impersonation        -> "The message may be pretending to be an organization or authority."
windfall             -> "The message offers an unexpected prize, refund, or benefit."
opportunity          -> "The message offers an unexpected job, task, or earning opportunity."
pretexting           -> "The message uses a setup or story to build trust."
urgency              -> "The message pressures you to act quickly."
sensitive_info       -> "The message asks for private or account information."
financial_transfer   -> "The message asks for money or a financial action."
external_action      -> "The message asks you to use a link, QR code, app, or outside contact method."
```

For `scam` results:

- Include the top 2-3 present features by contribution.
- First bullet should mention the weighted score crossed the threshold without exposing too much math: `"This screenshot has enough scam warning signs to be treated as unsafe."`
- Remaining bullets should be feature labels.

For `safe` results:

- Use: `"I did not find enough visible scam warning signs in this screenshot."`
- If any low-weight features are present below the threshold, include one bullet: `"I did notice: <top present feature label>"`.
- Do not say the message is guaranteed safe.

### 8.4 Confidence formula

`AgentResult.confidence` is a display confidence for the deterministic threshold decision, not a calibrated probability.

Use side-specific distance from the threshold:

```swift
let threshold = WeightedScamScorer.scamThreshold
let confidence: Double
if report.totalScore >= threshold {
    let normalized = min(1.0, (report.totalScore - threshold) / (1.0 - threshold))
    confidence = 0.50 + 0.49 * normalized
} else {
    let normalized = min(1.0, (threshold - report.totalScore) / threshold)
    confidence = 0.50 + 0.49 * normalized
}
```

If marker JSON is invalid or Stage B fails but returns text, set confidence to `0.50` after applying the notebook-compatible absent-feature fallback.

### 8.5 Orchestrator low-confidence fallback exception

The current `OrchestratorAgent` forces non-scam results to scam when confidence is below `0.75`. That behavior conflicts with the notebook's deterministic threshold rule.

Update `OrchestratorAgent.dispatch(task:)` so that `.analyseScreenshot` results from `ImageAgent` are not modified by the E2B low-confidence fallback.

Required logic:

```swift
if task.type == .analyseScreenshot {
    return specialistResult
}
```

Place this after specialist routing and before the generic low-confidence fallback.

### 8.6 Text input refactor for "Check this text"

When the user clicks **Check this text**, the app must not call `ImageAgent`, `generateVision`, Vision OCR, or `IMAGE_CONTEXT_PROMPT`.

Required text flow:

1. Validate payload is text.
2. Trim the user-entered text.
3. Build the single marker extraction prompt with `{{INPUT_SUMMARY}}` replaced by the trimmed user text.
4. Call `inferenceEngine.generate(prompt: markerPrompt, modelTier: .e2b, grammar: markerExtractionGrammar)`.
5. Parse marker JSON using `ScamMarkerParser`.
6. Score using `WeightedScamScorer`.
7. Generate deterministic user-facing reasoning bullets from the top present markers.
8. Return `AgentResult` with the same `WeightedScamScoreReport` contract used by images.

This means the text path and image path differ only in how `inputSummary` is produced. Feature extraction, parsing, scoring, confidence, and verdict logic must be shared.

Implementation options:

- Preferred: create a shared `WeightedScamAnalysisService` used by both text and image agents once `inputSummary` is available.
- Acceptable: keep the shared parser/scorer and duplicate only minimal prompt-call plumbing.

Do not use any direct-verdict text prompt for **Check this text** in this notebook-derived scoring path.

## 9. AgentResult Contract Changes

The app currently returns only verdict, confidence, reasoning, and logging data. The weighted modality-aware pipeline needs optional scoring metadata for tests, debugging, and future UI, while staying backward compatible.

### 9.1 Swift `AgentResult`

Update `ios/App/GemmaKit/Sources/Agents/AgentResult.swift`:

```swift
public struct AgentResult: Codable, Sendable {
    ...existing fields...
    public let weightedScoreReport: WeightedScamScoreReport?
}
```

Default this field to `nil` in the initializer so all existing agents and tests keep working.

### 9.2 TypeScript `AgentResult`

Update `src/lib/gemma/types.ts`:

```ts
export type ScamFeatureKey =
  | 'unknown_sender'
  | 'foreign_sender'
  | 'impersonation'
  | 'windfall'
  | 'opportunity'
  | 'pretexting'
  | 'urgency'
  | 'sensitive_info'
  | 'financial_transfer'
  | 'external_action'

export interface ScamFeatureScore {
  key: ScamFeatureKey
  status: 'present' | 'absent'
  weight: number
  contribution: number
}

export interface WeightedScamScoreReport {
  type: 'weightedScamScore'
  totalScore: number
  threshold: number
  verdict: ScamVerdict
  features: ScamFeatureScore[]
  validationWarnings: string[]
  validJSON: boolean
}

export interface AgentResult {
  ...existing fields...
  weightedScoreReport?: WeightedScamScoreReport
}
```

### 9.3 Persistence rule

`src/lib/store.ts` currently persists `recentResults`. Because `weightedScoreReport` contains no raw summary or raw screenshot text, it may be persisted.

Do not persist:

- raw image base64
- raw user-entered text beyond normal UI state required to run the analysis
- raw extracted image/modality context
- raw marker JSON output
- unredacted evidence strings

## 10. Grammar Constraint for Marker Extraction

Add an optional grammar factory to:

```text
ios/App/GemmaKit/Sources/Agents/Grammars/GrammarConstraint+Definitions.swift
```

Suggested grammar:

```swift
public static func markerExtractionGrammar() -> GrammarConstraint {
    GrammarConstraint(
        name: "marker_extraction",
        rawGBNF: """
        root ::= "{" ws "\"unknown_sender\"" ws ":" ws marker ws "," ws "\"foreign_sender\"" ws ":" ws marker ws "," ws "\"impersonation\"" ws ":" ws marker ws "," ws "\"windfall\"" ws ":" ws marker ws "," ws "\"opportunity\"" ws ":" ws marker ws "," ws "\"pretexting\"" ws ":" ws marker ws "," ws "\"urgency\"" ws ":" ws marker ws "," ws "\"sensitive_info\"" ws ":" ws marker ws "," ws "\"financial_transfer\"" ws ":" ws marker ws "," ws "\"external_action\"" ws ":" ws marker ws "}"
        marker ::= "{" ws "\"status\"" ws ":" ws status ws "," ws "\"evidence\"" ws ":" ws string ws "}"
        status ::= "\"present\"" | "\"absent\""
        string ::= "\"" chars "\""
        chars ::= ([^"\\] | "\\" ["\\/bfnrt] | "\\u" [0-9a-fA-F] [0-9a-fA-F] [0-9a-fA-F] [0-9a-fA-F])*
        ws ::= [ \t\n]*
        """
    )
}
```

MLX currently performs post-hoc grammar validation. The parser remains the source of truth for robust runtime behavior.

## 11. Next.js / Capacitor UI Changes

### 11.1 Add image capture/upload support

Current `src/app/page.tsx` has TODO buttons for camera and image upload. Implement them.

Recommended native path:

- Add `@capacitor/camera` compatible with Capacitor 6.
- Use `Camera.getPhoto({ resultType: CameraResultType.Base64, source: CameraSource.Camera })` for camera.
- Use `Camera.getPhoto({ resultType: CameraResultType.Base64, source: CameraSource.Photos })` for photo library.
- Map returned format to `image/jpeg` or `image/png`.
- Build an `AgentTask` with type `analyseScreenshot`.

Web fallback:

- Use a hidden `<input type="file" accept="image/png,image/jpeg,image/*">`.
- Convert the selected file to raw base64 by stripping the data URL prefix.
- Use the file MIME type when possible.

### 11.2 Fix text handoff while adding image handoff

The current home page routes to `/analyse` without passing the text input. Add a pending-analysis handoff in Zustand.

Update `src/lib/store.ts` with:

```ts
export type PendingAnalysisInput =
  | { kind: 'text'; content: string }
  | { kind: 'url'; url: string }
  | { kind: 'image'; base64: string; mimeType: 'image/jpeg' | 'image/png'; previewUrl?: string }

interface GemScanStore {
  pendingAnalysisInput: PendingAnalysisInput | null
  setPendingAnalysisInput: (input: PendingAnalysisInput | null) => void
}
```

Do not persist `pendingAnalysisInput` because it may contain image base64.

### 11.3 Build task from pending input on `/analyse`

Update `src/app/analyse/page.tsx`:

- If `pendingAnalysisInput` exists, run analysis immediately on mount.
- Clear `pendingAnalysisInput` after task creation.
- Keep the existing textarea fallback for direct text entry.
- For image tasks, show an image preview while analysis is running, but do not store the base64 after the result returns.
- For text tasks from **Check this text**, pass the text as the marker-extraction input summary. Do not trigger image context extraction.

Task building rules:

```ts
function buildTaskFromPending(input: PendingAnalysisInput): AgentTask {
  const id = `task-${Date.now()}`
  if (input.kind === 'image') {
    return {
      id,
      type: 'analyseScreenshot',
      payload: { type: 'image', base64: input.base64, mimeType: input.mimeType },
      priority: 'realtime',
      createdAt: Date.now(),
      timeoutMs: 120_000,
    }
  }
  if (input.kind === 'text') {
    return {
      id,
      type: 'analyseText',
      payload: { type: 'text', content: input.content },
      priority: 'realtime',
      createdAt: Date.now(),
      timeoutMs: 60_000,
    }
  }
  ...existing url behavior...
}
```

### 11.4 Verdict card display

`src/components/VerdictCard.tsx` can remain mostly unchanged.

Add an optional compact score line when `result.weightedScoreReport` exists:

```text
Weighted warning score: 0.31 / threshold 0.22
```

Accessibility:

- The score line must be readable by VoiceOver.
- Do not rely on color only.
- Do not display raw model JSON.
- Do not display raw screenshot summary.

### 11.5 Mock plugin support

Update `src/lib/gemma/mock.ts`:

- For `task.type === 'analyseScreenshot'`, return deterministic weighted-score fixtures.
- Include `weightedScoreReport` in at least one scam screenshot fixture and one safe screenshot fixture.
- Continue streaming reasoning tokens so UI tests remain useful.

## 12. Error Handling

### 12.1 Infrastructure errors

Infrastructure errors include:

- Model not downloaded.
- Model not loaded.
- Unsupported vision modality.
- Thermal critical state.
- Memory pressure refusal.
- Base64 decode failure.
- Image payload MIME unsupported.

These should reject through `GemmaPlugin.analyse(...)`. The existing TypeScript `makeConservativeResult(...)` path may display a conservative fallback to the user.

### 12.2 Marker JSON parse failure

Marker JSON parse failure is not an infrastructure error. It is part of the notebook-compatible scoring path.

Behavior:

- Return all features absent.
- `totalScore = 0.0`.
- `verdict = safe` because `0.0 < 0.22`.
- `validJSON = false`.
- Add a validation warning.
- Set display confidence to `0.50`.
- Include a reasoning bullet such as: `"I could not read all warning markers clearly, so this result has low confidence."`

This preserves notebook semantics while making uncertainty visible.

### 12.3 Stage A empty summary

If Stage A returns an empty string:

- Continue to Stage B with an empty summary only if the model call completed successfully.
- The Stage B parser will likely return all absent.
- Add validation warning: `empty_image_context_summary`.
- Set confidence to `0.50`.

If Stage A throws, reject as an infrastructure error.

## 13. Testing Requirements

### 13.1 Swift unit tests

Add tests under:

```text
ios/App/GemmaKit/Tests/WeightedScamScorerTests.swift
ios/App/GemmaKit/Tests/ScamMarkerParserTests.swift
ios/App/GemmaKit/Tests/ImageAgentWeightedPipelineTests.swift
```

Required test cases:

1. Score all features absent:
   - total score `0.0`
   - verdict `safe`
2. Score only `pretexting` present:
   - total score `0.2143`
   - verdict `safe`
3. Score `pretexting + external_action` present:
   - total score `0.2584`
   - verdict `scam`
4. Threshold boundary:
   - construct feature combination or direct scorer input equal to `0.22`
   - verdict `scam`
5. Nested status object parses correctly.
6. Direct boolean/string values parse correctly.
7. Markdown-fenced JSON parses correctly.
8. Invalid JSON returns all absent, `validJSON = false`, warning present.
9. Missing feature key returns absent and warning present.
10. `ImageAgent` mock backend executes two inference calls in order:
    - first returns context summary
    - second returns marker JSON
    - final result includes weighted report
11. Text analysis for **Check this text** executes exactly one marker-extraction inference call and does not call `generateVision`.
12. Text analysis uses the raw user text as `{{INPUT_SUMMARY}}` and returns the same weighted report shape as image analysis.

### 13.2 TypeScript tests

Update/add tests under:

```text
src/lib/gemma/__tests__/types.test.ts
src/lib/gemma/__tests__/mock.test.ts
src/components/__tests__/VerdictCard.test.tsx
src/lib/__tests__/store.test.ts
```

Required test cases:

1. `AgentResult` accepts optional `weightedScoreReport`.
2. Mock screenshot analysis returns a weighted score report.
3. VerdictCard renders weighted score line when present.
4. Zustand does not persist `pendingAnalysisInput`.
5. Image pending input creates `analyseScreenshot` task with timeout `120000`.

### 13.3 Manual iOS validation

Manual smoke test on device:

1. Install app.
2. Download E2B model from onboarding/settings.
3. Upload a screenshot containing a link and urgent bank/account language.
4. Confirm result is `scam`.
5. Upload a normal receipt/order-confirmation screenshot.
6. Confirm result is `safe` unless visible markers cross threshold.
7. Confirm app does not crash under repeated screenshot runs.
8. Confirm raw image base64 is not persisted in local storage or logs.

## 14. File-by-File Implementation Checklist

### Swift - new files

Create:

```text
ios/App/GemmaKit/Sources/Agents/Prompts/ModalityWeightedScamPrompts.swift
ios/App/GemmaKit/Sources/Agents/Scoring/WeightedScamScorer.swift
ios/App/GemmaKit/Sources/Agents/Scoring/ScamMarkerParser.swift
ios/App/GemmaKit/Sources/Inference/VisionInput.swift
```

### Swift - modified files

Modify:

```text
ios/App/App/GemmaPlugin.swift
ios/App/GemmaKit/Sources/Agents/ImageAgent.swift
ios/App/GemmaKit/Sources/Agents/OrchestratorAgent.swift
ios/App/GemmaKit/Sources/Agents/AgentResult.swift
ios/App/GemmaKit/Sources/Agents/Grammars/GrammarConstraint+Definitions.swift
ios/App/GemmaKit/Sources/Inference/InferenceBackend.swift
ios/App/GemmaKit/Sources/Inference/InferenceEngine.swift
ios/App/GemmaKit/Sources/Inference/MLXInferenceBackend.swift
ios/App/GemmaKit/Sources/Inference/LlamaCppInferenceBackend.swift
```

### TypeScript / Next.js - modified files

Modify:

```text
package.json
package-lock.json
src/lib/gemma/types.ts
src/lib/gemma/mock.ts
src/lib/store.ts
src/app/page.tsx
src/app/analyse/page.tsx
src/components/VerdictCard.tsx
```

Only add `@capacitor/camera` if implementing native camera/photo picker through Capacitor. If using browser file input only, do not add the dependency.

## 15. Acceptance Criteria

The implementation is complete when all of the following are true:

1. The app can submit an `analyseScreenshot` task from the UI.
2. The app can submit a text analysis task from **Check this text**.
3. The native bridge decodes the nested `{ task }` payload correctly.
4. `ImageAgent` performs two model calls: image context extraction, then text marker extraction.
5. **Check this text** performs one model call: marker extraction with the user text as `{{INPUT_SUMMARY}}`.
6. Text input does not call `IMAGE_CONTEXT_PROMPT`, `generateVision`, OCR, or image context extraction.
7. Only one marker extraction prompt exists in runtime code, and it matches Prompt 2 from `scam_marker_extraction_prompts (2)(1).md`.
8. No prompt ablation code exists in runtime code.
9. The target feature keys exactly match:
   - `unknown_sender`
   - `foreign_sender`
   - `impersonation`
   - `windfall`
   - `opportunity`
   - `pretexting`
   - `urgency`
   - `sensitive_info`
   - `financial_transfer`
   - `external_action`
10. The weights exactly match the notebook values.
11. The threshold is exactly `0.22` and is inclusive.
12. `pretexting` alone scores `0.2143` and returns `safe`.
13. `pretexting + external_action` scores `0.2584` and returns `scam`.
14. Invalid marker JSON does not crash the app.
15. Raw image base64, raw extracted context, raw user text, and raw marker output are not persisted.
16. `npm run typecheck`, `npm run lint`, and `npm run test:unit` pass.
17. Swift unit tests for parser/scorer pass in Xcode or `swift test` where applicable.

## 16. Implementation Notes for Claude

- Treat this as an in-place refactor of the existing repo.
- Do not create parallel `_NEW` files.
- Do not replace the app architecture.
- Do not add a backend server for inference.
- Do not move inference to Next.js.
- Do not use Python in the app runtime.
- Keep the privacy-first local inference design.
- Prefer typed Swift structs/enums over dictionaries after the JSON boundary.
- Keep dictionary parsing isolated inside `ScamMarkerParser`.
- Keep the scoring function deterministic and side-effect free.
- Keep prompts in one Swift prompt file so future prompt changes are auditable.
- Avoid putting raw user content in logs.

## 17. Future Work Not Included

The following are intentionally out of scope for this implementation:

- Re-running prompt ablation on-device.
- Threshold re-calibration.
- Adding E4B or JudgeAgent escalation.
- Adding cloud fallback.
- Adding URL reputation or vector-search signals into the weighted score.
- Persisting full analysis traces.
- Fine-tuning or distillation.
- W&B or metrics dashboard integration.

