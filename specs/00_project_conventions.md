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
├── android/                      # Capacitor Android project (generated; edit native/ only)
│   └── app/
│       ├── src/main/
│       │   ├── kotlin/com/gemscan/
│       │   │   ├── inference/    # LiteRT-LM / llama.cpp wrappers
│       │   │   ├── agents/       # Six agent coroutine classes
│       │   │   ├── mcp/          # Ten MCP server implementations
│       │   │   ├── router/       # Kotlin coroutines message router
│       │   │   └── plugins/      # Capacitor plugins
│       │   └── res/
│       └── src/test/
├── specs/                        # This directory — implementation specifications
├── research/                     # Research documents (read-only reference)
├── scripts/                      # Build, fine-tuning, and data-pipeline scripts
│   ├── finetune/                 # Unsloth QLoRA fine-tuning scripts
│   ├── export/                   # GGUF + MLX + Core ML + TFLite export scripts
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
| Android native | Kotlin | 1.9 |
| Android API | — | minSdk 28 / targetSdk 35 |
| Android build | Gradle | 8.2+ |
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

### Kotlin

```kotlin
// Files: PascalCase matching the primary class
AgentTask.kt
GemmaInferenceEngine.kt
ScamPatternsServer.kt

// Classes: PascalCase
data class AgentTask(...)
sealed class ScamVerdict { object Safe; object Suspicious; data class Scam(...) }

// Functions and properties: camelCase
suspend fun classifySms(input: SmsInput): AgentResult { ... }

// Constants: SCREAMING_SNAKE_CASE in companion object
companion object {
    const val MAX_CONTEXT_TOKENS = 128_000
    const val E2B_RSS_LIMIT_BYTES = 2_300L * 1_024 * 1_024
}
```

---

## 4. Core Data Contracts

These types must be consistent across the TypeScript bridge, Swift actors, and Kotlin coroutines.

### AgentTask

```typescript
// TypeScript (canonical definition — Swift and Kotlin must mirror)
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

---

## 5. Error Handling

### Rules

1. **Never swallow errors silently.** Every `catch` block must log at minimum at the `.error` level.
2. **Distinguish error categories:** `UserError` (bad input — surface to UI), `SystemError` (OOM, timeout — log + degrade gracefully), `ModelError` (hallucinated JSON, grammar failure — retry once then escalate).
3. **No force-unwraps in Swift** (`!`). Use `guard let` or `if let` with a logged fallback.
4. **No `!!` in Kotlin** unless behind a documented invariant with a comment.
5. **All async Swift functions throw.** Callers must handle errors at the call site.

### Swift Error Types

```swift
enum GemScanError: Error, CustomStringConvertible {
    case modelNotLoaded(tier: ModelTier)
    case inferenceTimeout(taskId: String, limitMs: Int)
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
- **Kotlin**: Use `android.util.Log` with tag prefix `GemScan/` + module name, wrapped in a `GemScanLogger` facade.
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
| Kotlin | JUnit 5 + MockK | All agent coroutine flows; all MCP server tool implementations |
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
