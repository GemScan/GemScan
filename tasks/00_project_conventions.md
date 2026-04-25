# Tasks — Project Conventions

> **Spec:** `specs/00_project_conventions.md` | **Milestone:** M0 — Foundation & Conventions | **Depends on:** None — start here

## Milestone Summary
M0 establishes the canonical directory layout, toolchain configuration, core TypeScript and Swift types, and the compliance baseline that every subsequent milestone builds on. Nothing in M1–M9 can begin until the type contracts (`AgentTask`, `AgentResult`, `GemScanError`) and lint/format rules defined here are merged and green in CI. This milestone produces no user-visible features — only the shared foundation that prevents every downstream task from diverging.

## Prerequisites
- None — start here

## Progress Tracker
| Status | Count |
|--------|-------|
| ✅ Done | 0 |
| 🔄 In progress | 0 |
| ⬜ Not started | 12 |

Update this table as tasks complete. Each task row also has a status checkbox.

---

## Tasks

### Group: Repository Scaffold

---

#### ⬜ T-00-001 · Create repo directory structure

| Field | Value |
|---|---|
| **Type** | SCAFFOLD |
| **Priority** | P0 (blocking) |
| **Spec ref** | §1 — Repository Layout |
| **Depends on** | None |
| **Estimated effort** | S (< 1 hr) |
| **Files to create/modify** | `src/app/`, `src/components/`, `src/hooks/`, `src/lib/agents/`, `src/lib/mcp/`, `src/lib/gemma/`, `src/styles/`, `ios/App/GemmaKit/Sources/Inference/`, `ios/App/GemmaKit/Sources/Agents/`, `ios/App/GemmaKit/Sources/MCP/`, `ios/App/GemmaKit/Sources/Router/`, `ios/App/GemmaKit/Sources/Extensions/`, `ios/App/GemmaKit/Sources/Logging/`, `ios/App/GemmaKit/Tests/`, `ios/App/Plugins/`, `ios/App/Extensions/`, `specs/`, `tasks/`, `scripts/finetune/`, `scripts/export/`, `scripts/data/`, `.github/workflows/`, `.gitignore`, `README.md` |

**What to build:**
Create the full directory tree exactly as described in Spec 00 §1. Each leaf directory must contain a `.gitkeep` placeholder so git tracks empty directories. Create `.gitignore` at the repo root with entries for `models/`, `*.gguf`, `node_modules/`, `.next/`, and `out/` — the `models/` and `*.gguf` entries are critical because model weights must never be committed. Create a minimal `README.md` stub with the project name "GemScan" and a one-line description. The `ios/App/GemmaKit/Sources/Logging/` directory is needed by Spec 08 but must be scaffolded now.

**Acceptance criteria:**
- [ ] `find . -name '.gitkeep' | wc -l` returns ≥ 17 (one per empty leaf directory)
- [ ] `.gitignore` contains `models/`, `*.gguf`, `node_modules/`, `.next/`, `out/` as separate entries
- [ ] `git ls-files --others --ignored --exclude-standard models/` returns no files
- [ ] `README.md` exists at repo root and is non-empty

**Apple compliance (Spec 00 §11):**
- [ ] N/A — no native code in this task

---

#### ⬜ T-00-002 · Configure TypeScript + ESLint + Prettier

| Field | Value |
|---|---|
| **Type** | SCAFFOLD |
| **Priority** | P0 (blocking) |
| **Spec ref** | §2 — Language and Runtime Versions; §3 — Naming Conventions (TypeScript) |
| **Depends on** | T-00-001 |
| **Estimated effort** | S (< 1 hr) |
| **Files to create/modify** | `tsconfig.json`, `.eslintrc.json`, `.prettierrc`, `package.json` (devDependencies only) |

