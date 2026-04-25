# Spec 00 — Project Conventions

Applies to every file in this repository. Claude Code agents must follow these conventions before writing any code.

---

## 1. Repository Layout

```
GemScan/
├── src/                          # Next.js web app (TypeScript + React)
│   ├── app/                      # App Router pages and layouts
│   ├── components/               # Shared UI components
│   ├── hooks/                    # Custom React hooks
│   ├── lib/                      # Business logic, utilities, type definitions
│   │   ├── agents/               # Agent task/result types and web-mode stubs
│   │   ├── mcp/                  # MCP client types and web-mode stubs
│   │   └── gemma/                # GemmaPlugin interface + mock implementation
│   └── styles/                   # Global CSS, design tokens
├── ios/                          # Capacitor iOS project (generated; edit native/ only)
│   └── App/
│       ├── App/                  # Capacitor App source
│       ├── GemmaKit/             # Shared Swift package (inference + agents + MCP)
│       │   ├── Sources/
│       │   │   ├── Inference/    # MLX Swift / llama.cpp wrappers
│       │   │   ├── Agents/       # Six agent actors
│       │   │   ├── MCP/          # Ten MCP server implementations
│       │   │   ├── Router/       # Platform-native message router
│       │   │   └── Extensions/   # iOS extension bridges
│       │   └── Tests/
│       ├── Plugins/              # Capacitor native plugins (GemmaPlugin, etc.)
│       └── Extensions/           # iOS app extensions (SMS Filter, Call Dir, Share, Intents)
├── specs/                        # This directory — implementation specifications
├── research/                     # Research documents (read-only reference)
├── scripts/                      # Build, fine-tuning, and data-pipeline scripts
│   ├── finetune/                 # Unsloth QLoRA fine-tuning scripts
│   ├── export/                   # GGUF + MLX + Core ML export scripts
│   └── data/                     # Dataset assembly and annotation scripts
├── models/                       # Local model artifact cache (gitignored; downloaded at runtime)
├── .github/workflows/            # CI/CD pipelines
└── capacitor.config.ts           # Capacitor configuration
```

---

## 2. Language and Runtime Versions

| Layer | Language | Minimum version |
|---|---|---|
| Web frontend | TypeScript | 5.4+ |
| Web runtime | Node.js | 20 LTS |
| Web framework | Next.js | 14 (App Router) |
| iOS native | Swift | 5.9 |
| iOS build | Xcode | 15.3 |
| iOS deployment target | — | iOS 15.0 |
| Python (scripts) | Python | 3.11+ |

---

## 3. Naming Conventions

### TypeScript / JavaScript

```ts
// Files: kebab-case
agent-task.ts
gemma-plugin.ts
use-scam-check.ts

// Types and interfaces: PascalCase
interface AgentTask { ... }
type ScamVerdict = 'safe' | 'suspicious' | 'scam'

// Functions and variables: camelCase
function classifySms(input: SmsInput): Promise<AgentResult> { ... }
const confidenceThreshold = 0.75

// Constants: SCREAMING_SNAKE_CASE
const MAX_CONTEXT_TOKENS = 128_000
const E2B_RSS_LIMIT_BYTES = 2_300 * 1024 * 1024

// React components: PascalCase files and function names
// src/components/ScamWarningCard.tsx
export function ScamWarningCard({ verdict }: Props) { ... }
```

### Swift

```swift
// Files: PascalCase matching the primary type
AgentTask.swift
GemmaKitInference.swift
ScamPatternsServer.swift

// Types: PascalCase
struct AgentTask { ... }
enum ScamVerdict: String { case safe, suspicious, scam }
actor OrchestratorAgent { ... }
protocol MCPServer { ... }

// Functions and properties: camelCase
func classifySMS(_ input: SMSInput) async throws -> AgentResult { ... }
var confidenceThreshold: Float = 0.75

// Constants: camelCase in structs/enums; static let preferred
static let maxContextTokens = 128_000
static let e2bRSSLimitBytes: Int = 2_300 * 1_024 * 1_024
```

