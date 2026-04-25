# Tasks — Logging & Performance Monitoring

> **Spec:** `specs/08_logging_and_monitoring.md` | **Milestone:** M8 — Logging & Performance Monitoring | **Depends on:** M7

## Milestone Summary
Implements the complete structured logging and performance monitoring layer for GemScan. Covers the centralised `GemScanLogger` registry with all 8 `os.Logger` instances, the `LogEvents` structured event helpers, the TypeScript `logger` module, the `InferenceMetrics` struct and `MetricsStore` actor with ring buffer and summary computation, wiring of metrics into `InferenceEngine`, the `DebugOverlay` component (web and native), a privacy annotation audit, and all associated tests and documentation.

## Prerequisites
- M0 complete: `GemScanError` types, Capacitor project scaffold
- M2 complete: `InferenceEngine` implemented
- M3 complete: agents (`OrchestratorAgent`, `TextAgent`, `JudgeAgent`) implemented
- `os` framework available (Swift 5.5+)
- `OSLog` available for `OSLogStore` tests (iOS 15+)

## Progress Tracker
| Status | Count |
|--------|-------|
| ✅ Done | 0 |
| 🔄 In progress | 0 |
| ⬜ Not started | 14 |

---
## Tasks

#### ⬜ T-08-001 · GemScanLogger registry

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P0 |
| **Spec ref** | §3.1 — GemScanLogger registry |
| **Depends on** | None |
| **Estimated effort** | S |
| **Files to create/modify** | `ios/App/GemmaKit/Sources/Logging/GemScanLogger.swift`, `ios/App/GemmaKit/Sources/Inference/InferenceEngine.swift`, `ios/App/GemmaKit/Sources/Agents/OrchestratorAgent.swift`, `ios/App/GemmaKit/Sources/Agents/TextAgent.swift`, `ios/App/GemmaKit/Sources/MCP/MCPClient.swift` |

**What to build:**
Create `ios/App/GemmaKit/Sources/Logging/GemScanLogger.swift` as an `enum GemScanLogger` (caseless namespace) exporting 8 static `os.Logger` properties, all with `subsystem: "com.gemscan"` and the following categories: `.inference` (`"inference"`), `.agents` (`"agents"`), `.mcp` (`"mcp"`), `.router` (`"router"`), `.extensions` (`"extensions"`), `.plugin` (`"plugin"`), `.ui` (`"ui"`), `.metrics` (`"metrics"`). Add a comment block at the top of the file documenting the privacy marker policy: values that are `.public` (task IDs, verdicts, latency numbers, model tier names, error category strings) vs. values that use the default `.private` mask (any user content, phone numbers, contact names). After creating this file, search all previously implemented Swift files for ad-hoc `Logger(subsystem:category:)` initialisations and replace them with the appropriate `GemScanLogger.*` instance.

**Acceptance criteria:**
- [ ] All 8 `os.Logger` instances defined with `subsystem: "com.gemscan"` and correct categories
- [ ] Privacy policy comment present at top of file
- [ ] No remaining ad-hoc `Logger(subsystem:category:)` calls in `InferenceEngine`, `OrchestratorAgent`, `TextAgent`, `MCPClient`
- [ ] File compiles without warnings

**Apple compliance (Spec 00 §11):**
- [ ] §11.2 — Privacy: centralised logger with privacy marker documentation
- [ ] §11.1 — All Swift types use the shared logger; no duplicate subsystems

---

#### ⬜ T-08-002 · LogEvent structured event helpers

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P0 |
| **Spec ref** | §3.3 — LogEvent structured events |
| **Depends on** | T-08-001 |
| **Estimated effort** | M |
| **Files to create/modify** | `ios/App/GemmaKit/Sources/Logging/LogEvents.swift`, `ios/App/GemmaKit/Sources/Inference/InferenceEngine.swift`, `ios/App/GemmaKit/Sources/Agents/OrchestratorAgent.swift`, `ios/App/GemmaKit/Sources/Inference/ModelLoader.swift` |

