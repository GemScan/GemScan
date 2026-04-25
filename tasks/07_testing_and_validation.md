# Tasks — Full Test Suite

> **Spec:** `specs/07_testing_and_validation.md` | **Milestone:** M7 — Full Test Suite | **Depends on:** M6

## Milestone Summary
Establishes the complete multi-layer test infrastructure for GemScan: Vitest unit tests with coverage enforcement, Playwright E2E tests on chromium and Mobile Safari, XCTest unit and integration tests, XCUITest UI automation, benchmark tests with regression gates, and Apple Platform compliance tests. All implementation milestones M0–M6 must be complete before this milestone begins.

## Prerequisites
- M0–M6 all implementation tasks complete
- Xcode 15.3 installed with iPhone 15 Pro iOS 17.4 simulator available
- Node.js dependencies installed (`vitest`, `@testing-library/react`, `playwright`, `@axe-core/playwright`)
- Swift Package Manager resolves all GemmaKit dependencies

## Progress Tracker
| Status | Count |
|--------|-------|
| ✅ Done | 18 |
| 🔄 In progress | 0 |
| ⬜ Not started | 3 |

---
## Tasks

#### ✅ T-07-001 · Vitest configuration

| Field | Value |
|---|---|
| **Type** | SCAFFOLD |
| **Priority** | P0 |
| **Spec ref** | §2.1 — Vitest configuration |
| **Depends on** | None |
| **Estimated effort** | S |
| **Files to create/modify** | `vitest.config.ts`, `src/test/setup.ts` |

**What to build:**
Create `vitest.config.ts` at the repository root with the following configuration: `environment: 'jsdom'`; `include: ['src/**/*.test.ts', 'src/**/*.test.tsx']`; `coverage.provider: 'v8'`; `coverage.thresholds: { lines: 80, functions: 80, branches: 75 }`; `coverage.reporter: ['lcov', 'html']`. Create `src/test/setup.ts` which calls `vi.mock('@/lib/gemma', ...)` returning a standard test stub object with `isReady: vi.fn().mockResolvedValue({ ready: true })`, `analyse: vi.fn().mockResolvedValue(goldenFixtures['default'])`, `addListener: vi.fn().mockReturnValue({ remove: vi.fn() })`, and `downloadModels: vi.fn().mockResolvedValue(undefined)`, `getDeviceStatus: vi.fn().mockResolvedValue({ ram: 4096, thermalState: 'nominal' })`.

**Acceptance criteria:**
- [ ] `npm run test:unit` runs with jsdom environment
- [ ] Coverage thresholds enforced: 80% lines, 80% functions, 75% branches
- [ ] Coverage reports generated in `lcov` and `html` formats
- [ ] `src/test/setup.ts` mock stub covers all 5 GemmaPlugin methods
- [ ] `vitest.config.ts` references `src/test/setup.ts` via `setupFiles`

**Apple compliance (Spec 00 §11):**
- [ ] N/A — no native code in this scaffold

---

#### ✅ T-07-002 · Playwright configuration

| Field | Value |
|---|---|
| **Type** | SCAFFOLD |
| **Priority** | P0 |
| **Spec ref** | §4.1 — Playwright configuration |
| **Depends on** | None |
| **Estimated effort** | S |
| **Files to create/modify** | `playwright.config.ts` |

**What to build:**
Create `playwright.config.ts` at the repository root. Set `testDir: './e2e'` and `fullyParallel: true`. Define two projects: `chromium` using `devices['Desktop Chrome']` and `Mobile Safari` using `devices['iPhone 15 Pro']`. Configure `webServer` to run `NEXT_PUBLIC_IS_MOCK=true npm run dev` and wait for `http://localhost:3000` to be available. Set `use.baseURL: 'http://localhost:3000'`. Set `reporter: [['html', { outputFolder: 'playwright-report' }]]`. Set `timeout: 30_000` per test and `expect.timeout: 10_000`.

**Acceptance criteria:**
- [ ] `npx playwright test` launches both chromium and Mobile Safari projects
- [ ] `webServer` starts the mock Next.js dev server automatically
- [ ] `baseURL` set to `http://localhost:3000`
- [ ] HTML report generated in `playwright-report/`
- [ ] `NEXT_PUBLIC_IS_MOCK=true` environment variable passed to the dev server

**Apple compliance (Spec 00 §11):**
- [ ] N/A — no native code in this scaffold

---

#### ✅ T-07-003 · Mock actor infrastructure

| Field | Value |
|---|---|
| **Type** | SCAFFOLD |
| **Priority** | P0 |
| **Spec ref** | §3.0 — Mock actor infrastructure |
| **Depends on** | None |
| **Estimated effort** | M |
| **Files to create/modify** | `ios/App/GemmaKit/Tests/Mocks/MockInferenceEngine.swift`, `ios/App/GemmaKit/Tests/Mocks/MockMCPClient.swift`, `ios/App/GemmaKit/Tests/Mocks/MockMessageRouter.swift` |

