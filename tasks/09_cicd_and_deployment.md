# Tasks — CI/CD & Deployment

> **Spec:** `specs/09_cicd_and_deployment.md` | **Milestone:** M9 — CI/CD & Deployment | **Depends on:** M8

## Milestone Summary
Establishes the complete CI/CD pipeline and App Store deployment infrastructure for GemScan. Covers four GitHub Actions workflows (`ci.yml`, `e2e.yml`, `release.yml`, `benchmark.yml`), SwiftLint and ESLint enforcement, model manifest signature verification, the `PrivacyInfo.xcprivacy` manifest required for App Store submission, `Info.plist` usage description keys, branch protection configuration, and all supporting scripts and documentation.

## Prerequisites
- M0–M8 all implementation and test milestones complete
- GitHub repository with Actions enabled
- Apple Developer account with Distribution certificate and provisioning profile
- App Store Connect API key available
- Codecov account configured for the repository

## Progress Tracker
| Status | Count |
|--------|-------|
| ✅ Done | 0 |
| 🔄 In progress | 0 |
| ⬜ Not started | 17 |

---
## Tasks

#### ⬜ T-09-001 · `ci.yml` GitHub Actions workflow

| Field | Value |
|---|---|
| **Type** | BUILD |
| **Priority** | P0 |
| **Spec ref** | §2 — ci.yml |
| **Depends on** | None |
| **Estimated effort** | M |
| **Files to create/modify** | `.github/workflows/ci.yml` |

**What to build:**
Create `.github/workflows/ci.yml`. Set `on: [push, pull_request]` and `concurrency: { group: "ci-${{ github.ref }}", cancel-in-progress: true }`. Define 4 jobs. Job `typescript`: runs on `ubuntu-latest`; steps: `actions/checkout`, `actions/setup-node@v4` with `node-version: 20`, `npm ci`, `npx tsc --noEmit`, `npx eslint src/ --max-warnings 0`, `npm run test:unit -- --coverage`, `jq -e '.total.lines.pct >= 80' coverage/coverage-summary.json`, `codecov/codecov-action@v4` with `CODECOV_TOKEN` secret. Job `nextjs-build`: `npm ci && npm run build`, then `test -f out/index.html`. Job `pii-scan`: `grep -r --include="*.swift" --include="*.ts" --include="*.tsx" -l "messageBody\|phoneNumber\|contactName\|emailAddress\|senderName\|messageContent" ios/App/GemmaKit/Sources src/lib && exit 1 || exit 0`. Job `swift-unit`: runs on `macos-14`, Xcode 15.3; `xcodebuild test -scheme GemmaKit -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=17.4' -resultBundlePath TestResults.xcresult`; upload `TestResults.xcresult` as artifact.

**Acceptance criteria:**
- [ ] 4 jobs defined: `typescript`, `nextjs-build`, `pii-scan`, `swift-unit`
- [ ] TypeScript job: type-check, lint, unit tests, coverage ≥ 80%, Codecov upload
- [ ] `nextjs-build` job verifies `out/index.html` exists
- [ ] `pii-scan` job fails if any PII keyword found in Swift/TS source files
- [ ] `swift-unit` job runs on `macos-14` with Xcode 15.3 and iPhone 15 Pro iOS 17.4 simulator
- [ ] `concurrency` with `cancel-in-progress: true` configured

**Apple compliance (Spec 00 §11):**
- [ ] §11.2 — Privacy: PII scan gate enforced in CI on every push

---

#### ⬜ T-09-002 · `e2e.yml` GitHub Actions workflow

| Field | Value |
|---|---|
| **Type** | BUILD |
| **Priority** | P0 |
| **Spec ref** | §3 — e2e.yml |
| **Depends on** | T-09-001 |
| **Estimated effort** | M |
| **Files to create/modify** | `.github/workflows/e2e.yml` |

