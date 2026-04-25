#!/usr/bin/env bash
#
# GemScan — Build & Test Script
#
# Usage:
#   ./scripts/build-and-test.sh            # Run everything
#   ./scripts/build-and-test.sh --quick     # Typecheck + unit tests only
#   ./scripts/build-and-test.sh --web       # TypeScript pipeline only (no Swift)
#   ./scripts/build-and-test.sh --ios       # Swift pipeline only (no TypeScript)
#   ./scripts/build-and-test.sh --e2e       # Unit tests + Playwright E2E
#   ./scripts/build-and-test.sh --ci        # Full CI-equivalent pipeline
#
# Exit codes:
#   0 — all checks passed
#   1 — one or more checks failed (scroll up for the first failure)

set -euo pipefail

# ──────────────────────────────────────────────────────────────
# Configuration
# ──────────────────────────────────────────────────────────────
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
RESET='\033[0m'

PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0
STEPS=()

MODE="${1:-all}"

# ──────────────────────────────────────────────────────────────
# Helpers
# ──────────────────────────────────────────────────────────────
banner() {
  echo ""
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo -e "${BOLD}  $1${RESET}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

step_pass() {
  echo -e "  ${GREEN}✓${RESET} $1"
  PASS_COUNT=$((PASS_COUNT + 1))
  STEPS+=("${GREEN}✓${RESET} $1")
}

step_fail() {
  echo -e "  ${RED}✗${RESET} $1"
  FAIL_COUNT=$((FAIL_COUNT + 1))
  STEPS+=("${RED}✗${RESET} $1")
}

step_skip() {
  echo -e "  ${YELLOW}–${RESET} $1 (skipped)"
  SKIP_COUNT=$((SKIP_COUNT + 1))
  STEPS+=("${YELLOW}–${RESET} $1 (skipped)")
}

run_step() {
  local name="$1"
  shift
  if "$@" > /tmp/gemscan-step-output.log 2>&1; then
    step_pass "$name"
    return 0
  else
    step_fail "$name"
    echo ""
    echo -e "  ${RED}Output:${RESET}"
    tail -20 /tmp/gemscan-step-output.log | sed 's/^/    /'
    echo ""
    return 1
  fi
}

# ──────────────────────────────────────────────────────────────
# Dependency check
# ──────────────────────────────────────────────────────────────
banner "1. Environment Check"

if command -v node &>/dev/null; then
  NODE_VER=$(node --version)
  step_pass "Node.js $NODE_VER"
else
  step_fail "Node.js not found — install Node.js 20 LTS"
fi

if [ -d node_modules ]; then
  step_pass "node_modules present"
else
  echo -e "  ${YELLOW}→${RESET} Installing dependencies..."
  if npm install --prefer-offline > /tmp/gemscan-step-output.log 2>&1; then
    step_pass "npm install"
  else
    step_fail "npm install"
    tail -10 /tmp/gemscan-step-output.log | sed 's/^/    /'
  fi
fi

HAS_XCODE=false
if [[ "$MODE" != "--web" ]]; then
  if command -v xcodebuild &>/dev/null; then
    XCODE_VER=$(xcodebuild -version 2>/dev/null | head -1 || echo "unknown")
    step_pass "Xcode: $XCODE_VER"
    HAS_XCODE=true
  else
    step_skip "Xcode not found — Swift checks will be skipped"
  fi
fi

HAS_SWIFTLINT=false
if [[ "$MODE" != "--web" ]] && command -v swiftlint &>/dev/null; then
  step_pass "SwiftLint $(swiftlint version)"
  HAS_SWIFTLINT=true
elif [[ "$MODE" != "--web" ]]; then
  step_skip "SwiftLint not found (brew install swiftlint)"
fi

# ──────────────────────────────────────────────────────────────
# TypeScript pipeline
# ──────────────────────────────────────────────────────────────
if [[ "$MODE" != "--ios" ]]; then

  banner "2. TypeScript Type Check"
  run_step "tsc --noEmit" npx tsc --noEmit || true

  banner "3. ESLint"
  run_step "eslint src/" npx eslint src/ --max-warnings 0 || true

  banner "4. Prettier Format Check"
  run_step "prettier --check" npx prettier --check src/ || true

  banner "5. Unit Tests (Vitest)"
  if npx vitest run 2>&1 | tee /tmp/gemscan-step-output.log | tail -5; then
    TEST_SUMMARY=$(grep -E "Tests\s+" /tmp/gemscan-step-output.log | tail -1)
    FILES_SUMMARY=$(grep -E "Test Files" /tmp/gemscan-step-output.log | tail -1)
    if echo "$FILES_SUMMARY" | grep -q "failed"; then
      step_fail "Vitest: $FILES_SUMMARY"
    else
      step_pass "Vitest: $FILES_SUMMARY / $TEST_SUMMARY"
    fi
  else
    step_fail "Vitest crashed"
  fi

  banner "6. Test Coverage"
  npx vitest run --coverage > /tmp/gemscan-step-output.log 2>&1
  COV_EXIT=$?
  # Show the summary table
  grep -E "(All files|ERROR|Stmts)" /tmp/gemscan-step-output.log | head -5
  if [ $COV_EXIT -eq 0 ]; then
    LINES_PCT=$(grep "All files" /tmp/gemscan-step-output.log | awk '{print $4}' | head -1)
    step_pass "Coverage: $LINES_PCT% lines"
  else
    if grep -q "ERROR.*Coverage" /tmp/gemscan-step-output.log; then
      ERRORS=$(grep "ERROR" /tmp/gemscan-step-output.log | head -3)
      step_fail "Coverage thresholds not met"
      echo "$ERRORS" | sed 's/^/    /'
    else
      step_fail "Coverage run failed"
      tail -5 /tmp/gemscan-step-output.log | sed 's/^/    /'
    fi
  fi

  banner "7. Next.js Production Build"
  if npx next build 2>&1 | tee /tmp/gemscan-step-output.log | grep -E "(Compiled|Route|error)" | head -10; then
    if grep -q "error" /tmp/gemscan-step-output.log; then
      step_fail "Next.js build"
    else
      step_pass "Next.js static export"
    fi
  else
    step_fail "Next.js build crashed"
  fi

  # Verify the export output
  if [ -d out ] && [ -f out/index.html ]; then
    PAGE_COUNT=$(find out -name 'index.html' | wc -l | tr -d ' ')
    step_pass "Static export: $PAGE_COUNT pages in out/"
  else
    step_fail "Static export: out/index.html missing"
  fi

  # E2E tests (only in --e2e or --ci or all mode)
  if [[ "$MODE" == "--e2e" || "$MODE" == "--ci" || "$MODE" == "all" ]]; then
    banner "8. Playwright E2E Tests"
    if command -v npx &>/dev/null && npx playwright --version &>/dev/null 2>&1; then
      # Check if browsers are installed
      if npx playwright install --dry-run chromium 2>&1 | grep -q "already"; then
        run_step "Playwright E2E" npx playwright test || true
      else
        echo -e "  ${YELLOW}→${RESET} Installing Playwright browsers..."
        npx playwright install chromium webkit 2>/dev/null
        run_step "Playwright E2E" npx playwright test || true
      fi
    else
      step_skip "Playwright not available"
    fi
  fi

  # PII scan
  if [[ "$MODE" == "--ci" || "$MODE" == "all" ]]; then
    banner "9. PII Scan"
    PII_FOUND=false

    # Check for hardcoded emails in non-test source
    if grep -rn --include='*.ts' --include='*.tsx' \
      -E '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}' \
      --exclude-dir=node_modules --exclude-dir='.git' \
      --exclude-dir='__tests__' --exclude-dir='__fixtures__' \
      --exclude='*.test.*' --exclude='*.spec.*' \
      src/lib/ src/hooks/ 2>/dev/null; then
      PII_FOUND=true
    fi

    # Check for console.log with potential PII
    if grep -rn --include='*.ts' --include='*.tsx' \
      'console\.log' \
      --exclude-dir=node_modules --exclude-dir='__tests__' \
      --exclude='*.test.*' \
      src/lib/ src/hooks/ src/components/ 2>/dev/null; then
      echo -e "  ${YELLOW}Warning: console.log found — use logger instead${RESET}"
    fi

    if [ "$PII_FOUND" = true ]; then
      step_fail "PII scan: potential email addresses in source"
    else
      step_pass "PII scan: clean"
    fi
  fi

fi

# ──────────────────────────────────────────────────────────────
# Swift pipeline
# ──────────────────────────────────────────────────────────────
if [[ "$MODE" != "--web" && "$MODE" != "--quick" ]]; then

  banner "10. Swift Checks"

  if [ "$HAS_SWIFTLINT" = true ]; then
    run_step "SwiftLint" swiftlint lint --config .swiftlint.yml --quiet ios/ || true
  else
    step_skip "SwiftLint (not installed)"
  fi

  if [ "$HAS_XCODE" = true ]; then
    # Build GemmaKit
    run_step "GemmaKit build" xcodebuild build \
      -project ios/App/App.xcodeproj \
      -scheme GemmaKit \
      -destination 'generic/platform=iOS Simulator' \
      -quiet || true

    # Run Swift tests
    run_step "GemmaKit tests" xcodebuild test \
      -project ios/App/App.xcodeproj \
      -scheme GemmaKitTests \
      -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
      -quiet || true

    # Static analyzer
    run_step "Xcode analyze" xcodebuild analyze \
      -project ios/App/App.xcodeproj \
      -scheme GemmaKit \
      -destination 'generic/platform=iOS Simulator' \
      -quiet || true
  else
    step_skip "GemmaKit build (no Xcode)"
    step_skip "GemmaKit tests (no Xcode)"
    step_skip "Xcode analyze (no Xcode)"
  fi

  # Verify Swift file conventions
  banner "11. Swift Convention Checks"

  FORCE_UNWRAPS=$(grep -rn '!\.' --include='*.swift' \
    --exclude-dir='Tests' --exclude-dir='Mocks' \
    ios/App/GemmaKit/Sources/ ios/App/Plugins/ ios/App/Extensions/ 2>/dev/null \
    | grep -v '// swiftlint:disable' \
    | grep -v 'import ' \
    | grep -v '\/\/\/' \
    | wc -l | tr -d ' ')

  if [ "$FORCE_UNWRAPS" -eq 0 ]; then
    step_pass "No force-unwraps in production Swift code"
  else
    step_fail "Found $FORCE_UNWRAPS potential force-unwraps in production code"
    grep -rn '!\.' --include='*.swift' \
      --exclude-dir='Tests' --exclude-dir='Mocks' \
      ios/App/GemmaKit/Sources/ ios/App/Plugins/ ios/App/Extensions/ 2>/dev/null \
      | grep -v '// swiftlint:disable' \
      | grep -v 'import ' \
      | grep -v '\/\/\/' \
      | head -5 | sed 's/^/    /'
  fi

  PRINT_STMTS=$(grep -rn '^\s*print(' --include='*.swift' \
    --exclude-dir='Tests' --exclude-dir='Mocks' \
    ios/App/GemmaKit/Sources/ ios/App/Plugins/ ios/App/Extensions/ 2>/dev/null \
    | wc -l | tr -d ' ')

  if [ "$PRINT_STMTS" -eq 0 ]; then
    step_pass "No print() in production Swift code (use os.Logger)"
  else
    step_fail "Found $PRINT_STMTS print() statements — use GemScanLogger instead"
  fi

  DIRECT_DEFAULTS=$(grep -rn 'UserDefaults\.standard' --include='*.swift' \
    --exclude-dir='Tests' --exclude-dir='Mocks' \
    ios/App/GemmaKit/Sources/ ios/App/Plugins/ ios/App/Extensions/ 2>/dev/null \
    | wc -l | tr -d ' ')

  if [ "$DIRECT_DEFAULTS" -eq 0 ]; then
    step_pass "No UserDefaults.standard (use SharedContainerSchema)"
  else
    step_fail "Found $DIRECT_DEFAULTS UserDefaults.standard — use App Group"
  fi
fi

# ──────────────────────────────────────────────────────────────
# Manifest & data integrity
# ──────────────────────────────────────────────────────────────
if [[ "$MODE" == "--ci" || "$MODE" == "all" ]]; then
  banner "12. Data Integrity"

  if [ -f manifest.json ]; then
    MODEL_COUNT=$(python3 -c "import json; print(len(json.load(open('manifest.json'))['models']))" 2>/dev/null || echo "0")
    if [ "$MODEL_COUNT" -gt 0 ]; then
      step_pass "Model manifest: $MODEL_COUNT models defined"
    else
      step_fail "Model manifest: no models found"
    fi
  else
    step_fail "manifest.json missing"
  fi

  for f in ios/App/App/Resources/ScamPatterns.json \
           ios/App/App/Resources/blocklist.json \
           ios/App/App/Resources/whois-cache.json \
           ios/App/App/Resources/phone-reputation.json; do
    if [ -f "$f" ]; then
      ENTRIES=$(python3 -c "import json; d=json.load(open('$f')); print(len(d) if isinstance(d,list) else len(d.get('patterns',d.get('domains',d.get('entries',d.get('records',[]))))))" 2>/dev/null || echo "?")
      step_pass "$(basename "$f"): $ENTRIES entries"
    else
      step_fail "$(basename "$f") missing"
    fi
  done

  # Check entitlement files
  ENT_COUNT=$(find ios/App -name '*.entitlements' | wc -l | tr -d ' ')
  if [ "$ENT_COUNT" -ge 4 ]; then
    step_pass "Entitlement files: $ENT_COUNT found"
  else
    step_fail "Entitlement files: only $ENT_COUNT found (expected ≥ 4)"
  fi

  # Check PrivacyInfo.xcprivacy
  if [ -f ios/App/App/PrivacyInfo.xcprivacy ]; then
    step_pass "PrivacyInfo.xcprivacy present"
  else
    step_fail "PrivacyInfo.xcprivacy missing"
  fi

  # Check Info.plist
  if [ -f ios/App/App/Info.plist ]; then
    step_pass "Info.plist present"
  else
    step_fail "Info.plist missing"
  fi
fi

# ──────────────────────────────────────────────────────────────
# Summary
# ──────────────────────────────────────────────────────────────
banner "Summary"

TOTAL=$((PASS_COUNT + FAIL_COUNT + SKIP_COUNT))

echo ""
for s in "${STEPS[@]}"; do
  echo -e "  $s"
done
echo ""
echo -e "  ${GREEN}Passed: $PASS_COUNT${RESET}  ${RED}Failed: $FAIL_COUNT${RESET}  ${YELLOW}Skipped: $SKIP_COUNT${RESET}  Total: $TOTAL"
echo ""

if [ "$FAIL_COUNT" -gt 0 ]; then
  echo -e "${RED}${BOLD}  BUILD FAILED — $FAIL_COUNT check(s) did not pass${RESET}"
  echo ""
  exit 1
else
  echo -e "${GREEN}${BOLD}  BUILD PASSED — all checks green${RESET}"
  echo ""
  exit 0
fi
