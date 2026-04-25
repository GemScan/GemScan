# Testing

How to run all test layers in GemScan.

---

## Overview

GemScan uses four test layers:

| Layer | Framework | Command | Target |
|-------|-----------|---------|--------|
| Unit + Component | Vitest | `npm run test:unit` | `src/lib/`, `src/components/` |
| E2E | Playwright | `npm run test:e2e` | Full app in browser |
| Swift unit | XCTest | `xcodebuild test` | GemmaKit package |
| Swift UI | XCUITest | `xcodebuild test` | iOS app UI |

---

## Unit and Component Tests (Vitest)

```bash
# Run all unit and component tests
npm run test:unit

# Watch mode (re-runs on file changes)
npm run test:watch

# With coverage report
npm run test:coverage
```

### Coverage Requirements

- **`src/lib/`** — minimum 80% line coverage
- **`src/components/`** — minimum 60% line coverage
- **`src/hooks/`** — minimum 70% line coverage

Coverage is enforced in CI. The configuration lives in `vitest.config.mts`.

### File Naming Convention

```
src/lib/agents/textAgent.ts        # Source
src/lib/agents/textAgent.test.ts   # Unit test (co-located)
src/components/ScanCard.tsx         # Component
src/components/ScanCard.test.tsx    # Component test
```

---

## E2E Tests (Playwright)

```bash
# Build first — Playwright tests run against the production build
npm run build

# Run E2E tests
npm run test:e2e

# Run with UI mode (interactive)
npx playwright test --ui

# Run a specific test file
npx playwright test e2e/scan-flow.spec.ts

# Run in headed mode (visible browser)
npx playwright test --headed
```

### Browser Targets

Configured in `playwright.config.ts`:

- **Chromium** — desktop web testing
- **WebKit** — Safari/iOS approximation

### Writing E2E Tests

```typescript
import { test, expect } from '@playwright/test';

test('scan page displays verdict after analysis', async ({ page }) => {
  await page.goto('/scan');
  await page.fill('[data-testid="scan-input"]', 'Check this message');
  await page.click('[data-testid="scan-button"]');
  await expect(page.locator('[data-testid="verdict"]')).toBeVisible();
});
```

Always use `data-testid` attributes for selectors.

---

## Swift Tests (XCTest)

### Unit Tests

```bash
# Run GemmaKit unit tests
xcodebuild test \
  -scheme GemmaKitTests \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -resultBundlePath TestResults.xcresult
```

### UI Tests

```bash
# Run XCUITest suite
xcodebuild test \
  -scheme GemScanUITests \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -resultBundlePath UITestResults.xcresult
```

### What Swift Tests Cover

- **InferenceEngine** — model loading, token generation, confidence scoring
- **Agent actors** — task routing, result aggregation, escalation logic
- **MCP servers** — tool invocation, response parsing
- **Extensions** — SMS filter classification, call directory formatting
- **Bridge** — Capacitor plugin serialization round-trip

---

## Benchmark Tests

Benchmark tests run weekly via CI (not on every PR):

```bash
# Manual benchmark run
xcodebuild test \
  -scheme GemScanBenchmarks \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

Benchmarks measure:
- Inference latency (E2B, E4B, DistilBERT)
- Agent pipeline end-to-end time
- Memory footprint per extension

---

## Mock Infrastructure

### MockInferenceEngine

Stubs model loading and token generation. Returns deterministic results based on input patterns.

```swift
let mock = MockInferenceEngine()
mock.stub(input: "win a prize", verdict: .scam, confidence: 0.95)
```

### MockMCPClient

Replaces all 10 MCP servers with in-memory stubs.

```swift
let client = MockMCPClient()
client.stubURLReputation(domain: "evil.com", score: 0.1)
```

### MockMessageRouter

Simulates SMS Filter extension message delivery without the system framework.

```swift
let router = MockMessageRouter()
router.deliver(message: "You won $1000!", sender: "+1555000111")
```

### TypeScript Mocks

Web mock mode (`NEXT_PUBLIC_IS_MOCK=true`) activates mocks in `src/lib/mocks/`:

- `mockGemmaPlugin.ts` — stubs the Capacitor native bridge
- `mockScanService.ts` — returns fixture-based scan results
- `mockHistoryStore.ts` — in-memory history

---

## Golden Fixtures

Deterministic test fixtures live in `tests/fixtures/`:

```
tests/fixtures/
├── scam-sms.json          # Known scam message samples
├── safe-sms.json          # Benign message samples
├── phishing-urls.json     # Phishing URL samples
├── safe-urls.json         # Legitimate URL samples
├── scan-results.json      # Expected AgentResult shapes
└── model-responses.json   # Stubbed inference outputs
```

Golden fixtures ensure tests are reproducible and independent of model weights.

---

## How to Add New Tests

### Unit Test Checklist

- [ ] Create test file co-located with source: `myModule.test.ts`
- [ ] Import from `@testing-library/react` for component tests
- [ ] Use `describe` / `it` blocks with clear descriptions
- [ ] Mock external dependencies (Capacitor plugins, fetch)
- [ ] Assert both happy path and error cases
- [ ] Run `npm run test:coverage` and verify thresholds

### E2E Test Checklist

- [ ] Add test file in `e2e/` directory
- [ ] Use `data-testid` selectors (never CSS classes)
- [ ] Test user-visible behavior, not implementation details
- [ ] Keep tests independent (no shared state between tests)
- [ ] Run locally: `npm run build && npm run test:e2e`

### Swift Test Checklist

- [ ] Add test class in the appropriate test target
- [ ] Use `MockInferenceEngine` or `MockMCPClient` for isolation
- [ ] Test actor methods with `await`
- [ ] Verify both success and failure paths
- [ ] Run: `xcodebuild test -scheme GemmaKitTests -destination '...'`

---

## CI Integration

All test layers run in GitHub Actions:

| Workflow | Trigger | Tests |
|----------|---------|-------|
| `ci.yml` | Every push/PR | typecheck, lint, unit, e2e |
| `swift-tests.yml` | Every push/PR | XCTest, XCUITest |
| `benchmarks.yml` | Weekly (cron) | Performance benchmarks |

A PR cannot merge unless both `ci` and `swift-tests` pass.
