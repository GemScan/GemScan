#!/bin/sh
set -e

echo "==> ci_post_clone.sh starting at $(pwd)"
echo "==> Xcode version: $(xcodebuild -version | head -1)"

# 1. Disable macro / plugin fingerprint validation at the Xcode defaults level.
#    (The "Validatation" typo is Apple's real key name.)
defaults write com.apple.dt.Xcode IDESkipPackagePluginFingerprintValidatation -bool YES
defaults write com.apple.dt.Xcode IDESkipMacroFingerprintValidation -bool YES
echo "==> Xcode defaults set"

# 2. Pre-resolve SwiftPM dependencies with the skip-validation flags so the
#    on-disk trust record exists before Xcode Cloud's main xcodebuild step runs.
#    This is what actually unblocks MLXHuggingFaceMacros from mlx-swift-lm.
#
#    Xcode Cloud clones into $CI_WORKSPACE; locally $CI_WORKSPACE is unset, so
#    fall back to the repo root.
REPO_ROOT="${CI_WORKSPACE:-$(cd "$(dirname "$0")/.." && pwd)}"
WORKSPACE="$REPO_ROOT/ios/App/App.xcworkspace"

echo "==> Resolving SwiftPM packages with macro/plugin validation skipped"
xcodebuild \
  -resolvePackageDependencies \
  -workspace "$WORKSPACE" \
  -scheme App \
  -skipMacroValidation \
  -skipPackagePluginValidation

echo "==> ci_post_clone.sh complete"