**What to build:**
Create `MockInferenceEngine.swift` as an `actor` conforming to `InferenceEngineProtocol`. It holds `var nextOutput: String = ""` and `var responses: [String] = []`. `generate(prompt:onToken:)` consumes `responses.removeFirst()` if available, else uses `nextOutput`; it streams by splitting the string on whitespace and calling `onToken` for each word with a 1 ms `Task.sleep` between calls. Create `MockMCPClient.swift` as an `actor` conforming to `MCPClientProtocol`. It holds `var callLog: [(server: String, tool: String, params: [String:Any])] = []`. It provides canned responses for all 10 MCP servers. Create `MockMessageRouter.swift` with `var draftConfidence: Double = 0.85` used as the returned confidence from `routeMessage(_:)`.

**Acceptance criteria:**
- [ ] `MockInferenceEngine` streams tokens word-by-word with `responses` array consumed in order
- [ ] `MockMCPClient` records every call in `callLog` and returns canned responses for all 10 servers
- [ ] `MockMessageRouter` returns `draftConfidence` as the routing confidence
- [ ] All three mocks compile without errors and conform to their respective protocols

**Apple compliance (Spec 00 §11):**
- [ ] N/A — test infrastructure only; no production code paths

---

#### ✅ T-07-004 · Test helper extensions

| Field | Value |
|---|---|
| **Type** | SCAFFOLD |
| **Priority** | P0 |
| **Spec ref** | §3.0 — Test helper extensions |
| **Depends on** | None |
| **Estimated effort** | S |
| **Files to create/modify** | `ios/App/GemmaKit/Tests/TestHelpers.swift`, `src/lib/gemma/__fixtures__/golden.ts` |

**What to build:**
Create `ios/App/GemmaKit/Tests/TestHelpers.swift` with two extensions on the production types. `extension AgentTask { static func fixture(id: String = "test-1", type: TaskType = .sms, content: String = "Hello") -> AgentTask }` and `extension AgentResult { static func fixture(verdict: Verdict = .safe, confidence: Double = 0.95, reasoning: [String] = ["No threats found"]) -> AgentResult }`. These allow concise test setup without repeating initialiser arguments. Create `src/lib/gemma/__fixtures__/golden.ts` exporting `goldenFixtures: Record<string, AgentResult>` with all 12 named entries (e.g., `'safe-greeting'`, `'scam-prize'`, `'suspicious-link'`, etc.) plus a `'default'` key pointing to a safe fixture.

**Acceptance criteria:**
- [ ] `AgentTask.fixture()` compiles and returns a valid `AgentTask` with default values overridable by named arguments
- [ ] `AgentResult.fixture()` compiles and returns a valid `AgentResult`
- [ ] `goldenFixtures` contains exactly 12 named entries plus `'default'`
- [ ] `goldenFixtures['default']` has `verdict: 'safe'`

**Apple compliance (Spec 00 §11):**
- [ ] N/A — test fixtures only

---

#### ✅ T-07-005 · XCTest scheme and test plan

| Field | Value |
|---|---|
| **Type** | BUILD |
| **Priority** | P0 |
| **Spec ref** | §3 — XCTest scheme |
| **Depends on** | T-07-003, T-07-004 |
| **Estimated effort** | S |
| **Files to create/modify** | `ios/App/GemScanUITests.xctestplan`, `ios/App/BenchmarkTests.xctestplan` |

**What to build:**
In Xcode, create a `GemmaKit` scheme that includes all Swift test targets under `ios/App/GemmaKit/Tests/`. Create `GemScanUITests.xctestplan` including `GemScanUITests` and `ComplianceTests` targets with parallelism enabled and a 60-second timeout per test. Create `BenchmarkTests.xctestplan` including only `BenchmarkTests` with `maximumTestRepetitions: 5` for statistical averaging. Verify that `xcodebuild test -scheme GemmaKit -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=17.4'` exits 0 with all test targets discovered. Commit both `.xctestplan` files and the scheme file.

**Acceptance criteria:**
- [ ] `xcodebuild test -scheme GemmaKit -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=17.4'` exits 0
- [ ] All test targets discovered and run (check `Test session results` output)
- [ ] `GemScanUITests.xctestplan` file committed to the repository
- [ ] `BenchmarkTests.xctestplan` with `maximumTestRepetitions: 5` committed
- [ ] CI `swift-unit` job uses this scheme

**Apple compliance (Spec 00 §11):**
- [ ] N/A — build configuration task

---

