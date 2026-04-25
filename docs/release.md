# Release Runbook

## Version Tagging

GemScan uses semantic versioning (`MAJOR.MINOR.PATCH`).

```bash
# Create a signed tag
git tag -s v1.0.0 -m "Release v1.0.0: initial App Store submission"

# Push the tag to trigger release.yml
git push origin v1.0.0
```

## Release Workflow

The `release.yml` GitHub Actions workflow triggers on any `v*` tag push:

1. **Verify model manifest** — `scripts/verify_manifest_signature.py` checks the ed25519 signature of `manifest.json`
2. **Build Next.js** — Production static export (`NEXT_PUBLIC_IS_MOCK=false`)
3. **Capacitor sync** — `npx cap sync ios` copies `out/` to the iOS project
4. **Xcode archive** — `xcodebuild archive` with Release configuration
5. **Export IPA** — `xcodebuild -exportArchive` with App Store distribution profile
6. **Upload to TestFlight** — `xcrun altool --upload-app` via App Store Connect API

## Pre-Release Checklist

Before tagging a release:

- [ ] All CI checks pass on `main` (ci.yml + e2e.yml)
- [ ] `npm run test:unit` — 110+ tests pass, 80%+ coverage on `src/lib/`
- [ ] `npm run build` — Static export succeeds
- [ ] `npx tsc --noEmit` — Zero TypeScript errors
- [ ] Swift tests pass: `xcodebuild test -scheme GemmaKitTests`
- [ ] Model manifest SHA-256 hashes verified for all artifacts
- [ ] `PrivacyInfo.xcprivacy` updated if new APIs are accessed
- [ ] `Info.plist` usage descriptions reviewed
- [ ] Changelog updated in PR description

## TestFlight Distribution

### Internal Testing

1. Tag triggers `release.yml` → auto-uploads to App Store Connect
2. Build appears in TestFlight within 15-30 minutes
3. Internal group "GemScan Internal" receives the build automatically
4. Test on physical devices:
   - SMS Filter activation
   - Model download + inference
   - Share Sheet flow
   - Guardian mode pairing

### External Testing

1. Promote internal build to external group in App Store Connect
2. Submit for Beta App Review (required for first build)
3. Review typically takes 24-48 hours
4. External testers receive TestFlight invitation

### App Store Submission

1. In App Store Connect, select the TestFlight build
2. Complete App Store listing:
   - Screenshots (6.7", 6.5", 5.5")
   - App description, keywords, categories
   - Privacy policy URL
   - Support URL
3. Submit for App Review
4. Review typically takes 24-48 hours

## Model Manifest Updates

When updating model weights:

```bash
# 1. Upload new model artifacts to Hugging Face
# 2. Compute SHA-256 hashes
shasum -a 256 gemma-4-e2b-it-GemScan-q4km.gguf

# 3. Update manifest.json with new hashes and URLs
# 4. Sign the manifest
python scripts/verify_manifest_signature.py --sign manifest.json

# 5. Commit and push
git add manifest.json
git commit -m "Update model manifest for v1.1.0"
```

## Rollback Procedures

### TestFlight Rollback

1. In App Store Connect → TestFlight → Builds
2. Expire the problematic build
3. Previous build becomes the active version
4. No tag deletion needed — old builds remain available

### App Store Rollback

1. If the release is in review: cancel the submission
2. If the release is live: submit a new version with the fix
3. For critical issues: contact Apple Developer Support for expedited review
4. Prepare a hotfix branch from the previous release tag:

```bash
git checkout -b hotfix/v1.0.1 v1.0.0
# Apply fix
git tag -s v1.0.1 -m "Hotfix: [description]"
git push origin v1.0.1
```

## Post-Release Checks

After a successful release:

- [ ] TestFlight build received and installable
- [ ] Cold start completes within 3 seconds
- [ ] Model download succeeds for all tiers
- [ ] SMS analysis produces correct verdicts
- [ ] Guardian mode pairing works
- [ ] No crash reports in Xcode Organizer
- [ ] Metrics dashboard shows expected latency ranges
- [ ] Weekly benchmark workflow runs on schedule

## GitHub Secrets Required

See [docs/secrets.md](./secrets.md) for the full list of GitHub Actions secrets needed for the release workflow.
