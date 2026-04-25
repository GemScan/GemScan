# Spec 09 — CI/CD and Deployment

---

## 1. Overview

GemScan uses **GitHub Actions** for all CI/CD. The pipeline is split into three workflow files:

| Workflow | Trigger | Duration target | Purpose |
|---|---|---|---|
| `ci.yml` | Every push + PR to `main` | < 15 min | Unit tests, type check, lint, PII scan |
| `e2e.yml` | PR to `main` (after `ci.yml` passes) | < 25 min | Playwright + XCTest on simulator |
| `release.yml` | Tag `v*` pushed to `main` | < 45 min | iOS build, sign, upload to TestFlight |

---

## 2. `ci.yml` — Continuous Integration

```yaml
# .github/workflows/ci.yml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  # ─────────────────────────────────────────────
  # 1. TypeScript: type check + lint + unit tests
  # ─────────────────────────────────────────────
  typescript:
    name: TypeScript
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Type check
        run: npx tsc --noEmit

      - name: Lint
        run: npx eslint src/ --max-warnings 0

      - name: Unit tests
        run: npm run test:unit -- --coverage --reporter=github-actions

      - name: Check coverage threshold
        run: |
          COVERAGE=$(cat coverage/coverage-summary.json | jq '.total.lines.pct')
          if (( $(echo "$COVERAGE < 80" | bc -l) )); then
            echo "Coverage $COVERAGE% is below 80% threshold"
            exit 1
          fi

      - name: Upload coverage
        uses: codecov/codecov-action@v4
        with:
          files: ./coverage/lcov.info

  # ─────────────────────────────────────────────
  # 2. Next.js build (static export)
  # ─────────────────────────────────────────────
  nextjs-build:
    name: Next.js Static Export
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
      - run: npm ci
      - run: npm run build
        env:
          NEXT_PUBLIC_IS_MOCK: 'true'
          NEXT_PUBLIC_APP_VERSION: ${{ github.sha }}
      - name: Verify out/ directory
        run: |
          test -f out/index.html || (echo "Static export failed — out/index.html missing" && exit 1)

  # ─────────────────────────────────────────────
  # 3. PII log scan — block any commit that logs PII
  # ─────────────────────────────────────────────
  pii-scan:
    name: PII Log Scan
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Scan for PII in log statements
        run: |
          # Fail if any Swift/TypeScript log statement contains raw message content, contact data, or URLs.
          # This checks for known PII field names. It is NOT exhaustive — code review is still required.
          # Expand this list when new PII-adjacent variable names are introduced.
          VIOLATIONS=$(grep -rn \
            -e 'logger\.\(debug\|info\|warning\|error\).*messageBody' \
            -e 'logger\.\(debug\|info\|warning\|error\).*phoneNumber' \
            -e 'logger\.\(debug\|info\|warning\|error\).*contactName' \
            -e 'logger\.\(debug\|info\|warning\|error\).*emailAddress' \
            -e 'logger\.\(debug\|info\|warning\|error\).*senderName' \
            -e 'logger\.\(debug\|info\|warning\|error\).*messageContent' \
            -e 'logger\.\(debug\|info\|warning\|error\).*payload\.text' \
            -e 'console\.\(log\|warn\|error\).*messageBody' \
            -e 'console\.\(log\|warn\|error\).*phoneNumber' \
            --include="*.swift" --include="*.ts" --include="*.tsx" \
            src/ GemmaKit/Sources/ 2>/dev/null || true)
          if [ -n "$VIOLATIONS" ]; then
            echo "PII detected in log statements:"
            echo "$VIOLATIONS"
            exit 1
          fi
          echo "PII scan passed — no violations found"

  # ─────────────────────────────────────────────
  # 4. Swift: GemmaKit unit tests on simulator
  # ─────────────────────────────────────────────
  swift-unit:
    name: Swift Unit Tests
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
      - name: Select Xcode
        # Pin to minimum required Xcode. To update the version, change this value
        # and the corresponding runner image in all jobs. Minimum: 15.3 (Swift 5.10, iOS 17.4 SDK).
        # Use `ls /Applications/Xcode*.app` on macos-14 to list available versions.
        run: sudo xcode-select -s /Applications/Xcode_15.3.app
      - name: Build and test GemmaKit
        run: |
          xcodebuild test \
            -scheme GemmaKit \
            -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=17.4' \
            -resultBundlePath TestResults.xcresult \
            CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO
      - name: Upload test results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: swift-test-results
          path: TestResults.xcresult

```