#### ✅ T-07-006 · Agent round-trip XCTests

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P1 |
| **Spec ref** | §3.1 — Agent round-trip tests |
| **Depends on** | T-07-003, T-07-004 |
| **Estimated effort** | M |
| **Files to create/modify** | `ios/App/GemmaKit/Tests/AgentRoundTripTests.swift` |

**What to build:**
Implement `ios/App/GemmaKit/Tests/AgentRoundTripTests.swift` as an `XCTestCase`. `testTextAgentSafeMessage()`: create `TextAgent(engine: MockInferenceEngine(nextOutput: "VERDICT:safe CONFIDENCE:0.97"))`, call `analyse(AgentTask.fixture(content: "Hello, how are you?"))`, assert `result.verdict == .safe` and `result.confidence >= 0.9`. `testOrchestratorEscalatesLowConfidenceToE4B()`: set `MockInferenceEngine.nextOutput` to an E2B-tier output with `confidence:0.45`, call the `OrchestratorAgent`, assert `result.escalatedToE4B == true` and `result.modelTier == .e4b`. `testJudgeAgentPhishDebateThreePasses()`: configure `MockInferenceEngine.responses` with 3 entries, call `JudgeAgent`, assert `reasoning.count >= 3`. `testMessageRouterTimeout()`: set `timeoutMs: 100` and make `MockInferenceEngine.generate` delay 200 ms, assert the thrown error is `GemScanError.timeout`.

**Acceptance criteria:**
- [ ] `testTextAgentSafeMessage` asserts `verdict == .safe` and `confidence >= 0.9`
- [ ] `testOrchestratorEscalatesLowConfidenceToE4B` asserts `escalatedToE4B == true` and `modelTier == .e4b`
- [ ] `testJudgeAgentPhishDebateThreePasses` asserts `reasoning.count >= 3`
- [ ] `testMessageRouterTimeout` asserts `GemScanError.timeout` thrown
- [ ] All tests use `MockInferenceEngine` and `MockMCPClient` (no real model loading)

**Apple compliance (Spec 00 §11):**
- [ ] N/A — unit tests only; no device or network access

---

#### ✅ T-07-007 · MCP server XCTests

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P1 |
| **Spec ref** | §3.2 — MCP server tests |
| **Depends on** | T-07-004 |
| **Estimated effort** | M |
| **Files to create/modify** | `ios/App/GemmaKit/Tests/MCPServerTests.swift` |

**What to build:**
Implement `ios/App/GemmaKit/Tests/MCPServerTests.swift` using real MCP server instances (not mocks). `testContactsServerExcludesPII()`: call `ContactsServer.lookupContact(id:)` with a fixture contact, assert the returned JSON contains `isKnown: Bool` but does NOT contain `name`, `phoneNumber`, or `email` keys. `testPhoneReputationHighRiskTLD()`: call `PhoneReputationServer.checkNumber("+1-900-555-0199")` and assert `riskScore >= 0.7`. `testIPURLScoring()`: call `URLReputationServer.analyseURL("http://192.168.1.1/login")` and assert `riskScore >= 0.6`. `testAccessControlRejectsUnauthorisedServer()`: attempt cross-server MCP call (ContactsServer calling PhoneReputation endpoint) and assert `GemScanError.accessDenied` is thrown. `testGrammarViolation()`: call `GrammarServer.check("Congratulations you have won prize")` and assert `violationCount >= 2`.

**Acceptance criteria:**
- [ ] ContactsServer output verified to contain no PII fields
- [ ] High-risk TLD number scores ≥ 0.7
- [ ] IP URL scores ≥ 0.6
- [ ] Cross-server access control throws `GemScanError.accessDenied`
- [ ] Grammar violation count ≥ 2 for the test phrase
- [ ] All tests use real server instances (no `MockMCPClient`)

**Apple compliance (Spec 00 §11):**
- [ ] §11.2 — Privacy: ContactsServer PII exclusion verified by XCTest

---

#### ✅ T-07-008 · InferenceEngine XCTests

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P1 |
| **Spec ref** | §3.3 — InferenceEngine tests |
| **Depends on** | T-07-003 |
| **Estimated effort** | S |
| **Files to create/modify** | `ios/App/GemmaKit/Tests/InferenceEngineTests.swift` |

**What to build:**
Implement `ios/App/GemmaKit/Tests/InferenceEngineTests.swift`. `testRSSCheckRejectsOversizedModel()`: inject a `MockMemoryProvider` returning 512 MB available RAM, attempt to load the E4B model (requires 3,200 MB), assert `GemScanError.insufficientMemory` is thrown and the model is not loaded. `testThermalGuardDowngradesToE2B()`: inject a `MockThermalStateProvider` returning `.critical`, call `InferenceEngine.shared.bestAvailableTier()`, assert the returned tier is `.e2b` (not `.e4b`). Both tests must inject dependencies via initialiser parameters (no global state mutation) so they are safe to run in parallel.

