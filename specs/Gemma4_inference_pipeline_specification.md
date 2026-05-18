# GemScan iOS Specification: Gemma 4 E2B 4-bit Modality-Aware Weighted Scam Detection

## 0. Purpose

This specification converts the notebook `10_6_prompt_ablation_classic_gemma_e2b_4_bit.ipynb` into an implementation plan for the existing GemScan repository.

The target implementation is a native iOS modality-aware scam detection path exposed through the existing Next.js + Capacitor app shell and implemented inside the existing Swift `GemmaKit` package. Text input uses the marker-extraction model call directly. Image input first uses Apple Vision OCR to extract visible text, then uses the same marker-extraction and scoring path. After deterministic scoring, the app performs one additional local Gemma 4 E2B explanation call to produce a user-facing explanation and recommended action.

The notebook was an experiment. The app implementation must be a deterministic production pipeline with a separate explanation stage:

1. User provides text, a screenshot/image, or another supported modality.
2. If the user clicks **Check this text**, the app skips OCR/context extraction and uses the user-entered text directly as `{{INPUT_SUMMARY}}`.
3. If the input is an image/screenshot, Apple Vision OCR extracts visible text from the image.
4. Future non-text modalities must also perform a modality-specific context-extraction step before marker extraction.
5. Gemma 4 E2B runs one fixed marker-extraction prompt against the input summary.
6. The app parses marker JSON into binary feature statuses.
7. The app applies the notebook's fixed feature weights.
8. The app sums the weighted score.
9. The app returns `scam` when `totalScore >= 0.22`; otherwise it returns `safe`.
10. The app builds a compact explanation input JSON from the input summary, parsed features, weighted score report, and final verdict.
11. Gemma 4 E2B runs one fixed explanation/action prompt against that JSON.
12. The app returns the deterministic verdict plus the generated user-facing explanation and recommended action.

Core rule:

```text
Stage B decides. Stage C explains.
```

The Stage C explanation call must never modify the verdict, score, threshold, feature statuses, or weighted-score metadata.

## 1. Source Notebook Behavior to Preserve

### 1.1 Keep

Preserve these runtime behaviors from the notebook:

- Model family/display name: `Gemma4:E2B`.
- Quantization concept: `4-bit`.
- Runtime temperature: `0.0` / deterministic generation.
- Maximum generation size for notebook-equivalent prompts: `700` new tokens unless the native backend requires a higher internal cap.
- Modality-aware inference flow:
  - Text input: text-only structured marker extraction call, deterministic scoring, then one text-only explanation/action call.
  - Image input: Apple Vision OCR first, then text-only structured marker extraction, deterministic scoring, then one text-only explanation/action call.
  - Future non-text input: modality-specific local context extraction first, then the same marker extraction, scoring, and explanation path.
- Robust JSON parsing from raw model output.
- Missing, malformed, absent, false, no, empty, or parse-failed marker values normalize to absent.
- Nested marker objects with `{ "status": "present" | "absent", "evidence": "..." }` are supported.
- Score threshold is inclusive: score equal to threshold is `scam`.
- The weighted score is the only source of truth for the verdict.
- Stage C may explain the already-decided result but must not reclassify the input.

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
  -> user clicks "Check this text" OR submits/shares image/screenshot
  -> build AgentTask from input modality
  -> GemmaPluginNative.analyse(task)
  -> GemmaPlugin.swift decodes AgentTask
  -> OrchestratorAgent.dispatch(task)

Text path:
  -> Text/URL agent uses the user text directly as INPUT_SUMMARY
  -> InferenceEngine.generate(text-only MARKER_EXTRACTION_PROMPT with user text)

Image path:
  -> ImageAgent.analyse(task)
  -> Apple Vision OCR extracts visible text from the image
  -> use OCR text as INPUT_SUMMARY
  -> InferenceEngine.generate(text-only MARKER_EXTRACTION_PROMPT with OCR text)

Shared scoring path:
  -> ScamMarkerParser.parse(rawMarkerOutput)
  -> WeightedScamScorer.score(features)
  -> deterministic verdict = scam when totalScore >= 0.22, otherwise safe