**What to build:**
Create `.github/workflows/e2e.yml`. Set `on: [push, pull_request]`. Define 2 jobs. Job `playwright`: runs on `ubuntu-latest`; steps: checkout, `actions/setup-node@v4`, `npm ci`, `npx playwright install --with-deps chromium webkit`, `NEXT_PUBLIC_IS_MOCK=true npx playwright test`, upload `playwright-report/` as artifact on failure. Job `xcuitest-simulator`: runs on `macos-14`; steps: checkout, `actions/setup-node@v4`, `npm ci`, `npm run build`, `npx cap sync ios`, `xcodebuild test -scheme GemScan -testPlan GemScanUITests -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=17.4'`; upload `UITestResults.xcresult` as artifact on failure.

**Acceptance criteria:**
- [ ] `playwright` job installs chromium and webkit, runs tests with `NEXT_PUBLIC_IS_MOCK=true`
- [ ] `playwright-report/` artifact uploaded on failure
- [ ] `xcuitest-simulator` job runs `npm run build` then `npx cap sync ios` before XCUITest
- [ ] `GemScanUITests.xctestplan` referenced in the xcodebuild command
- [ ] `UITestResults.xcresult` artifact uploaded on failure

**Apple compliance (Spec 00 §11):**
- [ ] §11.7 — Accessibility: Playwright axe-core tests run in CI on every push
- [ ] §11.8 — XCUITest extension activation test runs in CI

---

#### ⬜ T-09-003 · `release.yml` GitHub Actions workflow

| Field | Value |
|---|---|
| **Type** | BUILD |
| **Priority** | P0 |
| **Spec ref** | §4 — release.yml |
| **Depends on** | T-09-001, T-09-002, T-09-006 |
| **Estimated effort** | L |
| **Files to create/modify** | `.github/workflows/release.yml` |

**What to build:**
Create `.github/workflows/release.yml`. Set `on: { push: { tags: ['v*'] } }`. Run on `macos-14`. Steps in order: checkout with `fetch-depth: 0`; `actions/setup-node@v4`; `npm ci`; run `python3 scripts/verify_manifest_signature.py` (exits 1 on failure); `npm run build` with `NEXT_PUBLIC_IS_MOCK=false`; `npx cap sync ios`; decode and install the `PROVISIONING_PROFILE_BASE64` secret to `~/Library/MobileDevice/Provisioning Profiles/`; decode and import the `SIGNING_CERTIFICATE_P12_BASE64` secret + `SIGNING_CERTIFICATE_PASSWORD` to keychain; `xcodebuild archive -scheme GemScan -archivePath GemScan.xcarchive`; `xcodebuild -exportArchive -archivePath GemScan.xcarchive -exportPath GemScan.ipa -exportOptionsPlist ExportOptions.plist`; `xcrun altool --upload-app -f GemScan.ipa/GemScan.ipa -t ios --apiKey ${{ secrets.APP_STORE_CONNECT_API_KEY_ID }} --apiIssuer ${{ secrets.APP_STORE_CONNECT_ISSUER_ID }}`; post a comment to the release noting the TestFlight group "GemScan Internal".

**Acceptance criteria:**
- [ ] Triggered only on `v*` tags
- [ ] `verify_manifest_signature.py` runs before any build steps and blocks on failure
- [ ] Provisioning profile and signing certificate installed from secrets
- [ ] `xcodebuild archive` and `exportArchive` steps both present
- [ ] `xcrun altool` uploads to TestFlight with App Store Connect API key
- [ ] Distributes to "GemScan Internal" TestFlight group

**Apple compliance (Spec 00 §11):**
- [ ] §11.4 — ATS: `NEXT_PUBLIC_IS_MOCK=false` ensures production endpoints used
- [ ] §11.9 — App Store: `altool` upload step present for TestFlight distribution

---

#### ⬜ T-09-004 · SwiftLint CI integration

| Field | Value |
|---|---|
| **Type** | BUILD |
| **Priority** | P0 |
| **Spec ref** | §9.1 — SwiftLint CI |
| **Depends on** | T-09-001 |
| **Estimated effort** | S |
| **Files to create/modify** | `.github/workflows/ci.yml` |