**Acceptance criteria:**
- [ ] `testRSSCheckRejectsOversizedModel` asserts `GemScanError.insufficientMemory` thrown
- [ ] `testThermalGuardDowngradesToE2B` asserts returned tier is `.e2b`
- [ ] Both tests use injected mock providers — no global state mutation
- [ ] Tests run in under 1 second each (no real model loading)

**Apple compliance (Spec 00 §11):**
- [ ] N/A — unit tests with injected dependencies; no device-specific state

---

#### ✅ T-07-009 · Apple Platform ComplianceTests

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P1 |
| **Spec ref** | §9.2 — Apple platform compliance tests |
| **Depends on** | T-07-003, T-07-004 |
| **Estimated effort** | L |
| **Files to create/modify** | `ios/App/GemmaKit/Tests/ComplianceTests.swift` |

**What to build:**
Implement `ios/App/GemmaKit/Tests/ComplianceTests.swift` with all 9 tests from Spec 07 §9.2. `testCoreTypesAreActors()`: use Mirror reflection to assert `InferenceEngine`, `OrchestratorAgent`, `TextAgent`, `MetricsStore` are all `actor` types. `testE2BLoadStaysWithinRSSBudget()`: load E2B model, call `ProcessInfo.processInfo.physicalFootprint`, assert ≤ 2,100 MB. `testDistilBERTRSSUnder50MB()`: load DistilBERT, assert RSS delta ≤ 50 MB. `testContactsServerOutputContainsNoPII()` and `testPhoneReputationServerOutputContainsNoPII()`: assert output JSON lacks PII keys. `testInferenceEngineDoesNotLogRawPrompt()`: use `OSLogStore` capture helper to collect log entries during a `generate()` call, assert no entry contains the raw input string `"Congratulations you have won"`. `testInfoPlistHasRequiredUsageDescriptions()`: load `Info.plist` from the app bundle, assert `NSContactsUsageDescription`, `NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription` are all non-empty. `testATSDoesNotAllowArbitraryLoads()`: load `Info.plist`, assert `NSAppTransportSecurity.NSAllowsArbitraryLoads` is false or absent. `testGuardianKeychainAccessibility()`: covered via import from `GuardianKeyManagerTests`.

**Acceptance criteria:**
- [ ] All 9 tests implemented and passing
- [ ] `testInferenceEngineDoesNotLogRawPrompt` uses `OSLogStore` capture (not just checking source code)
- [ ] `testE2BLoadStaysWithinRSSBudget` asserts ≤ 2,100 MB RSS
- [ ] `testDistilBERTRSSUnder50MB` asserts delta ≤ 50 MB
- [ ] `testInfoPlistHasRequiredUsageDescriptions` checks all 3 keys
- [ ] `testATSDoesNotAllowArbitraryLoads` fails if `NSAllowsArbitraryLoads = true`

**Apple compliance (Spec 00 §11):**
- [ ] §11.1 — Actor isolation verified programmatically
- [ ] §11.2 — PII exclusion verified by two server tests
- [ ] §11.3 — Usage description strings verified against `Info.plist`
- [ ] §11.4 — ATS arbitrary loads verified absent
- [ ] §11.6 — Keychain accessibility verified

---

#### ✅ T-07-010 · GemmaPluginMock Vitest tests

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P1 |
| **Spec ref** | §2.2 — GemmaPluginMock tests |
| **Depends on** | T-07-001, T-07-004 |
| **Estimated effort** | M |
| **Files to create/modify** | `src/lib/gemma/__tests__/mock.test.ts`, `src/lib/mcp/__tests__/mock-client.test.ts` |

**What to build:**
Implement `src/lib/gemma/__tests__/mock.test.ts` with 5 tests using the GemmaPlugin mock from `src/test/setup.ts`. `isReady returns true`: assert `{ ready: true }`. `analyse returns default fixture for unknown taskId`: call `analyse('unknown-id', ...)` and assert result equals `goldenFixtures['default']`. `analyse returns correct verdict for known fixture ID`: call `analyse('scam-prize', ...)` and assert `result.verdict === 'scam'`. `downloadModels fires downloadProgress events`: call `downloadModels({ modelIds: ['distilbert'] })` and assert at least one `downloadProgress` event fired via listener. `analyse completes in < 1000ms`: measure elapsed time with `performance.now()`. Implement `src/lib/mcp/__tests__/mock-client.test.ts` asserting all tools return structured output with required fields and each call resolves within 50 ms.