---

## 4. Core Data Contracts

These types must be consistent across the TypeScript bridge and Swift actors.

### AgentTask

```typescript
// TypeScript (canonical definition — Swift must mirror)
interface AgentTask {
  id: string                    // UUID v4
  type: AgentTaskType           // 'classifySMS' | 'classifyEmail' | 'checkURL' |
                                //   'analyseScreenshot' | 'scoreVoice' | 'explainVerdict'
  payload: AgentPayload         // See per-type payload below
  priority: 'realtime' | 'background'
  createdAt: number             // Unix timestamp ms
  timeoutMs: number             // Abort if agent exceeds this (default: 5000)
}

type AgentPayload =
  | { type: 'text';       content: string; language?: string }
  | { type: 'url';        url: string }
  | { type: 'image';      base64: string; mimeType: 'image/jpeg' | 'image/png' }
  | { type: 'audio';      base64: string; durationSeconds: number }
  | { type: 'multimodal'; parts: AgentPayload[] }
```

### AgentTaskType Enum

```typescript
// TypeScript canonical definition
export type AgentTaskType =
  | 'classifySMS'
  | 'classifyEmail'
  | 'checkURL'
  | 'analyseScreenshot'
  | 'scoreVoice'
  | 'explainVerdict'
```

```swift
// Swift mirror — raw values must match TypeScript strings exactly
enum AgentTaskType: String, Codable {
    case classifySMS       = "classifySMS"
    case classifyEmail     = "classifyEmail"
    case checkURL          = "checkURL"
    case analyseScreenshot = "analyseScreenshot"
    case scoreVoice        = "scoreVoice"
    case explainVerdict    = "explainVerdict"
}
```

### ModelTier Enum

```swift
// ios/App/GemmaKit/Sources/Inference/ModelTier.swift
enum ModelTier: String, Codable {
    case e2b        = "e2b"
    case e4b        = "e4b"
    case distilbert = "distilbert"

    /// Expected resident-memory footprint at Q4_K_M
    var expectedRAMBytes: Int {
        switch self {
        case .e2b:        return 1_800 * 1_024 * 1_024   // 1.8 GB
        case .e4b:        return 3_200 * 1_024 * 1_024   // 3.2 GB
        case .distilbert: return 5 * 1_024 * 1_024       // 5 MB
        }
    }
}
```

### Swift AgentTask Struct

The Swift struct is the authoritative native definition. All field names use camelCase and are JSON-key-matched to the TypeScript contract via `CodingKeys`.