**What to build:**
Add three steps to the `swift-unit` job in `ci.yml` (before the xcodebuild test step). Step 1 — SwiftLint: `brew install swiftlint && swiftlint lint --strict --reporter github-actions-logging ios/App/GemmaKit/Sources/`. This emits GitHub-native annotations for violations. Step 2 — Xcode Analyze: `xcodebuild analyze -scheme GemmaKit -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=17.4' 2>&1 | grep -E "warning:|error:" | tee analyze.log && ! grep -q "error:" analyze.log`. Step 3 — Strict Concurrency: `xcodebuild build -scheme GemmaKit -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=17.4' SWIFT_STRICT_CONCURRENCY=complete 2>&1 | grep -E "error:" && exit 1 || exit 0`. All three steps must pass for the `swift-unit` job to succeed.

**Acceptance criteria:**
- [ ] SwiftLint runs with `--strict` and `--reporter github-actions-logging`
- [ ] SwiftLint covers `ios/App/GemmaKit/Sources/` directory
- [ ] `xcodebuild analyze` step fails job on any `error:` output
- [ ] `SWIFT_STRICT_CONCURRENCY=complete` build step fails job on concurrency errors
- [ ] All three steps run before `xcodebuild test`

**Apple compliance (Spec 00 §11):**
- [ ] §11.1 — Actor isolation: `SWIFT_STRICT_CONCURRENCY=complete` enforced in CI

---

#### ⬜ T-09-005 · `benchmark.yml` weekly workflow

| Field | Value |
|---|---|
| **Type** | BUILD |
| **Priority** | P1 |
| **Spec ref** | §9 — benchmark.yml |
| **Depends on** | T-09-001 |
| **Estimated effort** | S |
| **Files to create/modify** | `.github/workflows/benchmark.yml` |

**What to build:**
Create `.github/workflows/benchmark.yml`. Set `on: { schedule: [{ cron: '0 4 * * 1' }] }` for weekly Monday 4:00 AM UTC runs. Runs on `macos-14`. Steps: checkout; `xcodebuild test -scheme GemmaKitBenchmarks -testPlan BenchmarkTests -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=17.4' -resultBundlePath BenchmarkResults.xcresult`; `xcrun xcresulttool get --format json --path BenchmarkResults.xcresult > benchmark_results.json`; `node scripts/check-benchmark-regression.js`; upload `benchmark_results.json` as artifact named `benchmark-results-${{ github.run_id }}`. The `node` regression-check step exits 1 if any metric exceeds its target by more than 20% or if false positive rate exceeds 8%.

**Acceptance criteria:**
- [ ] Cron schedule `0 4 * * 1` configured
- [ ] `GemmaKitBenchmarks` scheme and `BenchmarkTests.xctestplan` referenced
- [ ] `xcresulttool` extracts results to `benchmark_results.json`
- [ ] `check-benchmark-regression.js` runs and blocks on regression
- [ ] Artifact uploaded with run ID in the name

**Apple compliance (Spec 00 §11):**
- [ ] N/A — benchmark automation; no production code paths

---

#### ⬜ T-09-006 · Model manifest + SHA-256 verification script

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P1 |
| **Spec ref** | §5.1 — Model manifest |
| **Depends on** | None |
| **Estimated effort** | M |
| **Files to create/modify** | `manifest.json`, `scripts/verify_manifest_signature.py`, `scripts/manifest_pubkey.pem` |

**What to build:**
Create `manifest.json` at the repository root with a top-level `models` array containing 5 entries. Each entry has: `id` (one of `distilbert`, `e2b`, `e4b`, `whisper-small-mlx`, `audioseal-detector-mlx`), `version` string, `sha256` (64-char hex), `sizeBytes` integer, `downloadUrl` string, and `downloadPolicy` (one of `"onboarding"`, `"on_demand"`). Also include a top-level `signature` field (base64-encoded ed25519 signature of the canonical JSON of the `models` array). Create `scripts/manifest_pubkey.pem` with a placeholder ed25519 public key. Create `scripts/verify_manifest_signature.py`: load `manifest.json`, extract `signature` and `models`; re-serialise `models` to canonical JSON (`json.dumps(models, sort_keys=True, separators=(',', ':'))`); load the PEM public key via `cryptography` library; call `public_key.verify(signature_bytes, canonical_json_bytes)`; exit 1 with an error message on `InvalidSignature`, exit 0 on success.