Shared explanation path:
  -> build ExplanationInput JSON from INPUT_SUMMARY, marker observations, score report, and verdict
  -> InferenceEngine.generate(text-only EXPLANATION_ACTION_PROMPT with ExplanationInput JSON)
  -> ScamExplanationParser.parse(rawExplanationOutput)
  -> build AgentResult(verdict, confidence, explanation, scoring metadata)
  -> GemmaPlugin returns AgentResult to TypeScript
  -> VerdictCard renders result, explanation, and recommended action
```

The marker extraction and weighted scoring path remains deterministic. The explanation path is user-facing only.

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

Text analysis performs two model calls after the user text is available:

1. marker extraction
2. explanation/action generation

Recommended text timeout:

```ts
timeoutMs: 90_000
```

Image/screenshot analysis performs Apple Vision OCR and then two model calls:

1. marker extraction
2. explanation/action generation

Recommended screenshot timeout:

```ts
timeoutMs: 120_000
```

The Swift side must still enforce the current `InferenceEngine` timeout guards.

### 3.4 Modality routing rule

The runtime must route inputs by modality before any prompt is built:

- **Text / "Check this text"**: do not run image OCR, image context extraction, Vision image analysis, or multimodal model inference. Insert the user text directly into the marker extraction prompt as `{{INPUT_SUMMARY}}`, run feature extraction, score present markers, then run the explanation/action prompt.
- **Image / screenshot**: first run Apple Vision OCR over the image. Treat the OCR text as the input summary for marker extraction. Then run scoring and explanation.
- **Other future non-text modalities**: first run a modality-specific local context extraction prompt/tool to produce plain text, then pass only that text summary into the same marker extraction prompt. Then run scoring and explanation.

Only the marker extraction prompt may produce scam-marker JSON. Context extraction and OCR stages must not classify, score, or label the content.

Only the deterministic weighted scoring step may decide the verdict. The explanation/action prompt must not change the verdict, score, threshold, or feature statuses.

## 4. Prompts

Create a dedicated prompt container in Swift:

```text
ios/App/GemmaKit/Sources/Agents/Prompts/ModalityWeightedScamPrompts.swift
```

Do not reuse the existing direct-verdict `ImageAgentPrompts.analyseScreenshot` prompt for this notebook-derived path.

This file must contain:

1. the fixed Stage B marker extraction prompt
2. the fixed Stage C explanation/action prompt

Stage A image text extraction uses Apple Vision OCR and does not require a Gemma prompt.

### 4.1 Stage A: Apple Vision OCR text extraction

Image text extraction is performed with Apple Vision OCR, not a Gemma vision prompt.

Implementation requirements:

- Use Apple's Vision framework, such as `VNRecognizeTextRequest`, to extract visible text from screenshots/images.
- Preserve reading order as closely as possible from top to bottom and left to right.
- Include sender/header text, message body, timestamps, links, buttons, warnings, labels, and visible replies when OCR detects them.
- Preserve spelling, punctuation, capitalization, line breaks, phone numbers, emails, links, and money amounts when possible.
- Do not classify the message during OCR.
- Do not score the message during OCR.
- Do not infer or guess text that OCR cannot read.
- If no text is detected, return an empty string and add the `empty_image_ocr_text` validation warning downstream.
- Do not store the raw image or OCR text in logs, `AgentResult`, Zustand, or `recentResults`.

Stage A output is plain text and becomes `{{INPUT_SUMMARY}}` for Stage B.

### 4.2 Stage B: single fixed marker extraction prompt

This implementation must not perform prompt ablation. Use one static text-only prompt for every modality after an input summary exists.

- For **text input**, `{{INPUT_SUMMARY}}` is the user-entered text from **Check this text**.
- For **image input**, `{{INPUT_SUMMARY}}` is the Stage A Apple Vision OCR text.
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


### 4.3 Stage C: explanation and recommended action prompt

After deterministic scoring, run one additional text-only Gemma 4 E2B call to generate the user-facing explanation and recommended action.

The explanation call receives compact JSON, not raw model traces. The input should include:

```json
{
  "input_text": "{{INPUT_SUMMARY}}",
  "verdict": "scam",
  "total_score": 0.2584,
  "threshold": 0.22,
  "present_features": [
    {
      "key": "pretexting",
      "evidence": "subscription will renew"
    },
    {
      "key": "external_action",
      "evidence": "call [phone_number]"
    }
  ]
}
```

The `input_text` value may be the user-entered text or Apple OCR text. It is used only in memory for the local explanation call and must not be persisted.

Use this prompt exactly for Stage C:

```swift
let EXPLANATION_ACTION_PROMPT = """
You are explaining a scam-detection result to a normal user.

The verdict has already been determined by a deterministic scoring system.
Do not change the verdict.
Do not question the verdict.
Do not recalculate the score.
Do not change any feature status.
Do not introduce new scam features.
Do not invent facts.
Use only the provided input text, verdict, score, threshold, present features, and evidence.
Use the original input text to make short evidence easier to understand.
Write simply and directly.

Return only valid JSON with this exact shape:

{
  "summary": "",
  "warning_signs": [],
  "recommended_action": "",
  "safety_note": ""
}

Field rules:
- "summary" must be one or two plain-language sentences explaining the verdict.
- "warning_signs" must contain 1 to 4 short bullet strings.
- "recommended_action" must be one practical next step.
- "safety_note" may be an empty string if no extra caution is needed.
- For scam results, tell the user not to use suspicious links, phone numbers, QR codes, payment instructions, or contact methods from the message.
- For safe results, do not say the message is guaranteed safe. Say that not enough visible warning signs were found.
- Do not include markdown.
- Do not include the raw score unless it is already present in the JSON input and needed for clarity.
- Do not mention internal feature names unless they are rewritten in normal language.

Input JSON:
{{EXPLANATION_INPUT_JSON}}
"""
```

The Stage C explanation must not become a second classifier. Its output is user-facing explanation text only.


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

### 5.5 Evidence and explanation privacy rule

The notebook stores extracted summaries and raw outputs in CSV. The app must not persist raw user text, raw OCR text, raw extracted context, raw model outputs, or raw explanation inputs in the normal `AgentResult` because text and screenshots may contain phone numbers, emails, account numbers, or other personal data.

Implementation rule:

- The text/image agent may keep the full input summary, raw marker output, parsed marker observations, and raw explanation output in local variables while building the result.
- `AgentResult` may include `WeightedScamScoreReport` without raw input summary text.
- `AgentResult` may include `ScamExplanation` because it is user-facing output.
- Evidence strings may be used in memory for Stage C explanation generation.
- Evidence strings must not be persisted unless redacted and truncated.
- Before building Stage C explanation input JSON, redact obvious sensitive tokens where practical:
  - phone numbers -> `[phone_number]`
  - emails -> `[email]`
  - URLs/domains -> `[url]`
  - long numeric identifiers -> `[number]`
- Do not over-redact ordinary scam context such as brand names, dollar amounts, or action verbs, because the explanation needs enough context to be useful.
- Raw image base64, raw OCR text, raw user-entered text, raw marker JSON output, and raw explanation input JSON must not be stored in Zustand, `recentResults`, logs, analytics, or crash metadata.

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

## 7. Native Apple Vision OCR Requirement

The image path uses Apple Vision OCR for Stage A text extraction. This replaces the earlier Gemma vision transcription requirement for this implementation.

### 7.1 Add OCR extractor

Create:

```text
ios/App/GemmaKit/Sources/Agents/OCR/AppleVisionOCRExtractor.swift
```

Suggested interface:

```swift
public protocol ImageTextExtracting: Sendable {
    func extractText(base64: String, mimeType: ImageMIMEType) async throws -> String
}