**Acceptance criteria:**
- [ ] `isReady` test asserts `{ ready: true }`
- [ ] `analyse` with unknown ID returns `goldenFixtures['default']`
- [ ] `analyse` with `'scam-prize'` returns `verdict: 'scam'`
- [ ] `downloadModels` fires at least one `downloadProgress` event
- [ ] `analyse` mock completes in < 1,000 ms
- [ ] All MCP mock tools respond in < 50 ms

**Apple compliance (Spec 00 §11):**
- [ ] N/A — TypeScript unit tests only

---

#### ✅ T-07-011 · Zustand store Vitest tests

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P1 |
| **Spec ref** | §2.3 — Zustand store tests |
| **Depends on** | T-07-001 |
| **Estimated effort** | S |
| **Files to create/modify** | `src/lib/__tests__/store.test.ts` |

**What to build:**
Implement `src/lib/__tests__/store.test.ts` with 6 tests. `defaults to active screening mode`: create a fresh store and assert `screeningMode === 'active'`. `setGuardianMode updates state`: call `setGuardianMode(true)`, assert `guardianModeEnabled === true`. `setTrustedContact stores contactId`: call `setTrustedContact('contact-abc')`, assert `trustedContactId === 'contact-abc'`. `persist version:1 rehydrates state`: serialize store state with `version: 1`, rehydrate via `useStore.persist.rehydrate()`, assert state matches. `migrate() called on version mismatch`: set persisted state with `version: 0`, trigger rehydration, assert `migrate()` was called and `version` updated to `1`. `store reset via clearStorage()`: call `useStore.persist.clearStorage()`, assert store returns to initial defaults.

**Acceptance criteria:**
- [ ] All 6 tests pass with a fresh isolated store per test (use `beforeEach` to reset)
- [ ] `setGuardianMode` test verifies state update
- [ ] `setTrustedContact` test verifies contactId stored
- [ ] Persist version test verifies rehydration
- [ ] Migration test verifies `migrate()` called on version mismatch
- [ ] `clearStorage()` test verifies defaults restored

**Apple compliance (Spec 00 §11):**
- [ ] N/A — TypeScript unit tests only

---

#### ✅ T-07-012 · Playwright SMS analysis E2E

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P1 |
| **Spec ref** | §4.2 — Playwright SMS analysis |
| **Depends on** | T-07-002 |
| **Estimated effort** | S |
| **Files to create/modify** | `e2e/analyse-sms.spec.ts` |

**What to build:**
Implement `e2e/analyse-sms.spec.ts` with a single `test` block. Navigate to `/`. Locate the SMS textarea by `role: 'textbox'` and fill it with the fixture scam message: `"URGENT: Your bank account has been suspended. Click http://bit.ly/claimNow to verify immediately."`. Click the button with text "Analyse". Await the element with `role: 'heading'` containing the verdict text to appear (use `waitForSelector` with 10 s timeout). Assert that `document.activeElement` is the verdict heading (WCAG focus management). Query all `role: 'listitem'` elements in the reasoning section and assert `count >= 2`. Assert the heading has `aria-live="assertive"`.

**Acceptance criteria:**
- [ ] Fills textarea with scam SMS fixture and clicks "Analyse"
- [ ] Verdict heading appears within 10 s
- [ ] `document.activeElement === verdictHeading` (focus management verified)
- [ ] At least 2 reasoning list items visible
- [ ] Verdict heading has `aria-live="assertive"`

**Apple compliance (Spec 00 §11):**
- [ ] §11.7 — Accessibility: focus management and `aria-live` verified by Playwright

---

#### ✅ T-07-013 · Playwright accessibility E2E

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P1 |
| **Spec ref** | §4.4 — Playwright accessibility tests |
| **Depends on** | T-07-002 |
| **Estimated effort** | S |
| **Files to create/modify** | `e2e/accessibility.spec.ts` |

**What to build:**
Implement `e2e/accessibility.spec.ts`. Import `checkA11y` from `axe-playwright`. For each of the 6 routes (`/`, `/onboarding`, `/analyse?taskId=test-1`, `/guardian/setup`, `/guardian/invite?token=valid-token-12345`, `/settings`): navigate to the route, call `checkA11y(page, undefined, { runOnly: { type: 'tag', values: ['wcag2a', 'wcag2aa'] } })` and assert zero violations of impact `critical` or `serious`. On `/onboarding`, additionally assert all three `role="progressbar"` elements have `aria-valuenow`, `aria-valuemin`, and `aria-valuemax` attributes present. Run the accessibility test with Guardian mode enabled (set via `localStorage` mock) and assert `role="status"` element is visible on every route.

**Acceptance criteria:**
- [ ] Zero WCAG 2A + 2AA critical/serious violations on all 6 routes
- [ ] Progress bars on `/onboarding` have all 3 ARIA attributes
- [ ] `role="status"` (GuardianStatusBar) visible on all routes when Guardian enabled
- [ ] Tests run in both chromium and Mobile Safari projects