```swift
// ios/App/GemmaKit/Sources/Agents/AgentTask.swift
import Foundation

struct AgentTask: Codable {
    let id: String                  // UUID v4 string
    let type: AgentTaskType
    let payload: AgentPayload
    let priority: TaskPriority
    let createdAt: Int64            // Unix timestamp ms
    let timeoutMs: Int

    enum CodingKeys: String, CodingKey {
        case id, type, payload, priority, createdAt, timeoutMs
    }

    /// Convenience — returns a copy with an updated modelTier hint in the payload.
    /// Used by OrchestratorAgent when escalating from E2B to E4B.
    func withModelTier(_ tier: ModelTier) -> AgentTask {
        AgentTask(id: id, type: type, payload: payload, priority: priority,
                  createdAt: createdAt, timeoutMs: timeoutMs)
        // Note: modelTier is passed separately to InferenceEngine.generate(); it is
        // not a field on AgentTask itself. This method is a no-op on the struct;
        // the caller passes the desired tier directly to the inference call.
    }
}

enum TaskPriority: String, Codable {
    case realtime   = "realtime"
    case background = "background"
}

enum AgentPayload: Codable {
    case text(String, language: String?)
    case url(String)
    case image(String, mimeType: ImageMIMEType)
    case audio(String, durationSeconds: Double)
    case multimodal(parts: [AgentPayload], priorResult: AgentResult?)

    var language: String? {
        if case .text(_, let lang) = self { return lang }
        return nil
    }

    var isMultiModal: Bool {
        if case .multimodal = self { return true }
        return false
    }

    enum ImageMIMEType: String, Codable {
        case jpeg = "image/jpeg"
        case png  = "image/png"
    }

    // Custom Codable implementation to handle discriminated union
    private enum CodingKeys: String, CodingKey { case type, content, url, base64, mimeType, durationSeconds, parts, priorResult, language }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(String.self, forKey: .type)
        switch type {
        case "text":
            let content = try c.decode(String.self, forKey: .content)
            let language = try c.decodeIfPresent(String.self, forKey: .language)
            self = .text(content, language: language)
        case "url":
            self = .url(try c.decode(String.self, forKey: .url))
        case "image":
            let base64 = try c.decode(String.self, forKey: .base64)
            let mimeType = try c.decode(ImageMIMEType.self, forKey: .mimeType)
            self = .image(base64, mimeType: mimeType)
        case "audio":
            let base64 = try c.decode(String.self, forKey: .base64)
            let duration = try c.decode(Double.self, forKey: .durationSeconds)
            self = .audio(base64, durationSeconds: duration)
        case "multimodal":
            let parts = try c.decode([AgentPayload].self, forKey: .parts)
            let prior = try c.decodeIfPresent(AgentResult.self, forKey: .priorResult)
            self = .multimodal(parts: parts, priorResult: prior)
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: c, debugDescription: "Unknown payload type: \(type)")
        }
    }
}
```

### TriageLabel Enum

Defined here to be shared between the main app (TextAgent fast path) and the ILMessageFilterExtension.

```swift
// ios/App/GemmaKit/Sources/Inference/TriageLabel.swift
enum TriageLabel: String, Codable {
    case safe        = "safe"
    case junk        = "junk"
    case transaction = "transaction"
    case promotion   = "promotion"
    case unknown     = "unknown"
}

struct TriageResult: Codable {
    let label: TriageLabel
    let confidence: Double
}
```

### AgentResult

```typescript
interface AgentResult {
  taskId: string
  agentId: string               // e.g. 'text-agent', 'url-agent', 'orchestrator'
  verdict: ScamVerdict
  confidence: number            // 0.0–1.0
  reasoning: string[]           // 2–3 bullet points, sixth-grade reading level
  language: string              // BCP-47 language tag of the reasoning output
  toolCallsLog: ToolCallRecord[] // For observability — every MCP tool call made
  latencyMs: number
  modelTier: 'e2b' | 'e4b' | 'distilbert'
  escalatedToE4B: boolean
}

type ScamVerdict = 'safe' | 'suspicious' | 'scam'

interface ToolCallRecord {
  serverName: string
  toolName: string
  inputSummary: string          // Non-sensitive summary (no PII)
  durationMs: number
  success: boolean
}
```

### Swift AgentResult Struct

```swift
// ios/App/GemmaKit/Sources/Agents/AgentResult.swift
struct AgentResult: Codable {
    let taskId: String
    let agentId: String
    let verdict: ScamVerdict
    let confidence: Double
    let reasoning: [String]
    let language: String
    let toolCallsLog: [ToolCallRecord]
    let latencyMs: Int
    let modelTier: ModelTier
    let escalatedToE4B: Bool

    func markingEscalated(latencyMs override: Int) -> AgentResult {
        AgentResult(taskId: taskId, agentId: agentId, verdict: verdict,
                    confidence: confidence, reasoning: reasoning, language: language,
                    toolCallsLog: toolCallsLog, latencyMs: override,
                    modelTier: modelTier, escalatedToE4B: true)
    }
}

enum ScamVerdict: String, Codable {
    case safe       = "safe"
    case suspicious = "suspicious"
    case scam       = "scam"
}

struct ToolCallRecord: Codable {
    let serverName: String
    let toolName: String
    let inputSummary: String
    let durationMs: Int
    let success: Bool
}
```

---

## 5. Error Handling

### Rules