**What to build:**
Create `tsconfig.json` with `"strict": true`, `"target": "ES2022"`, `"lib": ["ES2022", "DOM"]`, `"moduleResolution": "bundler"`, `"jsx": "preserve"`, and `"paths"` configured for `@/*` → `./src/*` (Next.js convention). Create `.eslintrc.json` extending `["next/core-web-vitals", "plugin:@typescript-eslint/strict"]` with `"parser": "@typescript-eslint/parser"`. Create `.prettierrc` with `singleQuote: true`, `semi: false`, `tabWidth: 2`, `trailingComma: "es5"`. Add the required dev packages (`typescript@5.5.4`, `eslint`, `@typescript-eslint/eslint-plugin`, `@typescript-eslint/parser`, `prettier`) with exact version pins.

**Acceptance criteria:**
- [ ] `npx tsc --noEmit` exits 0 on a project with only `src/lib/gemma/types.ts` (created in T-00-004)
- [ ] `npx eslint src/ --max-warnings 0` exits 0 on the empty `src/` scaffold
- [ ] `npx prettier --check src/` exits 0 on freshly generated files
- [ ] `tsconfig.json` `strict` is `true` (verified by `jq .compilerOptions.strict tsconfig.json`)

**Apple compliance (Spec 00 §11):**
- [ ] N/A — TypeScript tooling only; no native code

---

#### ⬜ T-00-003 · Configure SwiftLint

| Field | Value |
|---|---|
| **Type** | SCAFFOLD |
| **Priority** | P0 (blocking) |
| **Spec ref** | §11.1 — Swift Concurrency and Memory Safety |
| **Depends on** | T-00-001 |
| **Estimated effort** | S (< 1 hr) |
| **Files to create/modify** | `.swiftlint.yml` |

**What to build:**
Create `.swiftlint.yml` at the repo root. Enable opt-in rules: `force_unwrapping`, `force_try`, `implicitly_unwrapped_optional`, `strict_fileprivate`. Add a custom `no_print` rule with `regex: "^\\s*print\\("` and `message: "Use os.Logger instead of print()"`. Add a custom `no_nsuserdefaults_direct` rule with `regex: "UserDefaults\\.standard"` and `message: "Use UserDefaults(suiteName:) with SharedContainerSchema.appGroupId — never UserDefaults.standard"`. Set `included: ["ios/App/GemmaKit/Sources", "ios/App/Plugins", "ios/App/Extensions"]` and `excluded: ["ios/App/GemmaKit/Tests"]`. Configure `reporter: "xcode"` so Xcode surfaces lint errors inline.

**Acceptance criteria:**
- [ ] `swiftlint lint ios/App/GemmaKit/Sources/` exits 0 on empty sources
- [ ] `swiftlint lint --strict ios/App/GemmaKit/Sources/` exits 0 on empty sources
- [ ] A test file containing `print("hello")` is flagged by the `no_print` rule
- [ ] A test file containing `UserDefaults.standard` is flagged by `no_nsuserdefaults_direct`

**Apple compliance (Spec 00 §11):**
- [ ] §11.1 — `force_unwrapping` and `force_try` rules enforce the no-force-unwraps requirement across all native source

---

### Group: Core TypeScript Types

---

#### ⬜ T-00-004 · Core TypeScript type definitions

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P0 (blocking) |
| **Spec ref** | §4 — Core Data Contracts; §8 — Web App Mode vs iOS Dev Mode |
| **Depends on** | T-00-002 |
| **Estimated effort** | M (1–3 hr) |
| **Files to create/modify** | `src/lib/gemma/types.ts`, `src/lib/platform.ts` |