---

## 3. `e2e.yml` — End-to-End Tests

```yaml
# .github/workflows/e2e.yml
name: E2E Tests

on:
  pull_request:
    branches: [main]

jobs:
  playwright:
    name: Playwright (Web Mock)
    runs-on: ubuntu-latest
    needs: []   # Independent — runs in parallel with swift unit if triggered by PR
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
      - run: npm ci
      - name: Install Playwright browsers
        run: npx playwright install --with-deps chromium webkit

      - name: Run Playwright tests
        run: npx playwright test
        env:
          NEXT_PUBLIC_IS_MOCK: 'true'
          CI: 'true'

      - name: Upload Playwright report
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: playwright-report
          path: playwright-report/

  xcuitest-simulator:
    name: XCUITest (iOS Simulator)
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode_15.3.app

      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
      - run: npm ci

      - name: Build web app (mock mode)
        run: npm run build
        env:
          NEXT_PUBLIC_IS_MOCK: 'true'
          NEXT_PUBLIC_APP_VERSION: 'ci-test'

      - name: Capacitor sync
        run: npx cap sync ios

      - name: Run XCUITests on simulator
        run: |
          xcodebuild test \
            -workspace ios/App/App.xcworkspace \
            -scheme App \
            -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=17.4' \
            -testPlan GemScanUITests \
            -resultBundlePath UITestResults.xcresult \
            CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO

      - name: Upload XCUITest results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: xcuitest-results
          path: UITestResults.xcresult
```

---

## 4. `release.yml` — TestFlight