**Apple compliance (Spec 00 §11):**
- [ ] §11.7 — Accessibility: axe-core zero-violation gate on all routes

---

#### ✅ T-07-014 · XCUITest cold-start + SMS filter

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P1 |
| **Spec ref** | §5.1 — XCUITest UI automation |
| **Depends on** | T-07-005 |
| **Estimated effort** | M |
| **Files to create/modify** | `ios/App/Tests/UITests/ColdStartTest.swift` |

**What to build:**
Implement `ios/App/Tests/UITests/ColdStartTest.swift` as `XCTestCase`. `testColdStartLoadsHomeScreen()`: launch the app, wait for element with `accessibilityIdentifier: "homeHeading"` to exist within 5 s using `XCTNSPredicateExpectation`. `testOnboardingFlowCompletesModelDownload()`: launch into the onboarding screen, assert at least one `progressBar` element exists within 3 s. `testSMSFilterExtensionActivation()`: use `XCUIApplication(bundleIdentifier: "com.apple.Preferences")` to navigate to Settings → Messages → Unknown & Spam, assert the "GemScan" switch element exists and its value is "1" (enabled). `testShareSheetFlowFromSafari()`: use `XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")`, navigate to a test URL, tap Share, assert "Analyse with GemScan" action sheet item exists.

**Acceptance criteria:**
- [ ] `testColdStartLoadsHomeScreen` passes within 5 s timeout
- [ ] `testOnboardingFlowCompletesModelDownload` finds progress bar within 3 s
- [ ] `testSMSFilterExtensionActivation` finds GemScan switch in Settings → Messages
- [ ] `testShareSheetFlowFromSafari` finds "Analyse with GemScan" in Share Sheet

**Apple compliance (Spec 00 §11):**
- [ ] §11.5 — HIG: Share Sheet integration verified
- [ ] §11.8 — SMS filter extension activation verified in Settings

---

#### ✅ T-07-015 · Benchmark tests

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P2 |
| **Spec ref** | §6 — Benchmark tests |
| **Depends on** | T-07-005 |
| **Estimated effort** | M |
| **Files to create/modify** | `ios/App/GemmaKit/Tests/BenchmarkTests.swift`, `ios/App/GemmaKit/Tests/AdversarialTests.swift` |

**What to build:**
Implement `ios/App/GemmaKit/Tests/BenchmarkTests.swift` using `measure(metrics: [XCTClockMetric()])`. `testE2BFirstTokenLatency()`: run 5 iterations of `InferenceEngine.shared.generate(prompt:onToken:)` capturing time-to-first-token; the `XCTClockMetric` average must be ≤ 400 ms (set `XCTMeasureOptions.invocationOptions = .manuallyStart`). `testDistilBERTClassificationLatency()`: run 5 iterations of DistilBERT classification, assert average ≤ 30 ms. Implement `ios/App/GemmaKit/Tests/AdversarialTests.swift` with 5 fixture adversarial samples (known evasion patterns: Unicode homoglyphs, zero-width characters, base64-encoded URLs, excessive whitespace obfuscation, mixed-script text). Run each through `TextAgent`, collect verdicts, assert `accuracy >= 0.80` (≥ 4 of 5 correctly classified as suspicious or scam).

**Acceptance criteria:**
- [ ] E2B first-token latency ≤ 400 ms average over 5 iterations
- [ ] DistilBERT classification ≤ 30 ms average over 5 iterations
- [ ] Adversarial test accuracy ≥ 80% (≥ 4/5 samples correctly flagged)
- [ ] Benchmark tests are in `BenchmarkTests.xctestplan` with `maximumTestRepetitions: 5`

**Apple compliance (Spec 00 §11):**
- [ ] N/A — performance benchmarks; no user-facing code

---

#### ✅ T-07-016 · CI coverage enforcement

| Field | Value |
|---|---|
| **Type** | BUILD |
| **Priority** | P1 |
| **Spec ref** | §2.1 — Coverage enforcement |
| **Depends on** | T-07-001 |
| **Estimated effort** | S |
| **Files to create/modify** | `.github/workflows/ci.yml`, `README.md` |

**What to build:**
In the `typescript` job of `.github/workflows/ci.yml`, add a step that runs `npm run test:unit -- --coverage` and fails the job if `coverage/coverage-summary.json` reports `total.lines.pct < 80`. Add a Codecov upload step using `codecov/codecov-action@v4` referencing the `CODECOV_TOKEN` secret and pointing to `coverage/lcov.info`. Add a `jq` assertion step: `jq -e '.total.lines.pct >= 80' coverage/coverage-summary.json`. Add the Codecov coverage badge to `README.md` using the standard badge URL format for the `main` branch.