**What to build:**
Create `src/lib/gemma/types.ts` exporting all canonical TypeScript types from Spec 00 §4: `AgentTaskType` (string union with six values: `'classifySMS' | 'classifyEmail' | 'checkURL' | 'analyseScreenshot' | 'scoreVoice' | 'explainVerdict'`), `AgentPayload` (discriminated union keyed on `type` field with five variants: `text`, `url`, `image`, `audio`, `multimodal`), `AgentTask` (interface with fields `id`, `type`, `payload`, `priority`, `createdAt`, `timeoutMs`), `AgentResult` (interface with fields `taskId`, `agentId`, `verdict`, `confidence`, `reasoning`, `language`, `toolCallsLog`, `latencyMs`, `modelTier`, `escalatedToE4B`), `ScamVerdict` (`'safe' | 'suspicious' | 'scam'`), `ToolCallRecord`, `ModelId` (`'e2b' | 'e4b' | 'distilbert'`), and `DeviceStatus`. Also export the `GemmaPlugin` interface with all five methods: `isReady()`, `downloadModels()`, `analyse()`, `getDeviceStatus()`, and the three `addListener()` overloads (`tokenStream`, `downloadProgress`, `guardianModeChanged`). Create `src/lib/platform.ts` exporting `isNativePlatform()` exactly as specified in Spec 00 §8.

**Acceptance criteria:**
- [ ] `npx tsc --noEmit` exits 0 with only `src/lib/gemma/types.ts` and `src/lib/platform.ts` present
- [ ] `AgentPayload` is a discriminated union — TypeScript narrows correctly on the `type` field in a `switch` statement
- [ ] `ScamVerdict` values `'safe'`, `'suspicious'`, `'scam'` are the only assignable strings
- [ ] `isNativePlatform()` return type is `boolean` (not `any`)

**Apple compliance (Spec 00 §11):**
- [ ] N/A — TypeScript-only file; no native code

---

### Group: Core Swift Types

---

#### ⬜ T-00-005 · Swift core type mirrors

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P0 (blocking) |
| **Spec ref** | §4 — Core Data Contracts (Swift AgentTask, AgentResult, ModelTier, TriageLabel structs) |
| **Depends on** | T-00-001 |
| **Estimated effort** | M (1–3 hr) |
| **Files to create/modify** | `ios/App/GemmaKit/Sources/Agents/AgentTask.swift`, `ios/App/GemmaKit/Sources/Agents/AgentResult.swift`, `ios/App/GemmaKit/Sources/Inference/ModelTier.swift`, `ios/App/GemmaKit/Sources/Inference/TriageLabel.swift` |

**What to build:**
Create `AgentTask.swift` with the `AgentTask` struct, `AgentPayload` enum (five cases: `.text(String, language: String?)`, `.url(String)`, `.image(String, mimeType: ImageMIMEType)`, `.audio(String, durationSeconds: Double)`, `.multimodal(parts: [AgentPayload], priorResult: AgentResult?)`), `TaskPriority` enum, and all `CodingKeys` enums exactly as in Spec 00 §4. Create `AgentResult.swift` with `AgentResult` struct, `ScamVerdict` enum (`.safe`, `.suspicious`, `.scam` with raw values matching TypeScript), `ToolCallRecord` struct, and the `markingEscalated(latencyMs:)` method. Create `ModelTier.swift` with `expectedRAMBytes` computed property (e2b: 1,800 MB, e4b: 3,200 MB, distilbert: 5 MB). Create `TriageLabel.swift` with `TriageLabel` enum and `TriageResult` struct including `senderHash: String`, `label: TriageLabel`, `confidence: Double`, and `timestampMs: Int64` fields. All types must conform to `Codable`.

**Acceptance criteria:**
- [ ] `xcodebuild build -scheme GemmaKit` succeeds with these four files as the only Swift sources
- [ ] `AgentTaskType` raw string values match TypeScript exactly: `"classifySMS"`, `"classifyEmail"`, `"checkURL"`, `"analyseScreenshot"`, `"scoreVoice"`, `"explainVerdict"`
- [ ] `ScamVerdict` raw values are `"safe"`, `"suspicious"`, `"scam"` (verified by `XCTAssertEqual(ScamVerdict.scam.rawValue, "scam")`)
- [ ] `ModelTier.e2b.expectedRAMBytes == 1_800 * 1_024 * 1_024` (1,887,436,800)