**What to build:**
Create `ios/App/GemmaKit/Sources/Logging/LogEvents.swift` as an `enum LogEvent` with 10 static functions, each returning a `String` in `key=value` format (space-separated). The functions and their required fields: `inferenceStart(taskId:type:modelTier:)` → `taskId= type= modelTier=`; `inferenceComplete(taskId:verdict:confidence:latencyMs:escalated:)` → `taskId= verdict= confidence= latencyMs= escalated=`; `inferenceError(taskId:error:)` → `taskId= error=`; `modelLoaded(name:rssBytes:durationMs:)` → `model= rssBytes= durationMs=`; `modelUnloaded(name:)` → `model=`; `modelDownloadProgress(modelId:pct:)` → `modelId= pct=`; `mcpCall(server:tool:durationMs:)` → `server= tool= durationMs=`; `thermalDowngrade(from:to:)` → `from= to=`; `oomFallback(tier:rssBytes:)` → `tier= rssBytes=`; `guardianModeChanged(enabled:)` → `enabled=`. In `InferenceEngine`, call `LogEvent.inferenceStart`, `inferenceComplete`, and `inferenceError` at the appropriate lifecycle points using `GemScanLogger.inference.info`. In `ModelLoader`, call `LogEvent.modelLoaded` and `modelUnloaded`.

**Acceptance criteria:**
- [ ] All 10 `LogEvent` static functions implemented and return correct key=value strings
- [ ] `InferenceEngine` calls `inferenceStart`, `inferenceComplete`, `inferenceError`
- [ ] `ModelLoader` calls `modelLoaded`, `modelUnloaded`
- [ ] No raw user content in any `LogEvent` output (verified by `testLogEventFormatTests` in T-08-012)
- [ ] File compiles without warnings

**Apple compliance (Spec 00 §11):**
- [ ] §11.2 — Privacy: structured events contain only safe `.public` fields

---

#### ⬜ T-08-003 · TypeScript structured logger

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P0 |
| **Spec ref** | §4.1 — TypeScript logger |
| **Depends on** | None |
| **Estimated effort** | S |
| **Files to create/modify** | `src/lib/logger.ts` |

**What to build:**
Create `src/lib/logger.ts`. Define `type LogLevel = 'debug' | 'info' | 'warn' | 'error'`. Define `interface LogEntry { level: LogLevel; message: string; timestamp: string; data?: unknown }`. Implement `function log(level: LogLevel, message: string, data?: unknown): void` with the following rules: if `process.env.NODE_ENV === 'production'` and `level === 'debug'`, return immediately without any output; in production, emit `JSON.stringify({ level, message, timestamp: new Date().toISOString(), ...(data !== undefined ? { data } : {}) })` via `console.log`; in development, emit a formatted string `[LEVEL] message` with `data` on the next line if present. Export a `logger` object with four methods: `debug(message, data?)`, `info(message, data?)`, `warn(message, data?)`, `error(message, data?)` — each calling `log` with the corresponding level. After creating this file, replace all `console.log`, `console.warn`, `console.error` calls in `src/lib/` with the appropriate `logger.*` method.

**Acceptance criteria:**
- [ ] `LogLevel` type and `LogEntry` interface exported
- [ ] `logger.debug` suppressed in production (`NODE_ENV=production`)
- [ ] All production output is valid JSON including `timestamp` field
- [ ] Development output is human-readable (not JSON)
- [ ] Existing `console.*` calls in `src/lib/` replaced with `logger.*`

**Apple compliance (Spec 00 §11):**
- [ ] §11.2 — Privacy: debug logging suppressed in production builds
- [ ] N/A — TypeScript only; no native code

---

#### ⬜ T-08-004 · InferenceMetrics + MetricsStore

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P0 |
| **Spec ref** | §5 — InferenceMetrics and MetricsStore |
| **Depends on** | T-08-001 |
| **Estimated effort** | M |
| **Files to create/modify** | `ios/App/GemmaKit/Sources/Logging/InferenceMetrics.swift` |