**Acceptance criteria:**
- [ ] `manifest.json` has 5 model entries with all required fields including `downloadPolicy`
- [ ] `verify_manifest_signature.py` uses `cryptography` library ed25519 verify
- [ ] Script exits 1 on invalid signature or missing file
- [ ] Script exits 0 when signature is valid
- [ ] `scripts/manifest_pubkey.pem` present (placeholder key for development)

**Apple compliance (Spec 00 §11):**
- [ ] §11.9 — App Store: model manifest signature verified before every release build

---

#### ⬜ T-09-007 · Benchmark regression check script

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P1 |
| **Spec ref** | §6 — Benchmark regression |
| **Depends on** | None |
| **Estimated effort** | S |
| **Files to create/modify** | `scripts/check-benchmark-regression.js` |

**What to build:**
Create `scripts/check-benchmark-regression.js` as a Node.js script. Read `benchmark_results.json` from the current working directory via `fs.readFileSync`. Parse the `xcresulttool` JSON format to extract four metrics: `e2bFirstTokenLatencyMs` (target ≤ 400 ms), `e4bFirstTokenLatencyMs` (target ≤ 800 ms), `distilbertLatencyMs` (target ≤ 30 ms), `falsePositiveRate` (target ≤ 0.05). For each latency metric, compare the measured value against `target * 1.2`; if exceeded, print an error message to `stderr` and call `process.exit(1)`. For `falsePositiveRate`, compare against `0.08`; if exceeded, print error and exit 1. If all metrics pass, print a summary table to `stdout` and exit 0.

**Acceptance criteria:**
- [ ] Reads `benchmark_results.json` from CWD
- [ ] Checks E2B latency ≤ 480 ms (400 × 1.2)
- [ ] Checks E4B latency ≤ 960 ms (800 × 1.2)
- [ ] Checks DistilBERT latency ≤ 36 ms (30 × 1.2)
- [ ] Checks false positive rate ≤ 0.08
- [ ] Exits 1 on any failure, 0 on all pass
- [ ] Prints readable summary on success

**Apple compliance (Spec 00 §11):**
- [ ] N/A — CI script only

---

#### ⬜ T-09-008 · `PrivacyInfo.xcprivacy` manifest

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P0 |
| **Spec ref** | §6 — PrivacyInfo.xcprivacy |
| **Depends on** | None |
| **Estimated effort** | S |
| **Files to create/modify** | `ios/App/App/PrivacyInfo.xcprivacy` |

**What to build:**
Create `ios/App/App/PrivacyInfo.xcprivacy` as an XML property list file with the exact keys required by Apple for App Store submission. Set `NSPrivacyTracking` to `false` (boolean). Set `NSPrivacyCollectedDataTypes` to an empty array. Set `NSPrivacyAccessedAPITypes` to an array of three dictionaries: (1) `{ NSPrivacyAccessedAPIType: "NSPrivacyAccessedAPICategoryContacts", NSPrivacyAccessedAPITypeReasons: ["C617.1"] }`; (2) `{ NSPrivacyAccessedAPIType: "NSPrivacyAccessedAPICategoryUserDefaults", NSPrivacyAccessedAPITypeReasons: ["CA92.1"] }`; (3) `{ NSPrivacyAccessedAPIType: "NSPrivacyAccessedAPICategoryFileTimestamp", NSPrivacyAccessedAPITypeReasons: ["C617.1"] }`. Add this file to the `App` Xcode target's `Copy Bundle Resources` build phase.