1. **Never swallow errors silently.** Every `catch` block must log at minimum at the `.error` level.
2. **Distinguish error categories:** `UserError` (bad input — surface to UI), `SystemError` (OOM, timeout — log + degrade gracefully), `ModelError` (hallucinated JSON, grammar failure — retry once then escalate).
3. **No force-unwraps in Swift** (`!`). Use `guard let` or `if let` with a logged fallback.
4. **All async Swift functions throw.** Callers must handle errors at the call site.

### Swift Error Types

```swift
enum GemScanError: Error, CustomStringConvertible {
    case modelNotLoaded(tier: ModelTier)
    case inferenceTimeout(taskId: String, limitMs: Int)   // thrown by MessageRouter.dispatch when agent exceeds AgentTask.timeoutMs
    case oomRejected(requestedBytes: Int, availableBytes: Int)
    case grammarViolation(raw: String)
    case mcpToolFailed(server: String, tool: String, underlying: Error)
    case audioIngestionUnavailable(reason: String)

    var description: String { /* human-readable, non-sensitive */ }
}
```

### Graceful Degradation Order

If E4B is unavailable (OOM or timeout):
1. Fall back to E2B with a logged `.warning`.
2. If E2B also unavailable, return a `suspicious` verdict with `confidence: 0.5` and log `.error`.
3. Never return an error to the user as a raw exception — always wrap in a conservative verdict.

---

## 6. Logging

See `specs/08_logging_and_monitoring.md` for full detail. Summary:

- **Swift**: Use `os.Logger` with subsystem `com.gemscan` and a category per module.
- **TypeScript**: Use a structured logger (`src/lib/logger.ts`) that emits JSON in production and pretty-prints in development.
- **Log levels**: `.debug` for per-token tracing (dev only), `.info` for lifecycle events, `.warning` for degradations, `.error` for failures.
- **Never log PII**: No message content, contact names, audio transcripts, or screenshot contents in logs. Use non-sensitive summaries only (e.g., `"SMS classified [12 chars, truncated]"`).

---

## 7. Performance Guards

Wrap every inference call and MCP tool call with:

1. **Timeout** — abort and log if the call exceeds `timeoutMs` from the `AgentTask`.
2. **RSS check before model load** — query available memory; refuse to load a model if `availableBytes < modelSizeBytes * 1.2` (20 % headroom required). Log at `.warning` and return a graceful degradation result.
3. **Thermal state check (iOS)** — before starting a multi-turn E4B session, query `ProcessInfo.processInfo.thermalState`. If `.critical` or `.serious`, downgrade to E2B and log at `.warning`.

```swift
// Swift thermal guard example
if ProcessInfo.processInfo.thermalState >= .serious {
    GemScanLogger.inference.warning("Thermal state \(ProcessInfo.processInfo.thermalState.rawValue) — downgrading to E2B")
    return try await e2bAgent.handle(task)
}
```

---

## 8. Web App Mode vs iOS Dev Mode

Every component that touches native hardware must have a **web mock** that activates when running in a browser or simulator outside the native Capacitor container.

### Detection Pattern

```typescript
// src/lib/platform.ts
export const isNativePlatform = (): boolean => {
  return typeof (window as any).Capacitor !== 'undefined'
    && (window as any).Capacitor.isNativePlatform()
}
```

### Mock Registration

```typescript
// src/lib/gemma/index.ts
import { isNativePlatform } from '../platform'
import { GemmaPluginNative } from './native'
import { GemmaPluginMock } from './mock'

export const GemmaPlugin = isNativePlatform()
  ? GemmaPluginNative
  : GemmaPluginMock
```

### Mock Contract

Web mocks must:
- Return valid `AgentResult` objects within 200–800 ms (simulated latency).
- Return deterministic results for known test inputs (golden fixtures in `src/lib/gemma/__fixtures__/`).
- Log every call at `.info` with prefix `[MOCK]`.
- Never throw unless testing error paths.

---

## 9. Testing Requirements (Minimum per PR)