**What to build:**
Create `ios/App/GemmaKit/Sources/Logging/InferenceMetrics.swift`. Define `struct InferenceMetrics` with fields: `taskId: String`, `modelTier: ModelTier`, `firstTokenLatencyMs: Double`, `totalLatencyMs: Double`, `peakRSSBytes: Int`, `verdict: Verdict`, `confidence: Double`, `escalatedToE4B: Bool`, `timestamp: Date`. Add an `emit()` method that calls `os_signpost(.event, log: OSLog(subsystem: "com.gemscan", category: "inference"), name: "InferenceComplete")` and then calls `await MetricsStore.shared.record(self)`. Define `actor MetricsStore` with `static let shared = MetricsStore()`. Private `var records: [InferenceMetrics] = []` with a maximum capacity of 500. `record(_ metrics: InferenceMetrics)`: append to `records`; if `records.count > 500`, call `records.removeFirst()`. `summary() -> MetricsSummary` computes `medianLatencyMs` and `p95LatencyMs` by sorting `records.map(\.totalLatencyMs)`, plus `escalationRate` (fraction of records with `escalatedToE4B == true`), and `lowConfidenceSafeCount` (records where `verdict == .safe && confidence < 0.7`).

**Acceptance criteria:**
- [ ] `InferenceMetrics` struct has all 9 fields
- [ ] `emit()` calls `os_signpost` and `MetricsStore.shared.record(self)`
- [ ] `MetricsStore.record()` enforces 500-record FIFO: oldest evicted when full
- [ ] `summary()` correctly computes median, p95, escalation rate, low-confidence safe count
- [ ] `MetricsStore` is an `actor` (Swift actor isolation)

**Apple compliance (Spec 00 §11):**
- [ ] §11.1 — Actor isolation: `MetricsStore` is an `actor`
- [ ] §11.2 — Privacy: `InferenceMetrics` contains no raw user content

---

#### ⬜ T-08-005 · Wire InferenceMetrics into InferenceEngine

| Field | Value |
|---|---|
| **Type** | INTEGRATE |
| **Priority** | P1 |
| **Spec ref** | §5 — InferenceMetrics wiring |
| **Depends on** | T-08-004 |
| **Estimated effort** | S |
| **Files to create/modify** | `ios/App/GemmaKit/Sources/Inference/InferenceEngine.swift` |

**What to build:**
In `InferenceEngine.generate(prompt:onToken:)`, add metrics capture wrapping each call. Record `let start = Date()` before calling the model. In the `onToken` closure, record `firstTokenLatencyMs = Date().timeIntervalSince(start) * 1000` only on the first token (use a `Bool` flag `var firstTokenRecorded = false`). After the generation completes, compute `totalLatencyMs = Date().timeIntervalSince(start) * 1000` and read `peakRSSBytes` from `ProcessInfo.processInfo.physicalFootprint`. Construct an `InferenceMetrics` and call `metrics.emit()`. Apply the same wrapping to `generateVision()` if it exists. Both methods must compile without breaking actor isolation — capture `start` and `firstTokenRecorded` in a local variable outside the closure, not as actor state.

**Acceptance criteria:**
- [ ] `generate()` captures `firstTokenLatencyMs` on first `onToken` callback
- [ ] `generate()` captures `totalLatencyMs` and `peakRSSBytes` after completion
- [ ] `metrics.emit()` called after each `generate()` invocation
- [ ] Same metrics applied to `generateVision()` if present
- [ ] No actor-isolation compiler errors or warnings

**Apple compliance (Spec 00 §11):**
- [ ] §11.1 — Actor isolation: metrics capture uses local variables, not actor-isolated state

---

#### ⬜ T-08-006 · TypeScript DebugOverlay component

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P1 |
| **Spec ref** | §6 — DebugOverlay |
| **Depends on** | T-08-003 |
| **Estimated effort** | M |
| **Files to create/modify** | `src/components/DebugOverlay.tsx` |