**Acceptance criteria:**
- [ ] `NSPrivacyTracking` set to `false`
- [ ] `NSPrivacyCollectedDataTypes` is an empty array
- [ ] Three `NSPrivacyAccessedAPITypes` entries present with correct reason codes
- [ ] File added to Xcode project and included in `Copy Bundle Resources`
- [ ] `xcodebuild archive` succeeds without "missing privacy manifest" warning

**Apple compliance (Spec 00 §11):**
- [ ] §11.9 — App Store: `PrivacyInfo.xcprivacy` required for App Store submission (mandatory from Spring 2024)

---

#### ⬜ T-09-009 · `Info.plist` required keys

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P0 |
| **Spec ref** | §6 — Info.plist keys |
| **Depends on** | None |
| **Estimated effort** | S |
| **Files to create/modify** | `ios/App/App/Info.plist` |

**What to build:**
Open `ios/App/App/Info.plist` and ensure the following keys are present with the exact string values specified. `NSContactsUsageDescription`: `"GemScan checks if the sender is in your contacts to help detect scams."`. `NSMicrophoneUsageDescription`: `"GemScan analyses voice calls you choose to share."`. `NSSpeechRecognitionUsageDescription`: `"GemScan transcribes audio on-device to detect voice scams."`. `ITSAppUsesNonExemptEncryption`: `false` (boolean). Verify that `NSAppTransportSecurity` does NOT contain `NSAllowsArbitraryLoads: true` — if the key exists with `true`, remove it. The `testInfoPlistHasRequiredUsageDescriptions` and `testATSDoesNotAllowArbitraryLoads` tests in `ComplianceTests.swift` must both pass after this change.

**Acceptance criteria:**
- [ ] `NSContactsUsageDescription` set to exact required string
- [ ] `NSMicrophoneUsageDescription` set to exact required string
- [ ] `NSSpeechRecognitionUsageDescription` set to exact required string
- [ ] `ITSAppUsesNonExemptEncryption` set to `false`
- [ ] `NSAllowsArbitraryLoads` absent or set to `false`
- [ ] `ComplianceTests.testInfoPlistHasRequiredUsageDescriptions` passes
- [ ] `ComplianceTests.testATSDoesNotAllowArbitraryLoads` passes

**Apple compliance (Spec 00 §11):**
- [ ] §11.3 — Permissions: all usage description strings present and accurate
- [ ] §11.4 — ATS: `NSAllowsArbitraryLoads` absent or false

---

#### ⬜ T-09-010 · GitHub Actions secrets documentation

| Field | Value |
|---|---|
| **Type** | SCAFFOLD |
| **Priority** | P0 |
| **Spec ref** | §7 — GitHub Secrets |
| **Depends on** | None |
| **Estimated effort** | S |
| **Files to create/modify** | `docs/secrets.md` |

**What to build:**
Create `docs/secrets.md` listing all 8 required GitHub Actions secrets with their names, descriptions, and setup instructions. The 8 secrets are: `SIGNING_CERTIFICATE_P12_BASE64` (Apple Distribution certificate exported as `.p12`, then `base64 -i cert.p12`); `SIGNING_CERTIFICATE_PASSWORD` (the `.p12` export password); `PROVISIONING_PROFILE_BASE64` (provisioning profile encoded as `base64 -i profile.mobileprovision`); `APP_STORE_CONNECT_API_KEY_ID` (key ID from App Store Connect); `APP_STORE_CONNECT_ISSUER_ID` (issuer UUID from App Store Connect); `APP_STORE_CONNECT_PRIVATE_KEY` (contents of the `.p8` private key file); `CODECOV_TOKEN` (from codecov.io project settings); `MANIFEST_SIGNING_PRIVATE_KEY` (ed25519 private key for signing `manifest.json`). Include a note: "Do not commit secret values to this file or any other file in the repository — reference only."

**Acceptance criteria:**
- [ ] All 8 secrets listed with names matching exactly what `ci.yml`, `e2e.yml`, and `release.yml` reference
- [ ] Setup instructions for each secret are actionable (specific commands or UI steps)
- [ ] Warning note present: "Do not commit secret values"
- [ ] Instructions for exporting a `.p12` certificate as base64 included
- [ ] Instructions for creating an App Store Connect API key included