public final class AppleVisionOCRExtractor: ImageTextExtracting, Sendable {
    public init() {}
    public func extractText(base64: String, mimeType: ImageMIMEType) async throws -> String {
        // Decode base64, create CGImage/UIImage, run VNRecognizeTextRequest,
        // sort observations into stable reading order, and return plain text.
    }
}
```

Use the existing `ImageMIMEType` enum from `AgentTask.swift` if visibility allows. If visibility becomes awkward, move `ImageMIMEType` to its own file and keep the raw values unchanged.

### 7.2 OCR behavior

Implementation requirements:

- Decode raw base64 image bytes.
- Support `image/jpeg` and `image/png`.
- Preserve screenshot orientation.
- Do not crop the image.
- Do not apply contrast/sharpness hallucination-prone enhancements.
- Use Apple Vision text recognition locally on device.
- Prefer accurate recognition over aggressive correction.
- Return plain text only.
- If no text is found, return an empty string rather than throwing.
- If base64 decode fails or image decoding fails, throw an infrastructure error.

### 7.3 Reading order

Vision observations may not arrive in user-readable order. The extractor should sort recognized text approximately:

1. top to bottom
2. left to right within each line/row

Do not attempt semantic reconstruction beyond ordering OCR observations. OCR must not classify or score content.

### 7.4 Error handling

Infrastructure errors include:

- Base64 decode failure.
- Unsupported image MIME type.
- Image decoding failure.
- Vision framework failure.

No-text results are not infrastructure errors. They should return `""` and allow the scoring path to continue with an `empty_image_ocr_text` validation warning.

### 7.5 Gemma vision out of scope

Do not add `generateVision(...)`, `VisionInput`, multimodal MLX inference, or llama.cpp multimodal projector work for this implementation.

Gemma vision image transcription can be reconsidered later, but the scoped implementation uses Apple Vision OCR for Stage A.

## 8. ImageAgent Refactor

Replace the current direct-verdict image prompt flow in:

```text
ios/App/GemmaKit/Sources/Agents/ImageAgent.swift
```

### 8.1 New ImageAgent flow

`ImageAgent.analyse(task:)` must do the following:

1. Validate payload is `.image(base64Data, mimeType)`.
2. Run Apple Vision OCR through `AppleVisionOCRExtractor`.
3. Trim the OCR text and treat it as `inputSummary`.
4. Build the single marker extraction prompt with `{{INPUT_SUMMARY}}` replaced by `inputSummary`.
5. Call `inferenceEngine.generate(prompt: markerPrompt, modelTier: .e2b, grammar: markerExtractionGrammar)`.
6. Parse marker JSON using `ScamMarkerParser`.
7. Score using `WeightedScamScorer`.
8. Derive the deterministic verdict from the weighted score.
9. Build compact `ExplanationInput` JSON from:
   - `inputSummary`
   - final verdict
   - `totalScore`
   - threshold
   - present feature observations and redacted evidence
10. Call `inferenceEngine.generate(prompt: explanationPrompt, modelTier: .e2b, grammar: explanationGrammarOrNil)`.
11. Parse explanation JSON using `ScamExplanationParser`.
12. Return `AgentResult` with:
    - `agentId = AgentID.imageAgent`
    - `verdict = .scam` or `.safe`
    - `confidence = distance-derived decision confidence`
    - `reasoning = explanation.warningSigns` or a fallback summary
    - `explanation = ScamExplanation`
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

### 8.3 Stage C explanation generation

Run a third local processing stage after deterministic scoring.

This is the only generation step that may produce user-facing prose. It must use the fixed `EXPLANATION_ACTION_PROMPT`.

Input construction rules:

- Include the original `inputSummary` so the model can expand short feature evidence into useful explanation.
- Include only the final verdict determined by `WeightedScamScorer`.
- Include `totalScore` and `threshold`.
- Include only present features by default.
- Include feature evidence after redaction/truncation.
- Do not include raw marker model output.
- Do not include absent features unless needed for a safe-result explanation.
- Do not include raw image base64.

Example explanation input:

```json
{
  "input_text": "Thank you. Your Wells Fargo subscription will renew today for $90. To cancel or dispute, call [phone_number].",
  "verdict": "scam",
  "total_score": 0.4251,
  "threshold": 0.22,
  "present_features": [
    {
      "key": "impersonation",
      "evidence": "Wells Fargo"
    },
    {
      "key": "pretexting",
      "evidence": "subscription will renew"
    },
    {
      "key": "external_action",
      "evidence": "call [phone_number]"
    }
  ]
}
```

Output parsing rules:

- Parse the explanation response as JSON.
- If JSON parsing succeeds, use the returned `summary`, `warning_signs`, `recommended_action`, and `safety_note`.
- If parsing fails, return a fallback explanation without changing the verdict or score.
- If the explanation contradicts the deterministic verdict, ignore the contradiction and use a fallback explanation.

Fallback explanation for `scam`:

```text
This looks unsafe because the weighted scam warning signs crossed the app's threshold.
```

Fallback recommended action for `scam`:

```text
Do not follow links, phone numbers, QR codes, payment instructions, or contact methods from this message. Verify through the official app, website, or a trusted contact.
```

Fallback explanation for `safe`:

```text
I did not find enough visible scam warning signs to mark this as a scam.
```

Fallback recommended action for `safe`:

```text
This is not a guarantee. If anything feels unusual, verify through an official source before acting.
```

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

Stage C explanation success or failure must not change confidence.

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

Apply the same exception to text-analysis results using this weighted scoring path if the existing low-confidence fallback would otherwise override them.

### 8.6 Text input refactor for "Check this text"

When the user clicks **Check this text**, the app must not call `ImageAgent`, Apple Vision OCR, image context extraction, Vision image analysis, or any image prompt.

Required text flow:

1. Validate payload is text.
2. Trim the user-entered text.
3. Treat the trimmed text as `inputSummary`.
4. Build the single marker extraction prompt with `{{INPUT_SUMMARY}}` replaced by `inputSummary`.
5. Call `inferenceEngine.generate(prompt: markerPrompt, modelTier: .e2b, grammar: markerExtractionGrammar)`.
6. Parse marker JSON using `ScamMarkerParser`.
7. Score using `WeightedScamScorer`.
8. Derive the deterministic verdict from the weighted score.
9. Build compact `ExplanationInput` JSON from the text, parsed present features, weighted score report, and verdict.
10. Call `inferenceEngine.generate(prompt: explanationPrompt, modelTier: .e2b, grammar: explanationGrammarOrNil)`.
11. Parse explanation JSON using `ScamExplanationParser`.
12. Return `AgentResult` with the same `WeightedScamScoreReport` and `ScamExplanation` contract used by images.

This means the text path and image path differ only in how `inputSummary` is produced. Feature extraction, parsing, scoring, confidence, explanation generation, and verdict logic must be shared.

Implementation options:

- Preferred: create a shared `WeightedScamAnalysisService` used by both text and image agents once `inputSummary` is available.
- Acceptable: keep the shared parser/scorer/explanation builder and duplicate only minimal prompt-call plumbing.

Do not use any direct-verdict text prompt for **Check this text** in this notebook-derived scoring path.

## 9. AgentResult Contract Changes

The app currently returns only verdict, confidence, reasoning, and logging data. The weighted modality-aware pipeline needs optional scoring metadata and a user-facing explanation, while staying backward compatible.

### 9.1 Swift `AgentResult`

Add a user-facing explanation type:

```swift
public struct ScamExplanation: Codable, Sendable {
    public let summary: String
    public let warningSigns: [String]
    public let recommendedAction: String
    public let safetyNote: String?