**Acceptance criteria:**
- [ ] `npm run test:unit -- --coverage` produces `coverage/coverage-summary.json`
- [ ] `jq` assertion step fails CI when lines coverage < 80%
- [ ] Codecov upload action configured with `CODECOV_TOKEN` secret
- [ ] Coverage badge added to `README.md`

**Apple compliance (Spec 00 §11):**
- [ ] N/A — CI configuration task

---

#### ✅ T-07-017 · Testing guide

| Field | Value |
|---|---|
| **Type** | DOCUMENT |
| **Priority** | P2 |
| **Spec ref** | §8 — Testing documentation |
| **Depends on** | T-07-001, T-07-002, T-07-003, T-07-005, T-07-015 |
| **Estimated effort** | S |
| **Files to create/modify** | `docs/testing.md` |

**What to build:**
Create `docs/testing.md` with six sections. (1) Running each test layer: exact commands for `npm run test:unit`, `npm run test:unit -- --coverage`, `npx playwright test`, `npx playwright test --ui`, and `xcodebuild test -scheme GemmaKit -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=17.4'`. (2) Adding a golden fixture: show how to add a new entry to `goldenFixtures` in `golden.ts`. (3) Using `MockInferenceEngine.responses` for multi-pass tests such as `JudgeAgent` PhishDebate: code example showing `responses = ["pass1", "pass2", "pass3"]`. (4) Running ComplianceTests: note that they require a physical device or a simulator with Keychain access enabled. (5) Running benchmarks locally using `BenchmarkTests.xctestplan`. (6) The `LogCapture` helper: how to instantiate `OSLogStore`, filter by subsystem, and read entries in an XCTest.

**Acceptance criteria:**
- [ ] All 5 test-layer commands documented with correct flags
- [ ] Golden fixture addition example is accurate
- [ ] `MockInferenceEngine.responses` example is runnable as-is
- [ ] ComplianceTests simulator caveat documented
- [ ] `LogCapture` / `OSLogStore` usage documented

**Apple compliance (Spec 00 §11):**
- [ ] N/A — documentation task

---

#### ✅ T-07-018 · Full test suite green

| Field | Value |
|---|---|
| **Type** | VALIDATE |
| **Priority** | P0 |
| **Spec ref** | §9 — Full suite validation |
| **Depends on** | T-07-006, T-07-007, T-07-008, T-07-009, T-07-010, T-07-011, T-07-012, T-07-013, T-07-014, T-07-015, T-07-016 |
| **Estimated effort** | M |
| **Files to create/modify** | None (validation task) |

**What to build:**
Execute the complete test suite across all three layers and verify every gate passes. Run `npm run test:unit -- --coverage` and confirm `total.lines.pct >= 80` in `coverage/coverage-summary.json`. Run `npx playwright test` on both chromium and Mobile Safari and confirm zero failures. Run `xcodebuild test -scheme GemmaKit` on the iPhone 15 Pro iOS 17.4 simulator and confirm all XCTests green with zero `ComplianceTests` failures. On a physical iPhone 15 Pro device, run the manual Instruments checklist from Spec 07 §9.3: Leaks instrument (zero leaks during a full analysis flow), Allocations instrument (RSS ≤ 2,100 MB during E2B inference), Network instrument (zero cleartext HTTP requests). Record pass/fail results for each item in the release PR description.

**Acceptance criteria:**
- [ ] Vitest coverage ≥ 80% lines on `src/lib/`
- [ ] All XCTests green on iPhone 15 Pro iOS 17.4 simulator
- [ ] All Playwright tests green on chromium and Mobile Safari
- [ ] Zero `ComplianceTests` failures
- [ ] Instruments checklist: Leaks = 0, RSS ≤ 2,100 MB, zero cleartext HTTP
- [ ] Results recorded in the release PR description

**Apple compliance (Spec 00 §11):**
- [ ] §11.1–§11.8 — All compliance tests pass (ComplianceTests.swift all green)
- [ ] §11.9 — Instruments manual checklist completed on physical device

---

#### ⬜ T-07-019 · User testing protocol execution

| Field | Value |
|---|---|
| **Type** | VALIDATE |
| **Priority** | P2 |
| **Spec ref** | §7 — User Testing Protocol (Days 11–12, 5–10 participants) |
| **Depends on** | T-07-018 |
| **Estimated effort** | XL (> 6 hr) |
| **Files to create/modify** | `docs/user-testing-report.md`, `docs/user-testing-scenarios.md` |