**Apple compliance (Spec 00 §11):**
- [ ] N/A — documentation task; no code changes

---

#### ⬜ T-09-011 · PII scan expansion

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P1 |
| **Spec ref** | §3 — PII scan |
| **Depends on** | T-09-001 |
| **Estimated effort** | S |
| **Files to create/modify** | `.github/workflows/ci.yml` |

**What to build:**
Update the `pii-scan` job in `ci.yml` to cover all 9 PII variable name patterns from Spec 09 §3. The grep pattern should be: `messageBody|phoneNumber|contactName|emailAddress|senderName|messageContent|payload\.text|console\.log.*messageBody|console\.log.*phoneNumber`. The scan must cover both Swift files (`--include="*.swift"`) and TypeScript/TSX files (`--include="*.ts" --include="*.tsx"`) under `ios/App/GemmaKit/Sources/` and `src/`. To test the scan locally: (1) add the string `console.log(messageBody)` to any `.ts` file, run the grep command, verify it exits 1; (2) remove it, run again, verify it exits 0. Document this test procedure in a comment in `ci.yml`.

**Acceptance criteria:**
- [ ] All 9 PII patterns covered in the grep command
- [ ] Scan covers both Swift and TypeScript/TSX file types
- [ ] Scan covers both `ios/App/GemmaKit/Sources/` and `src/` directories
- [ ] Adding a deliberate `console.log(messageBody)` causes the scan to fail
- [ ] Removing it restores a passing scan
- [ ] Test procedure documented as a comment in `ci.yml`

**Apple compliance (Spec 00 §11):**
- [ ] §11.2 — Privacy: expanded PII scan covers all 9 sensitive variable names

---

#### ⬜ T-09-012 · Branch protection rules

| Field | Value |
|---|---|
| **Type** | BUILD |
| **Priority** | P1 |
| **Spec ref** | §8 — Branch protection |
| **Depends on** | T-09-001, T-09-002 |
| **Estimated effort** | S |
| **Files to create/modify** | `docs/contributing.md` |

**What to build:**
Configure GitHub branch protection for the `main` branch via the GitHub repository settings UI (or via `gh api`). Required status checks: all jobs in `ci.yml` (typescript, nextjs-build, pii-scan, swift-unit) and all jobs in `e2e.yml` (playwright, xcuitest-simulator). Require ≥ 1 approving review. Require branches to be up-to-date with `main` before merging. Require GPG-signed commits for any tag matching `v*` (document as a policy in `docs/contributing.md`; enforce via `git tag -s`). Create `docs/contributing.md` documenting: PR process, the required CI status checks, the 1-reviewer approval requirement, the GPG tag signing requirement with instructions for setting up a GPG key, and how to run the full CI suite locally before opening a PR.

**Acceptance criteria:**
- [ ] Branch protection requires all `ci.yml` and `e2e.yml` jobs to pass
- [ ] Branch protection requires ≥ 1 reviewer approval
- [ ] Branch protection requires branches to be up-to-date with `main`
- [ ] `docs/contributing.md` documents GPG tag signing with setup instructions
- [ ] `docs/contributing.md` lists all required local checks before opening a PR

**Apple compliance (Spec 00 §11):**
- [ ] N/A — CI/CD process controls; no production code

---

#### ⬜ T-09-013 · `.swiftlint.yml` + ESLint + Prettier CI

| Field | Value |
|---|---|
| **Type** | BUILD |
| **Priority** | P1 |
| **Spec ref** | §9.1 — Linter configuration |
| **Depends on** | T-09-004 |
| **Estimated effort** | S |
| **Files to create/modify** | `.swiftlint.yml`, `.eslintrc.json`, `.prettierrc`, `.github/workflows/ci.yml` |