| Layer | Tool | Minimum coverage |
|---|---|---|
| TypeScript | Vitest | 80 % line coverage on `src/lib/` |
| Swift | XCTest | All `AgentTask` round-trips; all MCP server `Tool` implementations |
| End-to-end (web mode) | Playwright | Happy-path Share Sheet flow; Guardian mode enrolment flow |
| End-to-end (iOS device) | XCUITest | Cold-start test; SMS Filter extension activation; Share Sheet flow |

See `specs/07_testing_and_validation.md` for full testing spec.

---

## 10. Dependency Management Rules

1. **Zero unnecessary dependencies.** Before adding a package, confirm no existing package solves the problem.
2. **Pin exact versions** in `package.json` (`"package": "1.2.3"`, not `"^1.2.3"`). Renovate Bot handles version bumps via PR.
3. **Swift Package Manager only** for iOS dependencies. No CocoaPods unless a package is unavailable on SPM.
4. **No transitive network calls** in test code. Mock all HTTP at the boundary.
5. **Model weights are not dependencies.** They are downloaded at runtime; never committed to git. The `models/` directory is gitignored.

---

## 11. Apple Platform Compliance — Mandatory Validation Gate

**Every task generated from these specifications must include a validation step that confirms the implementation meets Apple iOS developer requirements.** This is not optional. A task is not complete until all applicable checks in this section pass.

Tasks must explicitly call out which checks apply (mark N/A with a reason if a check is genuinely not applicable to the task scope).

### 11.1 Swift Concurrency and Memory Safety

| Check | Requirement | Tooling |
|---|---|---|
| No data races | All shared mutable state is inside `actor` types or protected by `@MainActor`. No `nonisolated` mutable variables. | Xcode Thread Sanitizer (TSan); `SWIFT_STRICT_CONCURRENCY = complete` in Build Settings |
| No force-unwraps | Zero `!` operators in production code. Use `guard let` / `if let` with a logged fallback. | SwiftLint rule `force_unwrapping` |
| No retain cycles | Closures capturing `self` in async contexts use `[weak self]` or `[unowned self]` where appropriate. | Xcode Memory Graph Debugger |
| Sendable conformance | Any type crossing actor boundaries conforms to `Sendable`. No `@unchecked Sendable` without a comment explaining why it is safe. | Xcode Swift 6 concurrency checking |
| Proper `@MainActor` usage | All UI updates (UIKit/SwiftUI mutations, CapacitorBridge callbacks) are dispatched on `@MainActor`. | TSan + Xcode runtime warnings |

### 11.2 Memory and Performance

| Check | Requirement | Tooling |
|---|---|---|
| RSS budget respected | No single component exceeds its documented RSS ceiling (E2B: 1.8 GB, E4B: 3.2 GB, DistilBERT: 5 MB, extensions: 50 MB). | Xcode Memory Report; `XCTMemoryMetric` in benchmarks |
| No memory leaks | Instruments Leaks template shows zero leaks after a full analysis session. | Instruments Leaks |
| Extension memory ceiling | `ILMessageFilterExtension`, `CallDirectoryExtension`, and `ShareExtension` stay within their 50 MB / 120 MB / 120 MB ceilings respectively. | Xcode Memory Report in extension target |
| Background execution | No long-running work initiated in `applicationDidEnterBackground` outside a `BGProcessingTask` or `URLSession` background task. | Xcode Energy Log |

### 11.3 Privacy and Data Handling