**Apple compliance (Spec 00 §11):**
- [ ] §11.1 — All types are `Sendable`-conformant (structs with value-type fields are implicitly `Sendable`); verify with `SWIFT_STRICT_CONCURRENCY=complete`

---

#### ⬜ T-00-006 · GemScanError enum

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P0 (blocking) |
| **Spec ref** | §5 — Error Handling |
| **Depends on** | T-00-005 |
| **Estimated effort** | S (< 1 hr) |
| **Files to create/modify** | `ios/App/GemmaKit/Sources/GemScanError.swift` |

**What to build:**
Create `ios/App/GemmaKit/Sources/GemScanError.swift` with the `GemScanError` enum conforming to `Error` and `CustomStringConvertible`. Implement all six cases from Spec 00 §5: `modelNotLoaded(tier: ModelTier)`, `inferenceTimeout(taskId: String, limitMs: Int)`, `oomRejected(requestedBytes: Int, availableBytes: Int)`, `grammarViolation(raw: String)`, `mcpToolFailed(server: String, tool: String, underlying: Error)`, `audioIngestionUnavailable(reason: String)`. The `description` property must be human-readable and must not include any PII — for `grammarViolation`, the `raw` string is model output and must be truncated to 50 characters with `"[truncated]"` suffix. For `mcpToolFailed`, only log `server` and `tool` names, not the underlying error message (which may contain user data).

**Acceptance criteria:**
- [ ] `GemScanError.inferenceTimeout(taskId: "abc", limitMs: 5000).description` does not contain the literal string `"abc"` (taskId is PII-adjacent)
- [ ] `GemScanError.grammarViolation(raw: String(repeating: "x", count: 200)).description.count` is ≤ 80 characters
- [ ] All six enum cases compile without warnings under `SWIFT_STRICT_CONCURRENCY=complete`
- [ ] `GemScanError` conforms to `CustomStringConvertible` (verified by `let _: CustomStringConvertible = GemScanError.modelNotLoaded(tier: .e2b)`)

**Apple compliance (Spec 00 §11):**
- [ ] §11.3 — `description` property verified to contain no PII: no message content, contact names, audio transcripts, or raw model output beyond 50 chars

---

### Group: TypeScript Plugin Interface & Store

---

#### ⬜ T-00-007 · GemmaPlugin TypeScript interface + web mock registration

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P1 (high) |
| **Spec ref** | §8 — Web App Mode vs iOS Dev Mode (Mock Registration, Mock Contract) |
| **Depends on** | T-00-004 |
| **Estimated effort** | M (1–3 hr) |
| **Files to create/modify** | `src/lib/gemma/index.ts`, `src/lib/gemma/mock.ts`, `src/lib/logger.ts` |

**What to build:**
Create `src/lib/gemma/index.ts` that exports `GemmaPlugin` as either `GemmaPluginNative` or `GemmaPluginMock` based on `isNativePlatform()`, exactly as in Spec 00 §8. Create `src/lib/gemma/mock.ts` implementing the full `GemmaPlugin` interface as `GemmaPluginMock`. The mock `analyse()` must simulate 300–800 ms latency via `sleep(300 + Math.random() * 500)`, look up a golden fixture from `goldenFixtures` keyed by `task.id`, fall back to `goldenFixtures['default']` for unknown IDs, emit a `tokenStream` event with `done: true`, and log `[MOCK] analyse` via `logger.info`. The mock `downloadModels()` must emit `downloadProgress` events at 10% intervals with 50 ms delays, with `totalBytes: 1_500_000_000`. Create `src/lib/logger.ts` with a structured logger that emits JSON in production (`process.env.NODE_ENV === 'production'`) and pretty-prints in development with `[INFO]`, `[WARN]`, `[ERROR]` prefixes.