**What to build:**
Create `src/components/DebugOverlay.tsx`. At the top of the component body, add `if (process.env.NODE_ENV === 'production') return null` to completely exclude the overlay from production builds. Render an invisible `<div>` of 64×64 px with an `onClick` counter; on the third consecutive click within 1 s, toggle `isVisible` state to true. When `isVisible`, render a fixed-position overlay panel. Use `useEffect` with a 1-second `setInterval` to poll `GemmaPlugin.getDeviceStatus()` while the overlay is visible; clear the interval when `isVisible` becomes false or on unmount. Display the following fields in a 2-column CSS grid: RAM available (MB), E2B loaded (yes/no), E4B loaded (yes/no), thermal state, battery percentage, screening mode, `NEXT_PUBLIC_IS_MOCK` value, and app version from `process.env.NEXT_PUBLIC_APP_VERSION`.

**Acceptance criteria:**
- [ ] Returns `null` immediately when `NODE_ENV === 'production'`
- [ ] Triple-tap on 64×64 invisible div (within 1 s) toggles overlay visibility
- [ ] Polls `GemmaPlugin.getDeviceStatus()` every 1 s when visible; stops when hidden
- [ ] Displays all 8 fields in a grid
- [ ] No `setInterval` leak — interval cleared on hide and unmount

**Apple compliance (Spec 00 §11):**
- [ ] §11.2 — Privacy: overlay absent in production; no sensitive data logged
- [ ] N/A — debug-only component

---

#### ⬜ T-08-007 · Swift DebugOverlayView

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P1 |
| **Spec ref** | §6 — Swift DebugOverlayView |
| **Depends on** | T-08-004 |
| **Estimated effort** | M |
| **Files to create/modify** | `ios/App/App/DebugOverlayView.swift` |

**What to build:**
Create `ios/App/App/DebugOverlayView.swift` wrapped entirely in `#if DEBUG … #endif`. Define `struct DebugOverlayView: View` with `@State private var status: DeviceStatus?` and `@State private var summary: MetricsSummary?`. In the `body`, use a `VStack` with small font displaying: RAM available, E2B loaded, E4B loaded, thermal state, pending task count, P95 latency (from `summary.p95LatencyMs`), and escalation rate (from `summary.escalationRate`). Use `Timer.publish(every: 1, on: .main, in: .common).autoconnect()` via `.onReceive` to refresh both `status` (from `InferenceEngine.shared.getDeviceStatus()`) and `summary` (from `MetricsStore.shared.summary()`) every second. Apply `.background(Color.black.opacity(0.7)).foregroundColor(.white).cornerRadius(8).padding()` for readability. Mount the view in the main `ContentView` wrapped in `#if DEBUG`.

**Acceptance criteria:**
- [ ] Entire file wrapped in `#if DEBUG … #endif`
- [ ] `Timer.publish(every: 1)` drives updates to both `status` and `summary`
- [ ] All 7 display fields present
- [ ] View mounted in `ContentView` inside `#if DEBUG`
- [ ] Release build produces no references to `DebugOverlayView`

**Apple compliance (Spec 00 §11):**
- [ ] §11.2 — Privacy: debug overlay excluded from release builds via `#if DEBUG`

---

#### ⬜ T-08-008 · Privacy annotation audit

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P2 |
| **Spec ref** | §3.2 — Privacy annotation policy |
| **Depends on** | T-08-001, T-08-002 |
| **Estimated effort** | M |
| **Files to create/modify** | `ios/App/GemmaKit/Sources/Inference/InferenceEngine.swift`, `ios/App/GemmaKit/Sources/Agents/OrchestratorAgent.swift`, `ios/App/GemmaKit/Sources/Agents/TextAgent.swift`, `ios/App/GemmaKit/Sources/MCP/MCPClient.swift`, `ios/App/GemmaKit/Sources/Logging/GemScanLogger.swift` |