    public init(
        summary: String,
        warningSigns: [String],
        recommendedAction: String,
        safetyNote: String? = nil
    ) {
        self.summary = summary
        self.warningSigns = warningSigns
        self.recommendedAction = recommendedAction
        self.safetyNote = safetyNote
    }
}
```

Update `ios/App/GemmaKit/Sources/Agents/AgentResult.swift`:

```swift
public struct AgentResult: Codable, Sendable {
    ...existing fields...
    public let weightedScoreReport: WeightedScamScoreReport?
    public let explanation: ScamExplanation?
}
```

Default both fields to `nil` in the initializer so all existing agents and tests keep working.

### 9.2 Explanation input and parser types

Create explanation-specific DTOs near the scoring/explanation service:

```swift
public struct ScamExplanationInput: Codable, Sendable {
    public let inputText: String
    public let verdict: ScamVerdict
    public let totalScore: Double
    public let threshold: Double
    public let presentFeatures: [ScamExplanationFeature]
}

public struct ScamExplanationFeature: Codable, Sendable {
    public let key: ScamFeatureKey
    public let evidence: String
}
```

Create:

```text
ios/App/GemmaKit/Sources/Agents/Scoring/ScamExplanationParser.swift
```

Required parser behavior:

- Try to parse full raw output as JSON.
- If that fails, extract the first balanced JSON object and parse it.
- Read `summary`, `warning_signs`, `recommended_action`, and `safety_note`.
- Accept camelCase variants only as a fallback, but normalize internally to Swift camelCase.
- If parsing fails, return the fallback explanation for the already-decided verdict.
- If the explanation contradicts the verdict, return the fallback explanation.

### 9.3 TypeScript `AgentResult`

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

export interface ScamExplanation {
  summary: string
  warningSigns: string[]
  recommendedAction: string
  safetyNote?: string
}

export interface AgentResult {
  ...existing fields...
  weightedScoreReport?: WeightedScamScoreReport
  explanation?: ScamExplanation
}
```