**Acceptance criteria:**
- [ ] `GemmaPlugin` resolves to `GemmaPluginMock` in a jsdom environment (verified in T-00-010)
- [ ] `GemmaPluginMock.analyse({ id: 'scam-sms-bank', ... })` returns the `'scam-sms-bank'` fixture without network calls
- [ ] `GemmaPluginMock.analyse({ id: 'nonexistent', ... })` returns the `'default'` fixture
- [ ] Every mock method call produces a `[MOCK]`-prefixed log entry via `logger.info`

**Apple compliance (Spec 00 §11):**
- [ ] N/A — TypeScript-only; no native code in this task

---

#### ⬜ T-00-008 · Zustand store

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P1 (high) |
| **Spec ref** | §8 — Web App Mode (state management referenced); Spec 01 §8 — State Management |
| **Depends on** | T-00-004 |
| **Estimated effort** | S (< 1 hr) |
| **Files to create/modify** | `src/lib/store.ts` |

**What to build:**
Create `src/lib/store.ts` exporting `useGemScanStore` using Zustand `create` with the `persist` middleware. The store interface `GemScanStore` must include: `screeningMode: 'passive' | 'active' | 'guardian'` (default `'active'`), `guardianModeEnabled: boolean` (default `false`), `trustedContactId: string | null` (default `null`), `preferredLanguage: string` (default `navigator.language.split('-')[0] ?? 'en'`), `recentResults: AgentResult[]` (default `[]`), and setter actions `setScreeningMode`, `setGuardianMode`, `setTrustedContact`, `setPreferredLanguage`, `addRecentResult`. Configure `persist` with `name: 'gemscan-store'`, `version: 1`, and a `migrate` stub that passes through persisted state for v0→v1. Import `AgentResult` from `./gemma/types`.

**Acceptance criteria:**
- [ ] `useGemScanStore.getState().screeningMode === 'active'` on fresh initialisation
- [ ] `useGemScanStore.getState().setGuardianMode(true)` causes `guardianModeEnabled` to be `true`
- [ ] The persist storage key is exactly `'gemscan-store'` (verified by inspecting `localStorage` in jsdom)
- [ ] `npx tsc --noEmit` passes with `src/lib/store.ts` present

**Apple compliance (Spec 00 §11):**
- [ ] N/A — TypeScript-only; no native code in this task

---

### Group: Tests

---

#### ⬜ T-00-009 · Core type round-trip tests

| Field | Value |
|---|---|
| **Type** | TEST |
| **Priority** | P1 (high) |
| **Spec ref** | §4 — Core Data Contracts (CodingKeys and JSON wire format) |
| **Depends on** | T-00-004, T-00-005 |
| **Estimated effort** | M (1–3 hr) |
| **Files to create/modify** | `src/lib/gemma/__tests__/types.test.ts`, `ios/App/GemmaKit/Tests/CoreTypesTests.swift` |

**What to build:**
Create `src/lib/gemma/__tests__/types.test.ts` with Vitest tests verifying: (1) an `AgentTask` object can be serialised with `JSON.stringify` and deserialised with `JSON.parse` with all fields intact, including the discriminated union `payload` field; (2) an `AgentResult` round-trips correctly including the `toolCallsLog` array and `escalatedToE4B` boolean; (3) `ScamVerdict` string values are exactly `'safe'`, `'suspicious'`, `'scam'`. Create `ios/App/GemmaKit/Tests/CoreTypesTests.swift` with XCTest cases verifying: (1) `AgentTask` with a `.text` payload encodes to JSON and decodes back with `JSONEncoder`/`JSONDecoder`; (2) `AgentResult` round-trips with all fields; (3) `ScamVerdict.scam.rawValue == "scam"`, `ScamVerdict.safe.rawValue == "safe"`, `ScamVerdict.suspicious.rawValue == "suspicious"` — these three assertions are the critical cross-language contract check.

