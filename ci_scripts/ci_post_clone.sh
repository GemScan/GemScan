#!/bin/sh
set -e

# Auto-trust SwiftPM macros and plugins on Xcode Cloud.
# Xcode 15+ blocks macro/plugin execution on first use until a user clicks
# "Trust & Enable" in the Xcode dialog. Xcode Cloud is headless and cannot
# click that dialog, so the build fails with:
#   "Macro 'X' from package 'Y' must be enabled before it can be used"
# Pre-disabling fingerprint validation makes the CI build pass without
# prompting. (The "Validatation" typo is Apple's real key name.)
defaults write com.apple.dt.Xcode IDESkipPackagePluginFingerprintValidatation -bool YES
defaults write com.apple.dt.Xcode IDESkipMacroFingerprintValidation -bool YES