### 9.4 Persistence rule

`src/lib/store.ts` currently persists `recentResults`. Because `weightedScoreReport` contains no raw summary or raw screenshot text, it may be persisted.

`ScamExplanation` may also be persisted because it is the user-facing result shown to the user.

Do not persist:

- raw image base64
- raw user-entered text beyond normal UI state required to run the analysis
- raw Apple OCR text
- raw extracted image/modality context
- raw marker JSON output
- raw explanation input JSON
- unredacted evidence strings

## 10. Grammar Constraints

Add an optional marker grammar factory to:

```text
ios/App/GemmaKit/Sources/Agents/Grammars/GrammarConstraint+Definitions.swift
```

Suggested marker grammar:

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

Add an optional explanation grammar only if it is practical with the current backend:

```swift
public static func scamExplanationGrammar() -> GrammarConstraint {
    GrammarConstraint(
        name: "scam_explanation",
        rawGBNF: """
        root ::= "{" ws "\"summary\"" ws ":" ws string ws "," ws "\"warning_signs\"" ws ":" ws stringArray ws "," ws "\"recommended_action\"" ws ":" ws string ws "," ws "\"safety_note\"" ws ":" ws string ws "}"
        stringArray ::= "[" ws string (ws "," ws string)* ws "]"
        string ::= "\"" chars "\""
        chars ::= ([^"\\] | "\\" ["\\/bfnrt] | "\\u" [0-9a-fA-F] [0-9a-fA-F] [0-9a-fA-F] [0-9a-fA-F])*
        ws ::= [ \t\n]*
        """
    )
}
```