**Acceptance criteria:**
- [ ] `npx vitest run src/lib/gemma/__tests__/types.test.ts` exits 0
- [ ] `xcodebuild test -scheme GemmaKitTests -only-testing GemmaKitTests/CoreTypesTests` exits 0
- [ ] `ScamVerdict` raw values match between TypeScript and Swift (both test suites assert the same string constants)
- [ ] Vitest coverage on `src/lib/gemma/types.ts` is 100% (all exported types exercised)

**Apple compliance (Spec 00 §11):**
- [ ] §11.1 — `AgentTask` and `AgentResult` conform to `Sendable` (value-type structs); verified by `SWIFT_STRICT_CONCURRENCY=complete` build of test target

---

#### ⬜ T-00-010 · Platform detection and mock registration tests

| Field | Value |
|---|---|
| **Type** | TEST |
| **Priority** | P1 (high) |
| **Spec ref** | §8 — Web App Mode vs iOS Dev Mode (Detection Pattern, Mock Contract) |
| **Depends on** | T-00-007 |
| **Estimated effort** | M (1–3 hr) |
| **Files to create/modify** | `src/lib/__tests__/platform.test.ts`, `src/lib/gemma/__tests__/mock.test.ts`, `ios/App/GemmaKit/Tests/ActorIsolationTests.swift` |

**What to build:**
Create `src/lib/__tests__/platform.test.ts` verifying: `isNativePlatform()` returns `false` in a jsdom environment (no `window.Capacitor`); `isNativePlatform()` returns `true` when `window.Capacitor = { isNativePlatform: () => true }` is injected. Create `src/lib/gemma/__tests__/mock.test.ts` verifying: `GemmaPlugin` is the mock object in jsdom; `GemmaPlugin.isReady()` resolves to `{ ready: true, missingModels: [] }`; `GemmaPlugin.analyse(task)` resolves to a valid `AgentResult` with all required fields within 1000 ms; `GemmaPlugin.addListener('tokenStream', handler)` returns `{ remove: Function }`. Create `ios/App/GemmaKit/Tests/ActorIsolationTests.swift` with `testInferenceEngineIsActor()`, `testOrchestratorAgentIsActor()`, `testMCPClientIsActor()` — each test verifies that the type is an actor by checking `type(of:)` metadata (or simply by calling an `async` method that requires `await`, which is a compile-time proof of actor isolation).

**Acceptance criteria:**
- [ ] `isNativePlatform()` returns `false` in jsdom (no `window.Capacitor` mock)
- [ ] `GemmaPlugin.analyse()` mock resolves within 1000 ms in Vitest
- [ ] `xcodebuild test -scheme GemmaKitTests -only-testing GemmaKitTests/ActorIsolationTests` exits 0
- [ ] Vitest coverage on `src/lib/platform.ts` is 100%

**Apple compliance (Spec 00 §11):**
- [ ] §11.1 — Actor isolation tests directly verify the `actor` keyword is used on `InferenceEngine`, `OrchestratorAgent`, and `MCPClient`, satisfying the no-data-races requirement

---

### Group: Documentation

---

#### ⬜ T-00-011 · DocC documentation for GemmaKit public API

| Field | Value |
|---|---|
| **Type** | DOCUMENT |
| **Priority** | P2 (standard) |
| **Spec ref** | §3 — Naming Conventions (Swift); §11.7 — Task Completion Definition |
| **Depends on** | T-00-005, T-00-006 |
| **Estimated effort** | M (1–3 hr) |
| **Files to create/modify** | `ios/App/GemmaKit/Sources/GemmaKit.docc/GemmaKit.md`, `ios/App/GemmaKit/Sources/GemmaKit.docc/Resources/`, `ios/App/GemmaKit/Sources/Agents/AgentTask.swift`, `ios/App/GemmaKit/Sources/Agents/AgentResult.swift`, `ios/App/GemmaKit/Sources/GemScanError.swift` |

