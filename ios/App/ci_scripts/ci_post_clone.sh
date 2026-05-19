#!/bin/sh
set -e

echo "==> ci_post_clone.sh starting at $(pwd)"
echo "==> Script location: $0"
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
#    The script lives in ios/App/ci_scripts, so the workspace is the sibling
#    ios/App/App.xcworkspace directory.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE="$SCRIPT_DIR/../App.xcworkspace"

echo "==> Resolving SwiftPM packages with macro/plugin validation skipped"
echo "==> Workspace: $WORKSPACE"
xcodebuild \
  -resolvePackageDependencies \
  -workspace "$WORKSPACE" \
  -scheme App \
  -skipMacroValidation \
  -skipPackagePluginValidation

echo "==> ci_post_clone.sh complete"