MLX currently performs post-hoc grammar validation. The parser remains the source of truth for robust runtime behavior for both marker extraction and explanation generation.

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

Do not persist `pendingAnalysisInput` because it may contain image base64 or raw user text.

### 11.3 Build task from pending input on `/analyse`

Update `src/app/analyse/page.tsx`:

- If `pendingAnalysisInput` exists, run analysis immediately on mount.
- Clear `pendingAnalysisInput` after task creation.
- Keep the existing textarea fallback for direct text entry.
- For image tasks, show an image preview while analysis is running, but do not store the base64 after the result returns.
- For text tasks from **Check this text**, pass the text as the marker-extraction input summary. Do not trigger image OCR or image context extraction.

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
      timeoutMs: 90_000,
    }
  }
  ...existing url behavior...
}
```

### 11.4 Verdict card display

Update `src/components/VerdictCard.tsx` to render the weighted score and explanation when available.

Add an optional compact score line when `result.weightedScoreReport` exists:

```text
Weighted warning score: 0.31 / threshold 0.22
```

Add explanation display when `result.explanation` exists:

- summary
- warning signs
- recommended action
- optional safety note

Accessibility:

- The score line, explanation, and recommended action must be readable by VoiceOver.
- Do not rely on color only.
- Do not display raw model JSON.
- Do not display raw screenshot summary or raw OCR text.
- Do not expose raw evidence strings unless they are already redacted and intentionally included in user-facing explanation.

### 11.5 Mock plugin support

Update `src/lib/gemma/mock.ts`:

- For `task.type === 'analyseScreenshot'`, return deterministic weighted-score fixtures.
- Include `weightedScoreReport` and `explanation` in at least one scam screenshot fixture and one safe screenshot fixture.
- For `task.type === 'analyseText'`, return deterministic weighted-score and explanation fixtures.
- Continue streaming reasoning tokens so UI tests remain useful.

## 12. Error Handling

### 12.1 Infrastructure errors

Infrastructure errors include:

- Model not downloaded.
- Model not loaded.
- Thermal critical state.
- Memory pressure refusal.
- Base64 decode failure.
- Image payload MIME unsupported.
- Image decoding failure.
- Apple Vision OCR framework failure.

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
- Continue to Stage C when possible so the user receives a low-confidence explanation.
- Include a warning sign or safety note such as: `"I could not read all warning markers clearly, so this result has low confidence."`

This preserves notebook semantics while making uncertainty visible.

### 12.3 Stage A empty OCR text

If Apple Vision OCR returns an empty string:

- Continue to Stage B with an empty summary.
- Add validation warning: `empty_image_ocr_text`.
- The Stage B parser will likely return all absent.
- Set confidence to `0.50`.
- Continue to Stage C with the empty input summary and the warning metadata if possible.

If Apple Vision OCR throws, reject as an infrastructure error.

### 12.4 Stage C explanation failure

Stage C explanation failure must not change the deterministic verdict or weighted score.

If the explanation model call throws:

- Return the deterministic verdict and `weightedScoreReport`.
- Return a fallback `ScamExplanation`.
- Add a validation warning such as `explanation_generation_failed` if the result metadata supports it.

If the explanation model call returns invalid JSON:

- Parse failure is not an infrastructure error.
- Return the deterministic verdict and `weightedScoreReport`.
- Return a fallback `ScamExplanation`.
- Add a validation warning such as `invalid_explanation_json` if the result metadata supports it.

If the explanation contradicts the deterministic verdict:

- Ignore the contradictory explanation.
- Return a fallback `ScamExplanation`.
- Do not change verdict, score, threshold, feature statuses, or confidence.

## 13. Testing Requirements

### 13.1 Swift unit tests

Add tests under:

```text
ios/App/GemmaKit/Tests/WeightedScamScorerTests.swift
ios/App/GemmaKit/Tests/ScamMarkerParserTests.swift
ios/App/GemmaKit/Tests/ScamExplanationParserTests.swift
ios/App/GemmaKit/Tests/ImageAgentWeightedPipelineTests.swift
ios/App/GemmaKit/Tests/TextWeightedPipelineTests.swift
ios/App/GemmaKit/Tests/AppleVisionOCRExtractorTests.swift
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
10. `ImageAgent` mock pipeline runs OCR before marker extraction.
11. `ImageAgent` mock pipeline executes two Gemma text calls in order after OCR:
    - first returns marker JSON
    - second returns explanation JSON