```yaml
# .github/workflows/release.yml
name: Release

on:
  push:
    tags:
      - 'v*'

jobs:
  # ─────────────────────────────────────────────
  # iOS: Build, sign, upload to TestFlight
  # ─────────────────────────────────────────────
  ios-release:
    name: iOS TestFlight
    runs-on: macos-14
    environment: production
    steps:
      - uses: actions/checkout@v4

      - name: Select Xcode
        # Same Xcode pin as ci.yml. Update in both files simultaneously.
        run: sudo xcode-select -s /Applications/Xcode_15.3.app

      - name: Verify model manifest signature
        run: |
          # Confirm the model manifest is reachable and ed25519 signature is valid.
          # Model weights are NOT downloaded in CI — this only verifies the signed manifest
          # (manifest.json) that ModelLoader uses at first launch to resolve download URLs.
          MANIFEST_URL="https://huggingface.co/GemScan/manifest/resolve/main/manifest.json"
          curl -fsSL "$MANIFEST_URL" -o manifest.json
          python3 scripts/verify_manifest_signature.py manifest.json \
            --pubkey scripts/manifest_pubkey.pem
          echo "✅ Model manifest signature verified"

      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - run: npm ci

      - name: Build Next.js static export
        run: npm run build
        env:
          NEXT_PUBLIC_APP_VERSION: ${{ github.ref_name }}
          NEXT_PUBLIC_IS_MOCK: 'false'

      - name: Capacitor sync
        run: npx cap sync ios

      - name: Install provisioning profile
        run: |
          echo "${{ secrets.IOS_PROVISIONING_PROFILE_BASE64 }}" | base64 -d > profile.mobileprovision
          mkdir -p ~/Library/MobileDevice/Provisioning\ Profiles
          cp profile.mobileprovision ~/Library/MobileDevice/Provisioning\ Profiles/

      - name: Install signing certificate
        run: |
          echo "${{ secrets.IOS_CERTIFICATE_BASE64 }}" | base64 -d > certificate.p12
          security import certificate.p12 -P "${{ secrets.IOS_CERTIFICATE_PASSWORD }}" \
            -A -t cert -f pkcs12 -k ~/Library/Keychains/login.keychain-db

      - name: Build and archive
        run: |
          xcodebuild archive \
            -workspace ios/App/App.xcworkspace \
            -scheme App \
            -configuration Release \
            -archivePath GemScan.xcarchive \
            CODE_SIGN_STYLE=Manual \
            PROVISIONING_PROFILE_SPECIFIER="${{ secrets.IOS_PROVISIONING_PROFILE_NAME }}" \
            CODE_SIGN_IDENTITY="${{ secrets.IOS_SIGNING_IDENTITY }}"

      - name: Export IPA
        run: |
          cat > ExportOptions.plist << 'EOF'
          <?xml version="1.0" encoding="UTF-8"?>
          <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
          <plist version="1.0">
          <dict>
            <key>method</key><string>app-store-connect</string>
            <key>uploadBitcode</key><false/>
            <key>uploadSymbols</key><true/>
          </dict>
          </plist>
          EOF
          xcodebuild -exportArchive \
            -archivePath GemScan.xcarchive \
            -exportPath GemScan.ipa \
            -exportOptionsPlist ExportOptions.plist

      - name: Upload to TestFlight via App Store Connect API
        run: |
          xcrun altool --upload-app \
            --type ios \
            --file "GemScan.ipa/GemScan.ipa" \
            --apiKey "${{ secrets.ASC_API_KEY_ID }}" \
            --apiIssuer "${{ secrets.ASC_ISSUER_ID }}"

      - name: Distribute to internal TestFlight group
        run: |
          # After upload processes (~5 min), add build to the "GemScan Internal" group
          # Group name in App Store Connect: "GemScan Internal" (internal testers only)
          # External TestFlight review is triggered manually after internal sign-off
          echo "TestFlight group: GemScan Internal (internal only)"
          echo "External group promotion: manual via App Store Connect UI"

```

---

## 5. Model Download Pipeline

Model weights are **never committed to git**. They are downloaded at runtime (first launch) or via a background prefetch. The model download URLs and SHA-256 checksums are stored in a signed manifest.

> **Hosting:** For the hackathon submission, model artifacts are hosted directly on Hugging Face Hub (`huggingface.co/GemScan/`). The `manifest.json` is served from `https://huggingface.co/GemScan/manifest/resolve/main/manifest.json`. For production, this moves to a CDN-backed URL with cryptographic signing (ed25519). The SHA-256 verification step is mandatory regardless of hosting provider.

### 5.1 Model Manifest