| Check | Requirement | Tooling |
|---|---|---|
| `NSUsageDescription` keys | Every permission used (Contacts, Microphone, Camera, Speech Recognition, Photo Library) has a matching `NSUsageDescription` key in `Info.plist` with a user-facing reason string. | `ibtool --verify`; App Store Connect upload validation |
| Privacy manifest complete | `PrivacyInfo.xcprivacy` lists all required reason APIs used (e.g., `NSPrivacyAccessedAPICategoryUserDefaults`, `NSPrivacyAccessedAPICategoryFileTimestamp`). | App Store Connect API validation; `xcodebuild -validatePrivacyManifest` |
| No PII in logs | No message content, contact names, phone numbers, or audio transcripts appear in `os.Logger` output or TypeScript structured logs. | CI PII scan (see Spec 09 §5); manual log audit |
| On-device only | No user content (messages, audio, screenshots) is transmitted to any external server. MCP servers operate exclusively in-process. | Network Profiler in Instruments; Charles Proxy integration test |
| Clipboard access | `UIPasteboard.general` is accessed only in `ClipboardWatcherServer` and only on explicit user action (app foreground). No silent clipboard reads. | Code review; Instruments Network |

### 11.4 App Store Guidelines Compliance

| Check | Requirement |
|---|---|
| No private APIs | Zero calls to private/undocumented APIs. Verify with `nm -u` on the compiled binary and check against Apple's private framework list. |
| Entitlements match capabilities | Every capability used at runtime has a matching entitlement in the `.entitlements` file and is enabled in the App ID on the Apple Developer portal. Missing entitlements cause silent runtime failures. |
| App Transport Security | All HTTPS requests use TLS 1.2+. No `NSAllowsArbitraryLoads` in `Info.plist`. The relay server (`relay.gemscan.app`) must have a valid TLS certificate. |
| Background modes declared | Any background mode used (remote notifications, background fetch, background processing) is declared in `UIBackgroundModes` in `Info.plist`. |
| Exported compliance | `ITSAppUsesNonExemptEncryption = NO` in `Info.plist` (GemScan uses only iOS-provided encryption via Keychain / TLS — no custom cryptography that requires export declarations). |

### 11.5 Human Interface Guidelines (HIG) Compliance

| Check | Requirement |
|---|---|
| Minimum tap target | All interactive elements are at least 44 × 44 pt (Apple HIG). Verified by XCUITest `frame` assertions. |
| Dynamic Type | All text scales correctly through all Dynamic Type sizes (XS → Accessibility-XXL). No truncated or overflowing text at any size. XCUITest: set `app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"]`. |
| Dark Mode | All custom colours use semantic colour assets (`UIColor.label`, `UIColor.systemBackground`, or named colours with light/dark variants in the asset catalogue). No hard-coded hex colours in native views. |
| VoiceOver | Every screen is fully operable without sight. All meaningful images have accessibility labels. Decorative elements are marked `isAccessibilityElement = false`. |
| Safe area insets | No content clipped by notch, Dynamic Island, or home indicator. All views use `safeAreaLayoutGuide` / `safeAreaInsets`. |

### 11.6 Keychain and Security

| Check | Requirement |
|---|---|
| Keychain accessibility | All Keychain items use `kSecAttrAccessibleAfterFirstUnlock` (or stricter). Never `kSecAttrAccessibleAlways`. |
| No hardcoded secrets | No API keys, tokens, or credentials in source code. Secrets stored in Keychain or GitHub Actions secrets only. |
| Secure transport for relay | `sendGuardianAlert()` uses HTTPS. Certificate pinning is optional for Cycle 1 but required before public release. |

### 11.7 Task Completion Definition

A task generated from this spec is **done** when:

1. The implementation passes all applicable checks in §11.1–11.6.
2. The following automated gates pass in CI:
   - `xcodebuild analyze` reports zero issues on the modified files.
   - SwiftLint with the project ruleset (`.swiftlint.yml`) reports zero errors (warnings are acceptable).
   - `SWIFT_STRICT_CONCURRENCY = complete` build succeeds without new warnings on modified files.
   - Vitest coverage remains ≥ 80% on `src/lib/`.
   - All existing XCTest and Playwright tests continue to pass.
3. Any new permission, entitlement, or background mode added is documented in the PR description and cross-checked against App Store Review Guidelines §5 (Privacy).
4. The PR description includes an **"Apple Compliance Notes"** section that lists: which §11 checks were verified, the tooling used, and any items marked N/A with justification.