12. Final image result includes `weightedScoreReport` and `explanation`.
13. Text analysis for **Check this text** executes exactly two Gemma text calls:
    - marker extraction
    - explanation/action generation
14. Text analysis does not call Apple Vision OCR.
15. Text analysis uses the raw user text as `{{INPUT_SUMMARY}}` and returns the same weighted report and explanation shape as image analysis.
16. Explanation input includes verdict, total score, threshold, present features, and redacted evidence.
17. Explanation parser accepts valid snake_case JSON.
18. Explanation parser returns fallback explanation for invalid JSON.
19. Explanation parser ignores output that contradicts the deterministic verdict.
20. Stage C failure does not change verdict, score, threshold, feature statuses, or confidence.
21. Raw OCR text is not included in `AgentResult`.

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
2. `AgentResult` accepts optional `explanation`.
3. Mock screenshot analysis returns a weighted score report and explanation.
4. Mock text analysis returns a weighted score report and explanation.
5. VerdictCard renders weighted score line when present.
6. VerdictCard renders explanation summary when present.
7. VerdictCard renders warning signs when present.
8. VerdictCard renders recommended action when present.
9. Zustand does not persist `pendingAnalysisInput`.
10. Zustand does not persist raw image base64.
11. Image pending input creates `analyseScreenshot` task with timeout `120000`.
12. Text pending input creates `analyseText` task with timeout `90000`.

### 13.3 Manual iOS validation

Manual smoke test on device:

1. Install app.
2. Download E2B model from onboarding/settings.
3. Upload a screenshot containing a link and urgent bank/account language.
4. Confirm Apple Vision OCR extracts visible text well enough for analysis.
5. Confirm result is `scam`.
6. Confirm result includes an explanation and recommended action.
7. Upload a normal receipt/order-confirmation screenshot.
8. Confirm result is `safe` unless visible markers cross threshold.
9. Confirm safe result does not claim the message is guaranteed safe.
10. Confirm app does not crash under repeated screenshot runs.
11. Confirm raw image base64 is not persisted in local storage or logs.
12. Confirm raw OCR text is not persisted in local storage, logs, or `recentResults`.

## 14. File-by-File Implementation Checklist

### Swift - new files

Create:

```text
ios/App/GemmaKit/Sources/Agents/Prompts/ModalityWeightedScamPrompts.swift
ios/App/GemmaKit/Sources/Agents/Scoring/WeightedScamScorer.swift
ios/App/GemmaKit/Sources/Agents/Scoring/ScamMarkerParser.swift
ios/App/GemmaKit/Sources/Agents/Scoring/ScamExplanationParser.swift
ios/App/GemmaKit/Sources/Agents/OCR/AppleVisionOCRExtractor.swift
```

