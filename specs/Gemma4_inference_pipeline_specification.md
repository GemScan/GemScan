# Gemma 4 E2B 4-bit Runtime Scam Detection Spec

This spec defines the runtime pipeline GemScan must implement for text and screenshot scam analysis. It replaces the notebook-derived experimental flow with a deterministic app contract.

The implementation must run locally through the existing Next.js + Capacitor UI and Swift `GemmaKit` native pipeline. OCR already exists in the project; do not build a second OCR system.

Core rule:

```text
Stage B decides. Stage C labels. Stage D explains.
```

Stage C and Stage D are metadata/prose stages. They must never change the deterministic verdict, score, threshold, feature statuses, or weighted-score report.

## 1. Runtime Pipeline

### Stage A: Input Summary

Convert the user input into plain text called `INPUT_SUMMARY`.

- Text, URL, SMS, and email inputs use the user-entered text directly.
- Screenshot/image inputs use the existing Apple Vision OCR implementation:
  - `ios/App/GemmaKit/Sources/Inference/ImageOCR.swift`
  - `ImageOCR.extractText(from:)`
- Do not add Gemma vision, MLX multimodal inference, `generateVision`, or a projector for this implementation.
- OCR must not classify, score, or label content.
- Empty OCR text is not an infrastructure failure. Continue with an empty `INPUT_SUMMARY` and add `empty_image_ocr_text` warning metadata where supported.

### Stage B: Marker Extraction And Scoring

Run one deterministic Gemma 4 E2B 4-bit text call against `INPUT_SUMMARY` to extract marker JSON. Then score deterministically in Swift.

Required marker keys:

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

The marker extraction prompt must be a single fixed text-only prompt. It must return JSON with exactly those keys. Each marker may be represented as a nested object with `status` and optional `evidence`; direct boolean/string variants may be accepted by the parser for robustness.

Use these exact weights:

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

Use this exact threshold:

```swift
public static let scamThreshold: Double = 0.22
let verdict: ScamVerdict = totalScore >= scamThreshold ? .scam : .safe
```

This weighted path returns only `.safe` or `.scam`. Do not return `.suspicious` from this notebook-derived weighted pipeline.

Parser rules:

- Try to parse full model output as JSON.
- If that fails, extract and parse the first balanced JSON object.
- Missing, malformed, false-like, empty, parse-failed, or unknown marker values normalize to `absent`.
- Invalid marker JSON is not an infrastructure failure. Return all features absent, `validJSON = false`, `totalScore = 0`, `verdict = safe`, and confidence `0.50`.

### Stage C: Scam Categorization

Run only when Stage B returns `scam`.

Inputs:

- deterministic verdict
- `INPUT_SUMMARY`
- present feature markers
- redacted/truncated marker evidence
- weighted score report

The user will provide the final `SCAM_CATEGORIZATION_PROMPT`. Until then, reserve a prompt constant with this contract:

- Return JSON only.
- Choose exactly one category.
- Return confidence in `[0, 1]`.
- Do not change or question the verdict.
- Do not change feature statuses, score, threshold, or weighted report.

Allowed categories:

```ts
export type ScamCategory =
  | 'extortion'
  | 'imposter'
  | 'phishing'
  | 'romance'
  | 'investment'
  | 'employment'
  | 'shopping'
  | 'malware'
```

Required output:

```json
{
  "category": "phishing",
  "confidence": 0.82
}
```

Failure policy:

- Invalid JSON, missing category, unknown category, or confidence outside `[0, 1]` must not fail the scan.
- Store no category and add `invalid_scam_category` warning metadata where supported.
- Do not force a nearest category.
- Safe verdicts skip Stage C and store no category.

### Stage D: Explanation And Recommended Action

Run after Stage B and optional Stage C.

Inputs:

- `INPUT_SUMMARY`
- deterministic verdict
- total score and threshold
- optional scam category
- present feature markers
- redacted/truncated marker evidence

The explanation prompt must return JSON only:

```json
{
  "summary": "",
  "warning_signs": [],
  "recommended_action": "",
  "safety_note": ""
}
```