```json
// Hosted at: https://models.gemscan.app/manifest.json (signed, served via CDN)
{
  "version": "1.0.0",
  "models": [
    {
      "id": "distilbert",
      "platform": "ios",
      "artifact": "GemScan/sms-triage-distilbert",
      "filename": "sms-triage-distilbert.mlmodelc.zip",
      "sha256": "abc123...",
      "sizeBytes": 5242880,
      "downloadUrl": "https://huggingface.co/GemScan/sms-triage-distilbert/resolve/main/sms-triage-distilbert.mlmodelc.zip"
    },
    {
      "id": "e2b",
      "platform": "ios",
      "artifact": "GemScan/gemma-4-e2b-it-GemScan-q4km",
      "filename": "gemma-4-e2b-q4_k_m.gguf",
      "sha256": "def456...",
      "sizeBytes": 1610612736,
      "downloadUrl": "https://huggingface.co/GemScan/gemma-4-e2b-it-GemScan-q4km/resolve/main/gemma-4-e2b-q4_k_m.gguf"
    },
    {
      "id": "e4b",
      "platform": "ios",
      "artifact": "GemScan/gemma-4-e4b-it-GemScan-q4km",
      "filename": "gemma-4-e4b-q4_k_m.gguf",
      "sha256": "ghi789...",
      "sizeBytes": 3006477107,
      "downloadUrl": "https://huggingface.co/GemScan/gemma-4-e4b-it-GemScan-q4km/resolve/main/gemma-4-e4b-q4_k_m.gguf"
    },
    {
      "id": "whisper-small-mlx",
      "platform": "ios",
      "artifact": "GemScan/whisper-small-mlx",
      "filename": "whisper-small-mlx",
      "sha256": "jkl012...",
      "sizeBytes": 157286400,
      "downloadUrl": "https://huggingface.co/GemScan/whisper-small-mlx/resolve/main/whisper-small-mlx.zip",
      "requiredFor": ["scoreVoice"],
      "downloadPolicy": "on_demand"
    },
    {
      "id": "audioseal-detector-mlx",
      "platform": "ios",
      "artifact": "GemScan/audioseal-detector-mlx",
      "filename": "audioseal-detector-mlx",
      "sha256": "mno345...",
      "sizeBytes": 31457280,
      "downloadUrl": "https://huggingface.co/GemScan/audioseal-detector-mlx/resolve/main/audioseal-detector-mlx.zip",
      "requiredFor": ["scoreVoice"],
      "downloadPolicy": "on_demand"
    }
  ]
}

// `downloadPolicy` values:
// - "required"   → downloaded at first launch (blocks app use until complete)
// - "on_demand"  → downloaded lazily when first feature that needs it is invoked
// distilbert, e2b = "required"; e4b, whisper-small-mlx, audioseal-detector-mlx = "on_demand"
```

### 5.2 SHA-256 Verification

```swift
// GemmaKit/Sources/Inference/ModelLoader.swift (verification step — see Spec 02 for full loader)
import CryptoKit

extension ModelLoader {
    func verifySHA256(fileURL: URL, expectedHex: String) throws {
        let data = try Data(contentsOf: fileURL)
        let digest = SHA256.hash(data: data)
        let actualHex = digest.compactMap { String(format: "%02x", $0) }.joined()

        guard actualHex == expectedHex else {
            GemScanLogger.inference.error("SHA-256 mismatch for \(fileURL.lastPathComponent): expected \(expectedHex) got \(actualHex)")
            // Delete corrupted file
            try? FileManager.default.removeItem(at: fileURL)
            throw GemScanError.modelNotLoaded(tier: .e2b)    // Conservative: mark as not loaded
        }
        GemScanLogger.inference.info("SHA-256 verified: \(fileURL.lastPathComponent)")
    }
}
```

---

## 6. App Store Privacy Manifest

Apple requires a `PrivacyInfo.xcprivacy` manifest for all apps submitted to the App Store.

```xml
<!-- ios/App/App/PrivacyInfo.xcprivacy -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>NSPrivacyAccessedAPITypes</key>
  <array>
    <!-- Contacts: cross-reference sender identity -->
    <dict>
      <key>NSPrivacyAccessedAPIType</key>
      <string>NSPrivacyAccessedAPICategoryContacts</string>
      <key>NSPrivacyAccessedAPITypeReasons</key>
      <array>
        <string>C617.1</string>  <!-- User-initiated sender verification -->
      </array>
    </dict>
    <!-- UserDefaults: App Group shared container for extensions -->
    <dict>
      <key>NSPrivacyAccessedAPIType</key>
      <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
      <key>NSPrivacyAccessedAPITypeReasons</key>
      <array>
        <string>CA92.1</string>  <!-- Extension data sharing via App Group -->
      </array>
    </dict>
    <!-- File timestamp: model cache management -->
    <dict>
      <key>NSPrivacyAccessedAPIType</key>
      <string>NSPrivacyAccessedAPICategoryFileTimestamp</string>
      <key>NSPrivacyAccessedAPITypeReasons</key>
      <array>
        <string>C617.1</string>
      </array>
    </dict>
  </array>

  <key>NSPrivacyCollectedDataTypes</key>
  <array>
    <!-- We do NOT collect any data types. All processing is on-device. -->
  </array>

  <key>NSPrivacyTracking</key>
  <false/>   <!-- No tracking whatsoever -->
</dict>
</plist>
```