**What to build:**
Execute the user testing protocol from Spec 07 §7 with 5–10 participants. Create `docs/user-testing-scenarios.md` documenting the five test scenarios: (1) receive a scam SMS alert and identify the verdict; (2) receive a safe message and confirm no false alarm; (3) set up Guardian Mode with a trusted contact in ≤ 5 taps; (4) share a suspicious URL from Safari via Share Sheet; (5) change the app language in Settings. For each scenario, document the expected outcome and the observation checklist. After testing, create `docs/user-testing-report.md` documenting: task completion rate (target: ≥ 90%), time-to-verdict comprehension (target: ≤ 5 seconds), user understanding score (target: ≥ 4/5), System Usability Scale score (target: ≥ 68), VoiceOver completion rate (target: 100% for at least 2 participants). Record all participant observations, failure points, and recommended UI fixes.

**Acceptance criteria:**
- [ ] 5–10 participants tested (documented by participant ID, not name)
- [ ] All five scenarios executed and results recorded
- [ ] Task completion rate ≥ 90% (or action items documented for failures)
- [ ] SUS score ≥ 68 (or UX improvement tasks created for next cycle)
- [ ] VoiceOver scenario completed by at least 2 participants

**Apple compliance (Spec 00 §11):**
- [ ] §11.5 — HIG: user testing validates real-world accessibility and usability

---

#### ⬜ T-07-020 · FPR dataset curation and benchmarking

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P1 |
| **Spec ref** | §6.3 — False Positive Rate Monitoring |
| **Depends on** | T-07-015 |
| **Estimated effort** | L (3–6 hr) |
| **Files to create/modify** | `tests/fixtures/legitimate-messages.json`, `scripts/run-fpr-benchmark.sh`, `ios/App/GemmaKit/Tests/FPRBenchmarkTests.swift` |

**What to build:**
Create `tests/fixtures/legitimate-messages.json` with 300 curated legitimate message samples covering: bank transaction confirmations, delivery tracking updates, appointment reminders, family/friend messages, promotional emails from known brands, government notifications, and school/work communications. Each sample includes `text`, `category` (e.g., `"bank_legitimate"`, `"delivery_tracking"`), and `expected_verdict: "safe"`. Create `ios/App/GemmaKit/Tests/FPRBenchmarkTests.swift` that loads this fixture file, classifies each message via `TextAgent` with `MockInferenceEngine`, and computes the false positive rate (messages classified as `suspicious` or `scam` / total). Assert FPR < 5%. If FPR > 8%, fail the test with a regression warning. Create `scripts/run-fpr-benchmark.sh` that runs the benchmark and writes results to `benchmark_results.json` with fields: `fpr`, `total_samples`, `false_positives`, `timestamp`.

**Acceptance criteria:**
- [ ] `legitimate-messages.json` contains exactly 300 samples across ≥ 7 categories
- [ ] FPR benchmark test runs and produces a numeric FPR value
- [ ] FPR < 5% passes; FPR > 8% fails the test
- [ ] `benchmark_results.json` is written with all four fields
- [ ] Dataset does not contain any real PII (all messages are synthetic or anonymized)

**Apple compliance (Spec 00 §11):**
- [ ] §11.3 — Dataset contains no real PII; all samples are synthetic or thoroughly anonymized

---

#### ⬜ T-07-021 · Throughput benchmark (tokens/second)

| Field | Value |
|---|---|
| **Type** | TEST |
| **Priority** | P2 |
| **Spec ref** | §6.1 — Inference Latency Benchmarks (tokens/second metric) |
| **Depends on** | T-07-015 |
| **Estimated effort** | M (1–3 hr) |
| **Files to create/modify** | `ios/App/GemmaKit/Tests/ThroughputBenchmarkTests.swift` |

**What to build:**
Create `ios/App/GemmaKit/Tests/ThroughputBenchmarkTests.swift` as an `XCTestCase` subclass. `testE2BThroughput()`: load the E2B model, run `InferenceEngine.shared.generate()` with a standardized 50-token prompt, count output tokens and measure wall-clock time, compute `tokensPerSecond = tokenCount / elapsedSeconds`. Assert `tokensPerSecond >= 15.0` (E2B target from Spec 02 §1). `testE4BThroughput()`: same pattern with E4B model; assert `tokensPerSecond >= 8.0` (E4B target). `testDistilBERTLatency()`: run `SMSTriage.shared.classify()` 100 times, compute p95 latency, assert `p95 <= 100` ms (DistilBERT target from Spec 02 §1). Use `XCTSkipIf` to skip E4B test if model is not downloaded. Write results to `benchmark_results.json` for the weekly regression gate (T-09-005).

**Acceptance criteria:**
- [ ] E2B throughput ≥ 15 tokens/second on iPhone 15 Pro
- [ ] E4B throughput ≥ 8 tokens/second on iPhone 15 Pro (or skipped if model absent)
- [ ] DistilBERT p95 latency ≤ 100 ms
- [ ] Results appended to `benchmark_results.json`

**Apple compliance (Spec 00 §11):**
- [ ] §11.2 — Performance targets from Spec 02 §1 validated on real hardware