**What to build:**
Audit every `GemScanLogger.*` call in `InferenceEngine.swift`, `OrchestratorAgent.swift`, `TextAgent.swift`, and `MCPClient.swift`. For each dynamic string interpolation, determine whether the value is safe to expose in system logs. Mark as `.public` (explicit `\(value, privacy: .public)`) the following categories: task IDs, verdict enum values, confidence scores, latency numbers in milliseconds, model tier names (`.e2b`, `.e4b`, `.distilbert`), and error category strings (not the full error message). Leave at default `.private` mask: any user-supplied string content, phone numbers, contact names, email addresses, URLs from user input. Document the full policy in a comment block at the top of `GemScanLogger.swift` listing which categories are `.public` and which are `.private`.

**Acceptance criteria:**
- [ ] All safe values marked `\(value, privacy: .public)` in all four files
- [ ] No user content, phone numbers, contact names, or email addresses marked `.public`
- [ ] Privacy policy comment at top of `GemScanLogger.swift` enumerates both categories
- [ ] PII scan in CI (T-09-011) passes after this audit

**Apple compliance (Spec 00 §11):**
- [ ] §11.2 — Privacy: `.public` markers applied only to non-sensitive operational metadata

---

#### ⬜ T-08-009 · MetricsStore ring buffer test

| Field | Value |
|---|---|
| **Type** | TEST |
| **Priority** | P1 |
| **Spec ref** | §5 — MetricsStore tests |
| **Depends on** | T-08-004 |
| **Estimated effort** | S |
| **Files to create/modify** | `ios/App/GemmaKit/Tests/MetricsStoreTests.swift` |

**What to build:**
Create `ios/App/GemmaKit/Tests/MetricsStoreTests.swift`. `testMetricsStoreEjectOldestWhenFull()`: create a fresh `MetricsStore`, call `record()` 501 times with unique `taskId` values (e.g., `"task-\(i)"`), then call `records.count` via a test-only accessor and assert it equals 500. Assert the first inserted record (with `taskId == "task-0"`) is no longer present in the array. `testMetricsSummaryComputesCorrectP95()`: insert 20 `InferenceMetrics` records with `totalLatencyMs` values `[10, 20, 30, ..., 200]`, call `summary()`, assert `p95LatencyMs == 190.0` (the value at index 18 of a sorted 20-element array). `testMetricsStoreIsActorIsolated()`: launch 10 concurrent `Task {}` blocks each calling `record()` 50 times; await all tasks; assert `records.count <= 500` with no data race (run with TSan enabled).

**Acceptance criteria:**
- [ ] 501 inserts → `records.count == 500` and `taskId == "task-0"` absent
- [ ] P95 of `[10, 20, ..., 200]` equals `190.0`
- [ ] Concurrent write test passes under TSan without data race
- [ ] Tests use a freshly initialised `MetricsStore` instance (not `shared`)

**Apple compliance (Spec 00 §11):**
- [ ] §11.1 — Actor isolation: TSan test verifies no data races in `MetricsStore`

---

#### ⬜ T-08-010 · Logging privacy compliance tests

| Field | Value |
|---|---|
| **Type** | TEST |
| **Priority** | P1 |
| **Spec ref** | §3.2, §4.1 — Privacy compliance |
| **Depends on** | T-08-001, T-08-003, T-08-008 |
| **Estimated effort** | M |
| **Files to create/modify** | `ios/App/GemmaKit/Tests/ComplianceTests.swift`, `src/lib/__tests__/logger.test.ts` |

**What to build:**
In `ComplianceTests.swift`, implement `testInferenceEngineDoesNotLogRawPrompt()`: set up `OSLogStore` to capture log entries from `subsystem: "com.gemscan"` during a `generate(prompt: "Congratulations you have won")` call; after the call, fetch all log entries and assert none contain the literal string `"Congratulations you have won"`. This test should be added to the existing `ComplianceTests.swift` from T-07-009. Create `src/lib/__tests__/logger.test.ts` with 3 tests: (1) `logger.debug()` does not call any `console.*` method when `process.env.NODE_ENV = 'production'` (mock `console.log` with `vi.spyOn`); (2) `logger.info('hello')` output in production is valid JSON parseable by `JSON.parse` and contains a `timestamp` field; (3) all calls include a `timestamp` field matching ISO 8601 format.