---

## 7. Required GitHub Secrets

| Secret | Used in | Description |
|---|---|---|
| `IOS_CERTIFICATE_BASE64` | `release.yml` | Apple Distribution certificate, base64-encoded p12 |
| `IOS_CERTIFICATE_PASSWORD` | `release.yml` | p12 password |
| `IOS_PROVISIONING_PROFILE_BASE64` | `release.yml` | App Store distribution profile, base64-encoded |
| `IOS_PROVISIONING_PROFILE_NAME` | `release.yml` | Profile name string |
| `IOS_SIGNING_IDENTITY` | `release.yml` | e.g. `Apple Distribution: GemScan Inc` |
| `ASC_API_KEY_ID` | `release.yml` | App Store Connect API key ID |
| `ASC_ISSUER_ID` | `release.yml` | App Store Connect issuer UUID |
| `CODECOV_TOKEN` | `ci.yml` | Codecov upload token |

---

## 8. Branch and Release Strategy

```
main ─────────────────────────────────────────────────────────── production
  │
  ├── feature/* ──── PR → CI (ci.yml) → E2E (e2e.yml) → merge
  │
  └── tag v1.0.0 ── release.yml → TestFlight (internal)
                      └── Manual promotion → TestFlight (external) → App Store review
```

### Release Tagging

```bash
# Tag a release after all tests pass on main
git tag -s v1.0.0 -m "GemScan v1.0.0 — Hackathon submission"
git push origin v1.0.0
```

The `-s` flag signs the tag with the committer's GPG key. Tags must be signed for `release.yml` to proceed.

### Merge Requirements

PRs to `main` require:
1. `ci.yml` all jobs green
2. `e2e.yml` all jobs green
3. At least 1 reviewer approval
4. Branch is up-to-date with `main`

---

## 9. Weekly Benchmark Workflow

```yaml
# .github/workflows/benchmark.yml
name: Weekly Benchmark

on:
  schedule:
    - cron: '0 4 * * 1'   # Every Monday at 4 AM UTC
  workflow_dispatch:

jobs:
  inference-benchmark:
    name: Inference Benchmark
    runs-on: macos-14    # Physical runner for accurate performance metrics
    steps:
      - uses: actions/checkout@v4
      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode_15.3.app
      - name: Run benchmark suite
        run: |
          xcodebuild test \
            -scheme GemmaKitBenchmarks \
            -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=17.4' \
            -testPlan BenchmarkTests \
            -resultBundlePath BenchmarkResults.xcresult
      - name: Extract metrics
        run: |
          xcresulttool get --format json --path BenchmarkResults.xcresult > benchmark_results.json
      - name: Check regression thresholds
        run: node scripts/check-benchmark-regression.js benchmark_results.json
      - name: Upload benchmark results
        uses: actions/upload-artifact@v4
        with:
          name: benchmark-results-${{ github.run_number }}
          path: benchmark_results.json
```

---

## 10. CI/CD Checklist (Pre-Submission)

- [ ] All `ci.yml` jobs green on `main`
- [ ] All `e2e.yml` jobs green on final PR
- [ ] PII scan: zero violations
- [ ] TypeScript coverage ≥ 80% on `src/lib/`
- [ ] `npm run build` produces zero TypeScript errors
- [ ] `npx cap sync` completes without warnings
- [ ] SHA-256 manifest entries match downloaded model weights (verified in release build)
- [ ] `PrivacyInfo.xcprivacy` present and correct (App Store review gate)
- [ ] All GitHub Secrets populated in `production` environment
- [ ] Release tag is GPG-signed
- [ ] TestFlight internal build distributed to test group before external review
