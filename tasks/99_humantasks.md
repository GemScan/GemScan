# Tasks — Human-Only Work

> **Scope:** Things that only a human can do — Xcode UI clicks, account signups,
> license acceptances, on-Mac model conversions, plugging in a real device,
> uploading to a bucket. Code-side tasks live in `01_…` through `10_…`.
>
> Update the checkbox as each item completes.

---

## H1 · Apple Developer & Code Signing

- [ ] **H1.1 — Apple Developer account.** Enroll at [developer.apple.com](https://developer.apple.com). Free tier is sufficient for sideloading to a personal device; paid ($99/yr) is required for TestFlight, App Store, Push, CallKit-in-production, and 7-day-renewal-free provisioning.
- [ ] **H1.2 — Add Apple ID to Xcode.** Xcode → Settings → Accounts → `+` → sign in with the Developer-account Apple ID.
- [ ] **H1.3 — Set Team on App target.** `App.xcodeproj` → target `App` → Signing & Capabilities → Team = your team. Repeat for any extension targets (Share, Notification Service) once they exist.
- [ ] **H1.4 — Pick a stable Bundle Identifier.** Recommendation: `com.<yourdomain>.gemscan`. Once this hits TestFlight or the App Store it cannot change. Do this before H1.5.
- [ ] **H1.5 — Capabilities to enable in Xcode** (Signing & Capabilities → `+ Capability`):
  - Background Modes → *Audio, AirPlay, and Picture in Picture* (for VoIP/CallKit if used), *Background fetch*, *Background processing*, *Voice over IP* (if CallKit screening is enabled).
  - App Groups → `group.com.<yourdomain>.gemscan` (needed for sharing model files between the main app and any extensions).
  - Push Notifications (only if you ship server-driven alerts; on-device-only doesn't need this).

## H2 · iOS Project Wiring (Xcode UI — cannot be scripted reliably)

- [ ] **H2.1 — Add GemmaKit local package.** In Xcode: File → Add Package Dependencies → `Add Local…` → select `ios/App/GemmaKit`. Then on the App target → General → Frameworks, Libraries, and Embedded Content → `+` → add `GemmaKit`.
- [ ] **H2.2 — Add Swift plugin files to App target.** In the project navigator, right-click the `App` group → Add Files to "App"… → select:
  - `ios/App/App/GemmaPlugin.swift`
  - `ios/App/App/GemmaPlugin+CallKit.swift`
  - `ios/App/App/GemmaPlugin+MCP.swift`

  In the dialog, ensure **Target Membership = App** is checked. Build (⌘B) and fix any compile errors that surface (GemmaKit's source has not been exercised end-to-end yet — expect 1–2 small breakages on first compile).
- [ ] **H2.3 — Verify the bridge.** After H2.1 + H2.2 build clean, run on a simulator and confirm `[gemma/index] Loading native GemmaPlugin` shows in the Xcode console (not the mock-fallback warning). The Settings → On-device models rows should now exercise the real native path.
- [ ] **H2.4 — Add `Info.plist` permission strings** as features come online:
  - `NSContactsUsageDescription` — already required by `CapacitorCommunityContacts`.
  - `NSUserNotificationsUsageDescription` — when notification observation lands.
  - `NSMicrophoneUsageDescription` — only if/when the post-call audio path (Voice Agent §3.4a) is wired in.

  Missing strings = silent permission denial at runtime.

## H3 · Model Preparation (one-time, on your Mac)

- [ ] **H3.1 — Accept the Gemma license.** Sign in to [huggingface.co](https://huggingface.co), open the Gemma 4 E2B and E4B model pages, click "Acknowledge license". Without this, downloads return 401.
- [ ] **H3.2 — Generate an HF access token.** [huggingface.co/settings/tokens](https://huggingface.co/settings/tokens) → New token → "Read" scope. Used only on your Mac during conversion; **do not** ship this token in the iOS app.
- [ ] **H3.3 — Convert Gemma 4 E2B → MLX 4-bit.** On your Mac: `pip install mlx-lm` then `python -m mlx_lm.convert --hf-path google/gemma-4-2b-it -q --q-bits 4 -o ./out/gemma-4-e2b-mlx-q4`. Expected output: ~1.5 GB folder.
- [ ] **H3.4 — Convert Gemma 4 E4B → MLX 4-bit.** Same as H3.3 but `gemma-4-4b-it`. Expected output: ~3 GB folder.
- [ ] **H3.5 — (Fallback) Convert one tier to GGUF Q4_K_M** for `llama.cpp`-based inference. `git clone https://github.com/ggerganov/llama.cpp && python convert_hf_to_gguf.py … && ./llama-quantize … Q4_K_M`. Keep one GGUF around as a cross-platform escape hatch.
- [ ] **H3.6 — Convert DistilBERT SMS classifier → CoreML.** Use `coremltools.convert(...)`. The result is small (< 100 MB) and ships **bundled inside the app** — copy it into `ios/App/App/Resources/` and add to the App target.
- [ ] **H3.7 — Compute SHA-256 of every converted artifact.** `shasum -a 256 <file>`. These hashes go into the plugin's download manifest so corrupt downloads are caught by `ModelLoader.verify()`.

## H4 · Model Hosting (CDN bucket — pick one)

- [ ] **H4.1 — Provision a public-read bucket.** Cloudflare R2 (recommended; free egress) or AWS S3 or Backblaze B2. Region: closest to demo location.
- [ ] **H4.2 — Upload the converted artifacts** from H3.3 / H3.4 / H3.5. Folder layout:
  ```
  s3://gemscan-models/v1/
    gemma-4-e2b-mlx-q4.tar.gz
    gemma-4-e4b-mlx-q4.tar.gz
    gemma-4-e2b-gguf-q4km.gguf       (optional fallback)
  ```
  `tar.gz` the MLX folders so each model is a single download.
- [ ] **H4.3 — Record canonical URLs + SHA-256 + sizeBytes** in a manifest. Either hard-code in `GemmaPlugin.swift`'s download impl or host a tiny `manifest.json` next to the artifacts.
- [ ] **H4.4 — Verify a download from a clean machine** (not the one that uploaded). Anonymous `curl -O` should succeed.

## H5 · Device Testing

- [ ] **H5.1 — Pair a real iPhone with Xcode.** Plug in via USB → "Trust this computer" on the phone → Xcode → Window → Devices and Simulators → confirm device appears.
- [ ] **H5.2 — Enable Developer Mode on the iPhone** (iOS 16+). Settings → Privacy & Security → Developer Mode → toggle on → restart phone.
- [ ] **H5.3 — First on-device run.** Select your phone in Xcode's run-destination dropdown → ⌘R. First run will fail to launch; on the iPhone, Settings → General → VPN & Device Management → trust the developer profile → re-run.
- [ ] **H5.4 — Confirm models actually download on cellular + Wi-Fi.** Run with E2B (~1.5 GB) over Wi-Fi first; verify resume works by killing the app mid-download and relaunching.
- [ ] **H5.5 — Confirm RAM-residency status pill flips correctly.** After download, Settings page model row should read **Active** while loaded; background the app for >5 min in Passive mode and watch it switch to **Inactive**.

## H6 · Hackathon Demo Prep

- [ ] **H6.1 — Sideload pre-converted models for flight-mode demo.** Xcode → Devices and Simulators → select device → installed apps → GemScan → ⚙ → Download Container → drop converted MLX folders into `Documents/Models/`, then re-upload container. Avoids any network at demo time.
- [ ] **H6.2 — Charge demo device > 80%** the night before. Background unload timers wake the app; low-power mode skews them.
- [ ] **H6.3 — Disable auto-lock during demo.** Settings → Display & Brightness → Auto-Lock → Never. Reset after.
- [ ] **H6.4 — Pre-stage scam fixtures** in the Messages app (or wherever the demo entry point is) so the live walkthrough doesn't depend on receiving a real SMS.
- [ ] **H6.5 — Test full demo flight in airplane mode** the day before. Anything that blocks here, you cannot fix on stage.

## H7 · Pre-Submission (only when shipping beyond the hackathon)

- [ ] **H7.1 — Provide all app icon sizes.** Currently only `GemScanLogo` exists. Apple requires: 1024×1024 (App Store), plus Asset Catalog `AppIcon` entries for 20/29/40/60/76/83.5pt @ 2x/3x.
- [ ] **H7.2 — Privacy nutrition labels.** App Store Connect → App Privacy. Since GemScan is fully on-device, declare "Data Not Collected" for all categories — but do declare contact-access reasons (analysis only, not stored, not linked).
- [ ] **H7.3 — Export Compliance.** App uses standard cryptography (TLS for model download). In Info.plist set `ITSAppUsesNonExemptEncryption = NO` to skip the per-build BIS questionnaire.
- [ ] **H7.4 — Export the `Gemma-4 license notice`** into an in-app Acknowledgements screen (required by the Gemma usage terms).
- [ ] **H7.5 — TestFlight build.** Archive → Distribute → App Store Connect → process → invite internal testers.
