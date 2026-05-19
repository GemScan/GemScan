#!/bin/sh
set -e

echo "==> ci_post_clone.sh starting at $(pwd)"
echo "==> Script location: $0"
echo "==> Xcode version: $(xcodebuild -version | head -1)"
echo "==> Node version: $(node --version 2>/dev/null || echo 'not installed')"

# 1. Disable macro / plugin fingerprint validation at the Xcode defaults level.
#    (The "Validatation" typo is Apple's real key name.)
defaults write com.apple.dt.Xcode IDESkipPackagePluginFingerprintValidatation -bool YES
defaults write com.apple.dt.Xcode IDESkipMacroFingerprintValidation -bool YES
echo "==> Xcode defaults set"

# Script lives in ios/App/ci_scripts; iOS project root is the parent;
# repo root is two levels up from that.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
IOS_APP_DIR="$SCRIPT_DIR/.."
REPO_ROOT="$IOS_APP_DIR/../.."
WORKSPACE="$IOS_APP_DIR/App.xcworkspace"

# 2. Install Node.js if missing. Xcode Cloud's image normally includes node,
#    but fall back to Homebrew so the script is robust to image changes.
if ! command -v node >/dev/null 2>&1; then
  echo "==> Installing Node via Homebrew"
  brew install node
fi

# 3. Build the Next.js static export and sync it into the iOS shell.
#    Without this, ios/App/App/public/ is empty (it's gitignored) and the
#    WebView would launch into a blank screen on the user's device.
#    `npx cap sync ios` also runs `pod install`, which produces the
#    Pods/Target Support Files/.../*.xcconfig files xcodebuild needs.
echo "==> Building web bundle and syncing Capacitor"
cd "$REPO_ROOT"
npm ci
npm run build
npx cap sync ios
echo "==> Web bundle synced; CocoaPods installed via cap sync"

# 4. Pre-resolve SwiftPM dependencies with the skip-validation flags so the
#    on-disk trust record exists before Xcode Cloud's main xcodebuild step
#    runs. This is what actually unblocks MLXHuggingFaceMacros from mlx-swift-lm.
echo "==> Resolving SwiftPM packages with macro/plugin validation skipped"
echo "==> Workspace: $WORKSPACE"
xcodebuild \
  -resolvePackageDependencies \
  -workspace "$WORKSPACE" \
  -scheme App \
  -skipMacroValidation \
  -skipPackagePluginValidation

echo "==> ci_post_clone.sh complete"