Rules:

- Explain the already-decided verdict in plain language.
- Do not change the verdict, score, threshold, feature statuses, or scam category.
- Do not invent facts.
- Do not expose internal feature names unless rewritten in normal language.
- For scam results, tell the user not to use suspicious links, phone numbers, QR codes, payment instructions, or contact methods from the message.
- For safe results, do not say the content is guaranteed safe.

If Stage D fails, return a fallback `ScamExplanation` without changing verdict, score, or scam category.

## 2. Public Contracts

### Swift Result Additions

Add these Codable types near the weighted pipeline DTOs:

```swift
public struct WeightedScamScoreReport: Codable, Sendable {
    public let type: String              // "weightedScamScore"
    public let totalScore: Double
    public let threshold: Double
    public let verdict: ScamVerdict
    public let features: [ScamFeatureScore]
    public let validationWarnings: [String]
    public let validJSON: Bool
}

public enum ScamCategory: String, Codable, CaseIterable, Sendable {
    case extortion
    case imposter
    case phishing
    case romance
    case investment
    case employment
    case shopping
    case malware
}

public struct ScamCategoryResult: Codable, Sendable {
    public let category: ScamCategory
    public let confidence: Double
    public let validJSON: Bool
    public let validationWarnings: [String]
}

public struct ScamExplanation: Codable, Sendable {
    public let summary: String
    public let warningSigns: [String]
    public let recommendedAction: String
    public let safetyNote: String?
}
```

Extend `AgentResult`:

```swift
public struct AgentResult: Codable, Sendable {
    ...existing fields...
    public let weightedScoreReport: WeightedScamScoreReport?
    public let scamCategory: ScamCategoryResult?
    public let explanation: ScamExplanation?
}
```

Default all three new fields to `nil` in initializers so existing agents remain compatible.

### TypeScript Result Additions

Add matching types to `src/lib/gemma/types.ts`:

```ts
export type ScamCategory =
  | 'extortion'
  | 'imposter'
  | 'phishing'
  | 'romance'
  | 'investment'
  | 'employment'
  | 'shopping'
  | 'malware'

export interface ScamCategoryResult {
  category: ScamCategory
  confidence: number
  validJSON: boolean
  validationWarnings: string[]
}

export interface AgentResult {
  // existing fields...
  weightedScoreReport?: WeightedScamScoreReport
  scamCategory?: ScamCategoryResult
  explanation?: ScamExplanation
}
```

### Task And Timeout Rules

Use the existing task shapes:

```ts
type AgentTaskType =
  | 'classifySMS'
  | 'classifyEmail'
  | 'checkURL'
  | 'analyseScreenshot'
  | 'explainVerdict'

type AgentPayload =
  | { type: 'text'; content: string; language?: string }
  | { type: 'url'; url: string }
  | { type: 'image'; base64: string; mimeType: 'image/jpeg' | 'image/png' }
  | { type: 'multimodal'; parts: AgentPayload[] }
```

Recommended timeouts:

- Text/URL/email: `90_000`
- Screenshot/image: `120_000`

## 3. Implementation Requirements

- Use the existing `ModelTier.e2b` path and MLX 4-bit model registry. Do not add E4B escalation.
- Create a shared weighted-analysis service once `INPUT_SUMMARY` exists, or otherwise share parser/scorer/category/explanation code between text and image agents.
- Text and image flows must differ only in how `INPUT_SUMMARY` is produced.
- `OrchestratorAgent` must not override weighted-path `.safe` results through the old low-confidence fallback.
- `AgentResult.confidence` is display confidence derived from distance to the `0.22` threshold. Category confidence is separate and never affects verdict confidence.

Recommended confidence formula:

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

Required parsers:

- `ScamMarkerParser`
- `ScamCategoryParser`
- `ScamExplanationParser`

Optional grammars may be added for marker extraction, scam categorization, and explanation generation. Parsers remain the source of truth for runtime robustness.

## 4. Privacy And Persistence

Do not persist or log:

- raw image base64
- raw user-entered text in `AgentResult`
- raw Apple OCR text in `AgentResult`
- raw marker model output
- raw categorization input or model output
- raw explanation input or model output
- unredacted evidence strings

May be persisted in local history/results:

- `WeightedScamScoreReport`
- `ScamCategoryResult`
- `ScamExplanation`

Before building Stage C or Stage D input JSON, redact obvious sensitive tokens where practical:

- phone numbers -> `[phone_number]`
- emails -> `[email]`
- URLs/domains -> `[url]`
- long numeric identifiers -> `[number]`

## 5. UI And Mock Behavior

The current UI may continue to render the verdict card as it does today, but it should prefer structured fields when present:

- Use `result.explanation.warningSigns` instead of `result.reasoning` when available.
- Use `result.explanation.recommendedAction` instead of `result.suggestion` when available.
- The UI may display scam category when present. Safe results should have no `scamCategory`.

Mock plugin fixtures must include:

- at least one scam text result with `weightedScoreReport`, `scamCategory`, and `explanation`
- at least one safe text result with `weightedScoreReport` and `explanation`, no `scamCategory`
- at least one scam screenshot result with `weightedScoreReport`, `scamCategory`, and `explanation`
- at least one safe screenshot result with `weightedScoreReport` and `explanation`, no `scamCategory`

## 6. Tests And Acceptance Criteria

### Unit Tests

Swift tests:

- scorer returns `safe` for all features absent
- `pretexting` alone scores `0.2143` and returns `safe`
- `pretexting + external_action` scores `0.2584` and returns `scam`
- threshold equality returns `scam`
- marker parser accepts nested status objects and robust fallback formats
- marker parser invalid JSON returns all absent with `validJSON = false`
- category parser accepts all eight categories
- category parser rejects unknown categories, missing category, and out-of-range confidence
- explanation parser accepts valid snake_case JSON and returns fallback on invalid JSON
- image weighted pipeline uses existing OCR before marker extraction
- scam pipelines run marker extraction, categorization, then explanation
- safe pipelines run marker extraction, skip categorization, then explanation
- Stage C failure does not change verdict, score, or explanation generation
- Stage D failure does not change verdict, score, or scam category

TypeScript tests:

- `AgentResult` accepts optional `weightedScoreReport`, `scamCategory`, and `explanation`
- mock text/image scam fixtures include category metadata
- mock text/image safe fixtures omit category metadata
- UI renders structured explanation fields when present
- store does not persist pending raw image base64 or transient pending input

### Acceptance Criteria

- Text input uses the raw user text as `INPUT_SUMMARY`.
- Image input uses the existing Apple Vision OCR path as `INPUT_SUMMARY`.
- No Gemma vision or multimodal image generation is added.
- The marker extraction prompt is the only prompt allowed to produce feature JSON.
- The deterministic weighted scorer is the only source of truth for verdict.
- Stage C runs only for scam verdicts and returns one of the eight allowed categories plus confidence.
- Invalid Stage C output stores no category and does not fail analysis.
- Stage D returns summary, warning signs, recommended action, and optional safety note.
- Invalid Stage D output returns a fallback explanation and does not change verdict, score, or category.
- Final scam weighted-path results include `weightedScoreReport`, valid `scamCategory` when Stage C succeeds, and `explanation`.
- Final safe weighted-path results include `weightedScoreReport` and `explanation`, and omit `scamCategory`.
- Raw image base64, raw OCR text, raw user text, raw model outputs, and raw prompt input JSON are not persisted or logged.
- `npm run typecheck`, `npm run lint`, and `npm run test:unit` pass.
- Relevant Swift unit tests pass in Xcode or `swift test` where applicable.

## 7. Out Of Scope

- Prompt ablation in app runtime
- E4B escalation
- Python/PyTorch/transformers/bitsandbytes/pandas/W&B in the iOS app
- New OCR implementation
- Gemma vision or multimodal projector work
- Cloud inference or backend services
- Batch notebook evaluation in the mobile runtime