**Acceptance criteria:**
- [ ] `testInferenceEngineDoesNotLogRawPrompt` uses `OSLogStore` capture (not source-code inspection)
- [ ] Vitest test: `logger.debug` suppressed in production
- [ ] Vitest test: `logger.info` output in production is valid JSON with `timestamp`
- [ ] Vitest test: `timestamp` field present and ISO 8601 formatted

**Apple compliance (Spec 00 §11):**
- [ ] §11.2 — Privacy: raw prompt never reaches logs, verified by `OSLogStore` test

---

#### ⬜ T-08-011 · DebugOverlay dev/prod tests

| Field | Value |
|---|---|
| **Type** | TEST |
| **Priority** | P1 |
| **Spec ref** | §6 — DebugOverlay tests |
| **Depends on** | T-08-006 |
| **Estimated effort** | S |
| **Files to create/modify** | `e2e/debug-overlay.spec.ts`, `src/components/__tests__/DebugOverlay.test.tsx` |

**What to build:**
Create `e2e/debug-overlay.spec.ts` with two tests. Test 1 (production): build the app with `NODE_ENV=production` and serve it; navigate to `/`; assert there is no element with `data-testid="debug-overlay"` in the DOM. Test 2 (development): use the existing mock dev server (`NEXT_PUBLIC_IS_MOCK=true`); navigate to `/`; locate the 64×64 invisible trigger div; simulate three rapid clicks; assert the overlay panel becomes visible. Create `src/components/__tests__/DebugOverlay.test.tsx` with a Vitest test: set `process.env.NODE_ENV = 'production'`, render `<DebugOverlay />`, assert the component renders `null` (container is empty).

**Acceptance criteria:**
- [ ] Playwright production test: overlay element absent in DOM
- [ ] Playwright dev test: triple-tap shows overlay
- [ ] Vitest test: component returns `null` in production
- [ ] `data-testid="debug-overlay"` attribute added to the overlay panel in `DebugOverlay.tsx`

**Apple compliance (Spec 00 §11):**
- [ ] §11.2 — Privacy: production exclusion verified by both Playwright and Vitest

---

#### ⬜ T-08-012 · LogEvent format tests

| Field | Value |
|---|---|
| **Type** | TEST |
| **Priority** | P2 |
| **Spec ref** | §3.3 — LogEvent format |
| **Depends on** | T-08-002 |
| **Estimated effort** | S |
| **Files to create/modify** | `ios/App/GemmaKit/Tests/LogEventTests.swift` |

**What to build:**
Create `ios/App/GemmaKit/Tests/LogEventTests.swift`. `testInferenceStartFormat()`: call `LogEvent.inferenceStart(taskId: "t-123", type: .sms, modelTier: .e2b)` and assert the returned string contains `"taskId=t-123"`, `"type=sms"`, and `"modelTier=e2b"`. `testInferenceCompleteFormat()`: call `LogEvent.inferenceComplete(taskId: "t-123", verdict: .scam, confidence: 0.97, latencyMs: 342, escalated: false)` and assert the string contains `"verdict=scam"`, `"confidence=0.97"`, `"latencyMs=342"`, `"escalated=false"`. `testNoRawPIIInAnyLogEvent()`: call all 10 `LogEvent` functions with realistic parameters; for each result string, assert it does NOT contain any of the PII keywords: `"messageBody"`, `"phoneNumber"`, `"contactName"`, `"emailAddress"`, `"senderName"`, `"messageContent"`.