**What to build:**
Verify `.swiftlint.yml` exists at the repository root with rules from Spec 00 §11.1 (created in T-00-003). If missing, create it with at minimum: `disabled_rules: [trailing_whitespace]`; `opt_in_rules: [force_unwrapping, explicit_type_interface]`; `excluded: [ios/App/Pods]`. Verify `.eslintrc.json` exists (created in T-00-002); if missing, create with `extends: ['next/core-web-vitals', 'plugin:@typescript-eslint/recommended']`. Create `.prettierrc` with `{ "semi": false, "singleQuote": true, "printWidth": 100, "trailingComma": "es5" }`. In the `typescript` job in `ci.yml`, add the step `npx prettier --check src/` as `npm run format:check` after the lint step. Add `"format:check": "prettier --check src/"` to `package.json` scripts.

**Acceptance criteria:**
- [ ] `.swiftlint.yml` present and valid; `swiftlint lint` exits 0 on the current codebase
- [ ] `.eslintrc.json` present; `npx eslint src/ --max-warnings 0` exits 0
- [ ] `.prettierrc` present with correct settings
- [ ] `npm run format:check` added to `package.json` and `ci.yml` typescript job
- [ ] All three linter/formatter steps pass in CI

**Apple compliance (Spec 00 §11):**
- [ ] §11.1 — SwiftLint with actor isolation rules enforced in CI

---

#### ⬜ T-09-014 · CI pipeline smoke test

| Field | Value |
|---|---|
| **Type** | TEST |
| **Priority** | P1 |
| **Spec ref** | §10 — CI validation |
| **Depends on** | T-09-001, T-09-002, T-09-004, T-09-013 |
| **Estimated effort** | M |
| **Files to create/modify** | None (validation task) |

**What to build:**
Open a passing PR to `main` with a trivial change (e.g., add a comment to `README.md`) to exercise the complete CI pipeline end-to-end. Verify all 4 `ci.yml` jobs pass: `typescript` (including coverage ≥ 80%), `nextjs-build`, `pii-scan`, `swift-unit` (including SwiftLint, Xcode Analyze, and `SWIFT_STRICT_CONCURRENCY=complete`). Verify all 2 `e2e.yml` jobs pass: `playwright` (chromium + Mobile Safari), `xcuitest-simulator`. Record the wall-clock duration of each job in the PR description and compare against the target durations: `ci.yml` total < 15 minutes, `e2e.yml` total < 25 minutes. If any job exceeds its target, identify the slowest step and file a follow-up issue to optimise it.

**Acceptance criteria:**
- [ ] All 4 `ci.yml` jobs green on the smoke-test PR
- [ ] All 2 `e2e.yml` jobs green
- [ ] Coverage ≥ 80% verified in `typescript` job
- [ ] PII scan clean
- [ ] `ci.yml` total duration < 15 minutes
- [ ] `e2e.yml` total duration < 25 minutes
- [ ] Job durations recorded in PR description

**Apple compliance (Spec 00 §11):**
- [ ] N/A — validation task; no new code

---

#### ⬜ T-09-015 · Capacitor sync + static export scripts

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P2 |
| **Spec ref** | §2 — Package scripts |
| **Depends on** | None |
| **Estimated effort** | S |
| **Files to create/modify** | `package.json` |

**What to build:**
Update `package.json` to ensure the following `scripts` are present with exact values: `"build": "next build"`, `"sync": "npx cap sync ios"`, `"build:ios": "npm run build && npm run sync"`, `"test:unit": "vitest run"`, `"test:unit:coverage": "vitest run --coverage"`, `"test:e2e": "playwright test"`, `"format:check": "prettier --check src/"`, `"format:write": "prettier --write src/"`, `"lint": "eslint src/ --max-warnings 0"`, `"typecheck": "tsc --noEmit"`. After adding/updating, run `npm run build:ios` in a clean checkout (after `npm ci`) and confirm the command exits 0 with no warnings from `npx cap sync`.

**Acceptance criteria:**
- [ ] All 10 script entries present in `package.json`
- [ ] `npm run build:ios` exits 0 in a clean checkout
- [ ] `npx cap sync ios` produces no warnings about missing web assets
- [ ] `npm run test:unit` runs Vitest in run (non-watch) mode
- [ ] `npm run format:check` is the exact command referenced in `ci.yml`