**What to build:**
Add `///` DocC comments to all `public` symbols in GemmaKit: `AgentTask` struct (describe the bridge serialization contract and the `CodingKeys` camelCase wire format), `AgentPayload` enum (document each case's associated values), `AgentResult` struct (document the `markingEscalated(latencyMs:)` method), `GemScanError` enum (document each case's parameters and when each is thrown), `ModelTier` enum (document `expectedRAMBytes` and Q4_K_M RAM ceilings). Create `GemmaKit.docc/GemmaKit.md` as the DocC overview article with a `## Topics` section listing all public types. The article must explain that GemmaKit is iOS 16+ and link to the Inference, Agents, MCP, and Router module overview pages.

**Acceptance criteria:**
- [ ] `xcodebuild docbuild -scheme GemmaKit -destination generic/platform=iOS` exits 0
- [ ] Zero "missing documentation" warnings for public symbols in the DocC build output
- [ ] `GemmaKit.docc/GemmaKit.md` exists and contains a `## Topics` section with at least 4 type links
- [ ] `AgentTask` DocC comment explicitly mentions the JSON camelCase wire format and `CodingKeys`

**Apple compliance (Spec 00 §11):**
- [ ] N/A — documentation task; no runtime behavior changes

---

### Group: Validation

---

#### ⬜ T-00-012 · Apple compliance baseline

| Field | Value |
|---|---|
| **Type** | VALIDATE |
| **Priority** | P1 (high) |
| **Spec ref** | §11.1 — Swift Concurrency; §11.7 — Task Completion Definition |
| **Depends on** | T-00-003, T-00-005, T-00-006, T-00-009, T-00-010 |
| **Estimated effort** | M (1–3 hr) |
| **Files to create/modify** | `.github/workflows/lint.yml` (CI gate), PR description (Apple Compliance Notes section) |

**What to build:**
Run the full M0 compliance checklist. Execute `xcodebuild analyze -scheme GemmaKit -destination generic/platform=iOS` and confirm zero analyzer issues on `AgentTask.swift`, `AgentResult.swift`, `GemScanError.swift`, `ModelTier.swift`, and `TriageLabel.swift`. Run `swiftlint lint --strict ios/App/GemmaKit/Sources/` and confirm zero errors. Build GemmaKit with `SWIFT_STRICT_CONCURRENCY=complete` in Build Settings and resolve any new concurrency warnings. Create `.github/workflows/lint.yml` that runs on every PR: `npx tsc --noEmit`, `npx eslint src/ --max-warnings 0`, `swiftlint lint --strict ios/App/GemmaKit/Sources/`, and `xcodebuild analyze`. Fill out the PR description "Apple Compliance Notes" template from Spec 00 §11.7 for the M0 milestone PR, marking §11.3–§11.6 as N/A with justification (no UI, no permissions, no network, no Keychain in M0).

**Acceptance criteria:**
- [ ] `xcodebuild analyze -scheme GemmaKit` reports zero issues
- [ ] `swiftlint lint --strict ios/App/GemmaKit/Sources/` exits 0
- [ ] GemmaKit builds clean under `SWIFT_STRICT_CONCURRENCY=complete` with zero new warnings
- [ ] `.github/workflows/lint.yml` CI workflow file exists and all jobs are defined
- [ ] PR description contains "Apple Compliance Notes" section with §11.1 verified, §11.3–§11.6 marked N/A with justification

**Apple compliance (Spec 00 §11):**
- [ ] §11.1 — `SWIFT_STRICT_CONCURRENCY=complete` build verified clean
- [ ] §11.1 — SwiftLint `force_unwrapping` and `force_try` rules confirmed active and passing
- [ ] §11.3 — Confirmed no PII in `GemScanError.description` outputs (manual review of all six cases)