Optional shared service, if useful:

```text
ios/App/GemmaKit/Sources/Agents/Scoring/WeightedScamAnalysisService.swift
```

### Swift - modified files

Modify:

```text
ios/App/App/GemmaPlugin.swift
ios/App/GemmaKit/Sources/Agents/ImageAgent.swift
ios/App/GemmaKit/Sources/Agents/OrchestratorAgent.swift
ios/App/GemmaKit/Sources/Agents/AgentResult.swift
ios/App/GemmaKit/Sources/Agents/Grammars/GrammarConstraint+Definitions.swift
ios/App/GemmaKit/Sources/Agents/AgentTask.swift
```

Modify whichever existing text agent or orchestrator route handles `analyseText` so **Check this text** uses the weighted marker extraction and explanation path.

Do not modify the inference backend to add multimodal image generation for this scoped implementation.

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
4. Image analysis uses Apple Vision OCR for Stage A text extraction.
5. Image analysis does not require Gemma vision, `generateVision(...)`, `VisionInput`, or a multimodal projector.
6. Runtime image analysis performs two Gemma text calls after OCR:
   - marker extraction
   - explanation/action generation
7. **Check this text** performs two Gemma text calls:
   - marker extraction with the user text as `{{INPUT_SUMMARY}}`
   - explanation/action generation
8. Text input does not call Apple Vision OCR, image context extraction, `generateVision`, or any image prompt.
9. Only one marker extraction prompt exists in runtime code, and it matches Prompt 2 from `scam_marker_extraction_prompts (2)(1).md`.
10. The explanation/action prompt is separate from the marker extraction prompt.
11. The marker extraction prompt is the only prompt allowed to produce feature JSON.
12. The explanation/action prompt must not change verdict, score, threshold, or feature statuses.
13. No prompt ablation code exists in runtime code.
14. The target feature keys exactly match:
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
15. The weights exactly match the notebook values.
16. The threshold is exactly `0.22` and is inclusive.
17. `pretexting` alone scores `0.2143` and returns `safe`.
18. `pretexting + external_action` scores `0.2584` and returns `scam`.
19. Invalid marker JSON does not crash the app.
20. Invalid explanation JSON does not change the verdict or score.
21. Final `AgentResult` includes `weightedScoreReport` for the weighted path.
22. Final `AgentResult` includes `explanation` for the weighted path.
23. Final explanation includes:
   - summary
   - warning signs
   - recommended action
   - optional safety note
24. Raw image base64, raw Apple OCR text, raw user text, raw marker output, and raw explanation input JSON are not persisted.
25. If Stage C fails, the app still returns the deterministic verdict and score report with a fallback explanation.
26. `npm run typecheck`, `npm run lint`, and `npm run test:unit` pass.
27. Swift unit tests for OCR, parser, scorer, explanation parser, and weighted pipelines pass in Xcode or `swift test` where applicable.

## 16. Implementation Notes for Claude

- Treat this as an in-place refactor of the existing repo.
- Do not create parallel `_NEW` files.
- Do not replace the app architecture.
- Do not add a backend server for inference.
- Do not move inference to Next.js.
- Do not use Python in the app runtime.
- Keep the privacy-first local inference design.
- Prefer typed Swift structs/enums over dictionaries after the JSON boundary.
- Keep dictionary parsing isolated inside `ScamMarkerParser` and `ScamExplanationParser`.
- Keep the scoring function deterministic and side-effect free.
- Keep prompts in one Swift prompt file so future prompt changes are auditable.
- Preserve the feature-extraction prompt and scoring behavior unless tests explicitly require a bug fix.
- Do not make the feature extractor more verbose just to improve explanations.
- Use Stage C to explain the already-scored result using the original input summary plus extracted feature JSON.
- Apple Vision OCR is the required image text-extraction path for this implementation.
- Avoid putting raw user content, raw OCR text, raw marker JSON, or raw explanation input JSON in logs.

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
- Replacing Apple Vision OCR with Gemma vision transcription.
- Adding `generateVision(...)`, `VisionInput`, or multimodal MLX/llama.cpp image inference.
- Letting the explanation prompt override or modify the deterministic weighted verdict.