**Apple compliance (Spec 00 §11):**
- [ ] N/A — build tooling configuration

---

#### ⬜ T-09-016 · Release runbook

| Field | Value |
|---|---|
| **Type** | DOCUMENT |
| **Priority** | P2 |
| **Spec ref** | §4 — Release process |
| **Depends on** | T-09-003, T-09-012 |
| **Estimated effort** | S |
| **Files to create/modify** | `docs/release.md` |

**What to build:**
Create `docs/release.md` documenting the end-to-end release process in numbered steps. (1) Branch from `main` for the feature/fix. (2) Implement and open a PR — all CI gates must be green. (3) Get ≥ 1 reviewer approval and merge. (4) Tag the merge commit with a GPG-signed tag: `git tag -s v{N} -m "Release v{N}"`. (5) Push the tag: `git push origin v{N}` — this triggers `release.yml` automatically. (6) Monitor the `release.yml` run in GitHub Actions; it uploads to TestFlight automatically on success. (7) TestFlight "GemScan Internal" group receives a notification; allow 3 business days for internal sign-off. (8) Promote to "GemScan Beta" external TestFlight group. (9) Submit to App Store Review. Include a Rollback section: if a critical issue is found post-TestFlight, delete the tag (`git push --delete origin v{N}`), fix the issue, and release a new patch tag.

**Acceptance criteria:**
- [ ] All 9 numbered release steps documented
- [ ] GPG tag signing command accurate (`git tag -s`)
- [ ] Rollback instructions for tag deletion present
- [ ] TestFlight group name "GemScan Internal" referenced
- [ ] App Store Review submission step included

**Apple compliance (Spec 00 §11):**
- [ ] N/A — documentation task

---

#### ⬜ T-09-017 · Pre-submission CI/CD checklist

| Field | Value |
|---|---|
| **Type** | VALIDATE |
| **Priority** | P0 |
| **Spec ref** | §10 — Pre-submission checklist |
| **Depends on** | T-09-001, T-09-002, T-09-003, T-09-006, T-09-008, T-09-009, T-09-010 |
| **Estimated effort** | M |
| **Files to create/modify** | None (validation task) |

**What to build:**
Execute every item from Spec 09 §10 before the first App Store submission. Verify each of the following and record pass/fail: (1) all `ci.yml` jobs green on `main`; (2) all `e2e.yml` jobs green on `main`; (3) `pii-scan` reports zero violations; (4) TypeScript coverage ≥ 80% (`coverage/coverage-summary.json`); (5) `npm run build` exits 0 with zero TypeScript errors; (6) `npx cap sync ios` exits 0 with no warnings; (7) spot-check SHA-256 for `distilbert` and `e2b` entries in `manifest.json` against the actual downloaded model files; (8) `PrivacyInfo.xcprivacy` present in the app bundle (`find GemScan.xcarchive -name PrivacyInfo.xcprivacy`); (9) all 8 GitHub Secrets populated in the `production` environment; (10) release tag is GPG-signed (`git tag -v v{N}`); (11) TestFlight internal build distributed and at least one team member has installed it.

**Acceptance criteria:**
- [ ] All 11 checklist items executed and recorded
- [ ] Zero failures across all items
- [ ] `PrivacyInfo.xcprivacy` found in the `.xcarchive` bundle
- [ ] SHA-256 spot-check passes for `distilbert` and `e2b`
- [ ] GPG signature verified on release tag (`git tag -v` exits 0)
- [ ] TestFlight internal build installed by ≥ 1 team member
- [ ] Results documented in the release PR description

**Apple compliance (Spec 00 §11):**
- [ ] §11.3 — Usage descriptions verified in `Info.plist`
- [ ] §11.4 — ATS `NSAllowsArbitraryLoads` absent
- [ ] §11.9 — `PrivacyInfo.xcprivacy` present in archive bundle