**Acceptance criteria:**
- [ ] `testInferenceStartFormat` asserts all 3 key=value pairs present
- [ ] `testInferenceCompleteFormat` asserts all 5 key=value pairs present
- [ ] `testNoRawPIIInAnyLogEvent` tests all 10 functions and asserts zero PII keywords

**Apple compliance (Spec 00 §11):**
- [ ] §11.2 — Privacy: LogEvent format verified to contain no PII field names

---

#### ⬜ T-08-013 · Logging developer guide

| Field | Value |
|---|---|
| **Type** | DOCUMENT |
| **Priority** | P2 |
| **Spec ref** | §7 — Logging guide |
| **Depends on** | T-08-001, T-08-002, T-08-003, T-08-004 |
| **Estimated effort** | S |
| **Files to create/modify** | `docs/logging.md`, `ios/App/GemmaKit/Sources/Logging/LogEvents.swift` |

**What to build:**
Create `docs/logging.md` with five sections. (1) Adding a new `GemScanLogger` category: copy the pattern from `GemScanLogger.swift` and list the category naming convention. (2) Privacy marker rules: copy the policy table from `GemScanLogger.swift` — which value types are `.public` and which are `.private`. (3) Console.app and Instruments filtering cheatsheet from Spec 08 §7: example filter strings such as `subsystem == "com.gemscan" AND category == "inference"`. (4) Using `OSLogStore` in tests: show a 10-line Swift snippet instantiating `OSLogStore`, creating a predicate, and iterating entries. (5) Exporting a `.logarchive` for debugging: `log collect --device --start "2025-01-01 00:00:00" --output gemscan.logarchive`. Add inline comments to `LogEvents.swift` above each function explaining the semantic meaning of each key=value field.

**Acceptance criteria:**
- [ ] All 5 sections present in `docs/logging.md`
- [ ] Console.app filter cheatsheet includes at least 3 example filter strings
- [ ] `OSLogStore` code snippet is compilable Swift
- [ ] Inline comments added to all 10 `LogEvent` functions
- [ ] `log collect` export command is correct

**Apple compliance (Spec 00 §11):**
- [ ] N/A — documentation task

---

#### ⬜ T-08-014 · Logging compliance

| Field | Value |
|---|---|
| **Type** | VALIDATE |
| **Priority** | P1 |
| **Spec ref** | §8 — Logging compliance validation |
| **Depends on** | T-08-001, T-08-002, T-08-003, T-08-006, T-08-008 |
| **Estimated effort** | S |
| **Files to create/modify** | `.github/workflows/ci.yml` |

**What to build:**
Verify four logging compliance gates. Gate 1 — CI PII scan: confirm the `pii-scan` job in `ci.yml` (from T-09-001) covers all 6 PII keywords (`messageBody`, `phoneNumber`, `contactName`, `emailAddress`, `senderName`, `messageContent`) in both Swift and TypeScript files under `ios/App/GemmaKit/Sources/` and `src/lib/`; run it locally and confirm zero violations. Gate 2 — Catch block coverage: search all Swift source files for `catch {` blocks and verify each is immediately followed by a `GemScanLogger.*. error(...)` call; add a `grep`-based CI step that fails if any `catch {` exists without a subsequent log call within 3 lines. Gate 3 — DebugOverlay absent in production: Playwright `e2e/debug-overlay.spec.ts` must pass (from T-08-011). Gate 4 — TypeScript debug suppression: Vitest `src/lib/__tests__/logger.test.ts` must pass (from T-08-010).

**Acceptance criteria:**
- [ ] PII scan: zero violations for all 6 keywords across Swift and TypeScript
- [ ] All `catch {}` blocks in GemmaKit have a `GemScanLogger.*. error` within 3 lines
- [ ] DebugOverlay Playwright test passes (production build shows no overlay)
- [ ] TypeScript logger Vitest tests pass
- [ ] All 4 gates run in CI and block merge on failure

**Apple compliance (Spec 00 §11):**
- [ ] §11.2 — Privacy: all four compliance gates enforced in CI
