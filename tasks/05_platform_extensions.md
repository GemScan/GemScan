# Tasks — iOS Platform Extensions

> **Spec:** `specs/05_platform_extensions.md` | **Milestone:** M5 — iOS Platform Extensions | **Depends on:** M0, M2, M4

## Milestone Summary
Implement all five iOS extension targets — SMSFilter (`ILMessageFilterExtension`), CallDirectory (`CXCallDirectoryProvider`), Share, AppIntents, and Safari Content Blocker — plus the App Group entitlements, `SharedContainerSchema`, and the inter-process communication layer between extensions and the main app. Extensions use shared UserDefaults (App Group `group.com.gemscan`) and the on-device models from M2. No model inference occurs outside the main app except in `ILMessageFilterExtension` (DistilBERT triage only, 50 MB ceiling).

## Prerequisites
- M0 complete: `GemScanError`, `AgentTask`, `Verdict`, `TriageLabel`, `TriageResult` types defined
- M2 complete: `SMSTriage.shared`, `SMSTriage.extensionInstance()`, `ModelLoader`, `ModelLoader.syncPathToAppGroup()`, `SharedContainerSchema.appGroupId` defined
- M4 complete: `MessageFilterServer` reads from App Group UserDefaults (M5 writes it)
- Apple Developer portal: App Group `group.com.gemscan` created; all five extension IDs registered under the team account

## Progress Tracker
| Status | Count |
|--------|-------|
| ✅ Done | 0 |
| 🔄 In progress | 0 |
| ⬜ Not started | 16 |

---
## Tasks

#### ⬜ T-05-001 · SCAFFOLD · P0 — App Group entitlements for all targets

| Field | Value |
|---|---|
| **Type** | SCAFFOLD |
| **Priority** | P0 |
| **Spec ref** | §2.1 — Entitlements and capability configuration |
| **Depends on** | None |
| **Estimated effort** | S |
| **Files to create/modify** | `ios/App/App/App.entitlements`, `ios/App/Extensions/SMSFilter/SMSFilter.entitlements`, `ios/App/Extensions/CallDirectory/CallDirectory.entitlements`, `ios/App/Extensions/Share/Share.entitlements`, `ios/App/Extensions/AppIntents/AppIntents.entitlements` |

**What to build:**
Create five `.entitlements` XML plist files. `ios/App/App/App.entitlements` (main target): include `com.apple.security.application-groups` array containing `group.com.gemscan`, and `aps-environment` string set to `production`. `ios/App/Extensions/SMSFilter/SMSFilter.entitlements`: include `com.apple.security.application-groups` array containing `group.com.gemscan`. `ios/App/Extensions/CallDirectory/CallDirectory.entitlements`: include `com.apple.security.application-groups` containing `group.com.gemscan`. `ios/App/Extensions/Share/Share.entitlements`: include `com.apple.security.application-groups` containing `group.com.gemscan`. `ios/App/Extensions/AppIntents/AppIntents.entitlements`: include `com.apple.security.application-groups` containing `group.com.gemscan`. All files use the standard `<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" ...>` header. Each `.entitlements` file must be added to its corresponding Xcode target via Build Settings → Code Signing Entitlements. Enable the "App Groups" capability in the Apple Developer portal for each App ID.

**Acceptance criteria:**
- [ ] All five `.entitlements` files exist at the specified paths and are valid XML plists
- [ ] Each file contains `com.apple.security.application-groups` → `[group.com.gemscan]`
- [ ] `App.entitlements` additionally contains `aps-environment: production`
- [ ] `xcodebuild build -scheme App` produces zero "entitlement not found" warnings

**Apple compliance (Spec 00 §11):**
- [ ] §11.4 — entitlements in all five `.entitlements` files match capabilities registered in the Apple Developer portal

---

#### ⬜ T-05-002 · IMPLEMENT · P0 — SharedContainerSchema

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P0 |
| **Spec ref** | §2.2 — Shared container keys and data types |
| **Depends on** | T-05-001, T-00-013 |
| **Estimated effort** | S |
| **Files to create/modify** | `ios/App/GemmaKit/Sources/Extensions/SharedContainerSchema.swift` |

**What to build:**
Extend the `SharedContainerSchema` stub created in T-00-013 (which defines `appGroupId` and `distilbertModelPath`). Add the remaining keys and types. Define `enum SharedContainerSchema` (caseless, used as namespace) with: `static let appGroupId = "group.com.gemscan"`. Define the following static UserDefaults key constants — all must begin with the prefix `"gemscan."`: `static let distilbertModelPath = "gemscan.distilbertModelPath"` (String — absolute path to the DistilBERT `.mlmodelc` directory in the shared container); `static let lastAnalysisTimestamp = "gemscan.lastAnalysisTimestamp"` (Double — Unix timestamp); `static let verdictHistory = "gemscan.verdictHistory"` (Data — JSON-encoded array of recent verdicts); `static let guardianModeEnabled = "gemscan.guardianModeEnabled"` (Bool); `static let trustedContactId = "gemscan.trustedContactId"` (String — hashed contact identifier). Define `struct ScamPhoneEntry: Codable` with `phoneNumber: Int64` (E.164 digits-only, e.g. `+14155551234` → `Int64(14155551234)`) and `riskScore: Float`. Add an inline comment on `phoneNumber` explaining: `// E.164 encoding: strip '+' and all non-decimal chars, e.g. +14155551234 → 14155551234`.

**Acceptance criteria:**
- [ ] All key constants begin with `"gemscan."` — verified by unit test `testSchemaKeyNamesUseGemscanPrefix()`
- [ ] `ScamPhoneEntry(phoneNumber: 14155551234, riskScore: 0.9)` encodes and decodes correctly via `JSONEncoder`/`JSONDecoder`
- [ ] `SharedContainerSchema.appGroupId == "group.com.gemscan"`
- [ ] `enum SharedContainerSchema` has no cases (pure namespace — cannot be instantiated)

**Apple compliance (Spec 00 §11):**
- [ ] §11.4 — App Group ID matches the value in all five `.entitlements` files exactly

---

#### ⬜ T-05-003 · IMPLEMENT · P0 — ILMessageFilterExtension

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P0 |
| **Spec ref** | §3.1 — SMSFilter extension ILMessageFilterQueryHandling |
| **Depends on** | T-05-001, T-05-002, T-05-008 |
| **Estimated effort** | M |
| **Files to create/modify** | `ios/App/Extensions/SMSFilter/MessageFilterExtension.swift` |

**What to build:**
Create `ios/App/Extensions/SMSFilter/MessageFilterExtension.swift`. Define `class MessageFilterExtension: ILMessageFilterExtension, ILMessageFilterQueryHandling`. Implement `func handle(_ queryRequest: ILMessageFilterQueryRequest, context: ILMessageFilterExtensionContext, completion: @escaping (ILMessageFilterQueryResponse) -> Void)`. In the handler: obtain `SMSTriage.extensionInstance()` — if this throws (model path not set), call `completion` with `ILMessageFilterQueryResponse()` where `action = .none` (defer to network). Wrap the classification in a `Task` with a hard timeout of 5 seconds: if exceeded, complete with `.none`. Otherwise, call `SMSTriage.extensionInstance().classify(text: queryRequest.messageBody ?? "")`, map `TriageLabel` to `ILMessageFilterAction` (`.safe` → `.allow`, `.spam` → `.filter`, `.suspicious` → `.none`), and call `completion` with the mapped action. After classification, write the verdict to `UserDefaults(suiteName: SharedContainerSchema.appGroupId)` under key `"filter_history_\(senderHash)"` as `[String: Any]` dict with `verdict: String`, `user_allowed: Bool`, `scan_count: Int`. Memory ceiling: enforce `.cpuOnly` compute units when initializing `SMSTriage.extensionInstance()`.

**Acceptance criteria:**
- [ ] Extension compiles and links against `IdentityLookup.framework`
- [ ] When `SMSTriage.extensionInstance()` throws, `completion` is called with `action == .none` (no crash)
- [ ] A message classified as `.spam` results in `ILMessageFilterAction.filter`
- [ ] Classification that takes over 5 seconds completes with `.none` (timeout path)
- [ ] `UserDefaults(suiteName: SharedContainerSchema.appGroupId)` is written after every classification

**Apple compliance (Spec 00 §11):**
- [ ] §11.2 — extension memory ceiling: `.cpuOnly` compute enforced; Xcode memory gauge must stay under 50 MB
- [ ] §11.4 — extension bundle ID follows `{mainBundleID}.SMSFilter` pattern

---

#### ⬜ T-05-004 · IMPLEMENT · P0 — CallDirectoryExtension

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P0 |
| **Spec ref** | §3.2 — CallDirectory CXCallDirectoryProvider implementation |
| **Depends on** | T-05-001, T-05-002 |
| **Estimated effort** | M |
| **Files to create/modify** | `ios/App/Extensions/CallDirectory/CallDirectoryExtension.swift` |

**What to build:**
Create `ios/App/Extensions/CallDirectory/CallDirectoryExtension.swift`. Define `class CallDirectoryExtension: CXCallDirectoryProvider`. Override `func beginRequest(with context: CXCallDirectoryExtensionContext)`. In `beginRequest`: read the `ScamPhoneEntry` records array from the shared container (stored as JSON-encoded `Data` under `SharedContainerSchema.verdictHistory` or a dedicated phone list key). For blocking: iterate records sorted ascending by `phoneNumber` (ascending order is required by CallKit), skip any entry with `phoneNumber <= 0`, call `context.addBlockingEntry(withNextSequentialPhoneNumber: CXCallDirectoryPhoneNumber(entry.phoneNumber))`. For identification: call `context.addIdentificationEntry(withNextSequentialPhoneNumber: CXCallDirectoryPhoneNumber(entry.phoneNumber), label: "Scam - GemScan (\(Int(entry.riskScore * 100))%)")`. Call `context.completeRequest()` at the end. Memory ceiling: 120 MB — do not load any ML models in this extension.

**Acceptance criteria:**
- [ ] `addBlockingEntry` is called for each valid `ScamPhoneEntry` in ascending `phoneNumber` order
- [ ] Entries with `phoneNumber <= 0` are skipped without crashing
- [ ] `context.completeRequest()` is always called (even if the entries list is empty)
- [ ] No ML model loading occurs in this extension — no `import CoreML` or GemmaKit inference calls

**Apple compliance (Spec 00 §11):**
- [ ] §11.2 — extension memory ceiling: no model loading; Xcode memory gauge must stay under 120 MB with 1000 entries
- [ ] §11.4 — extension bundle ID follows `{mainBundleID}.CallDirectory` pattern

---

#### ⬜ T-05-005 · IMPLEMENT · P1 — ShareExtension

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P1 |
| **Spec ref** | §3.3 — Share extension URL-scheme handoff |
| **Depends on** | T-05-001 |
| **Estimated effort** | S |
| **Files to create/modify** | `ios/App/Extensions/Share/ShareViewController.swift` |

**What to build:**
Create `ios/App/Extensions/Share/ShareViewController.swift`. Define `class ShareViewController: UIViewController, NSExtensionRequestHandling`. In `viewDidLoad()`: iterate `extensionContext?.inputItems` cast as `[NSExtensionItem]`; for each item, check `NSItemProvider` for `UTType.url` first (using `loadItem(forTypeIdentifier: UTType.url.identifier)`), then for `UTType.plainText`. Encode the extracted content as an `AgentTask` using `JSONEncoder`, then base64url-encode the resulting `Data`. Open the main GemScan app via `extensionContext?.open(URL(string: "gemscan://analyse?task=\(encodedTask)")!, completionHandler:)`. Call `extensionContext?.completeRequest(returningItems: [], completionHandler: nil)` after the URL open. Do not perform any model inference in this extension — hand-off only. Memory ceiling: 120 MB.

**Acceptance criteria:**
- [ ] Sharing a URL from Safari opens GemScan at `gemscan://analyse?task=<encoded>`
- [ ] Sharing plain text also produces a valid `task=` URL parameter
- [ ] No inference, no CoreML import, no GemmaKit import in this file
- [ ] `extensionContext?.completeRequest` is always called

**Apple compliance (Spec 00 §11):**
- [ ] §11.2 — extension memory ceiling: no model loading; memory gauge under 120 MB
- [ ] §11.4 — `NSExtensionActivationRule` in `Info.plist` limits activation to `SUBQUERY(..., $attachment, ANY $attachment.registeredTypeIdentifiers UTI-CONFORMS-TO "public.url") COUNT >= 1`

---

#### ⬜ T-05-006 · IMPLEMENT · P1 — AppIntents extension

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P1 |
| **Spec ref** | §3.4 — AppIntents Siri and Shortcuts integration |
| **Depends on** | T-05-001 |
| **Estimated effort** | M |
| **Files to create/modify** | `ios/App/Extensions/AppIntents/CheckMessageIntent.swift`, `ios/App/Extensions/AppIntents/ScanURLIntent.swift`, `ios/App/Extensions/AppIntents/AppShortcuts.strings` |

**What to build:**
Create `ios/App/Extensions/AppIntents/CheckMessageIntent.swift` conforming to `AppIntent`. Set `static var title: LocalizedStringResource = "Check Message for Scams"`. Define `@Parameter var messageText: String`. Implement `func perform() async throws -> some IntentResult`: encode `messageText` as an `AgentTask`, base64url-encode it, open `URL(string: "gemscan://analyse?task=\(encoded)")` via `UIApplication.shared.open(_:)`. Return `.result()`. Create `ScanURLIntent.swift` with `static var title: LocalizedStringResource = "Scan URL with GemScan"`, `@Parameter var url: URL`, same handoff pattern. Create `AppShortcuts.strings` with localized intent names for all 5 locales (`en`, `es`, `zh-Hans`, `fr`, `de`). Both intents must be visible in Siri and the Shortcuts app — add `static var parameterSummary: some ParameterSummary` returning the appropriate summary.

**Acceptance criteria:**
- [ ] Both intents appear in the Shortcuts app after the app is installed on device
- [ ] `CheckMessageIntent.perform()` opens `gemscan://analyse?task=...` URL
- [ ] `AppShortcuts.strings` contains entries for all 5 locales for both intent titles
- [ ] No inference occurs in the extension — handoff only

**Apple compliance (Spec 00 §11):**
- [ ] §11.4 — AppIntents extension bundle ID follows `{mainBundleID}.AppIntents`
- [ ] §11.2 — no model loading in AppIntents extension

---

#### ⬜ T-05-007 · IMPLEMENT · P1 — Safari Content Blocker

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P1 |
| **Spec ref** | §3.5 — Safari Content Blocker dynamic blocklist |
| **Depends on** | T-05-001, T-04-005 |
| **Estimated effort** | M |
| **Files to create/modify** | `ios/App/Extensions/SafariContentBlocker/ContentBlockerRequestHandler.swift` |

**What to build:**
Create `ios/App/Extensions/SafariContentBlocker/ContentBlockerRequestHandler.swift`. Define `class ContentBlockerRequestHandler: NSObject, NSExtensionRequestHandling`. Implement `func beginRequest(with context: NSExtensionContext)`. In `beginRequest`: read the blocklist domains from the shared container (stored by `URLReputationServer` or a dedicated blocklist key under `SharedContainerSchema`). Generate a `blockerList.json` array conforming to the Safari Content Blocker rules format: each entry is `{"trigger": {"url-filter": ".*\\.{domain}"}, "action": {"type": "block"}}`. Write the JSON to a temporary file, create an `NSItemProvider` with the file URL and type `"org.webkit.safari-content-blocker"`, set it on `NSExtensionItem`, and call `context.completeRequest(returningItems:)`. Implement a background refresh mechanism: after the main app updates the blocklist, call `SFContentBlockerManager.reloadContentBlocker(withIdentifier: "{mainBundleID}.SafariContentBlocker", completionHandler:)` from the main app's `ModelLoader` or a dedicated `BlocklistSyncService`.

**Acceptance criteria:**
- [ ] `beginRequest` returns a valid `blockerList.json` without crashing on an empty blocklist
- [ ] The generated JSON is valid Safari Content Blocker format (parseable by Safari)
- [ ] `SFContentBlockerManager.reloadContentBlocker` is called after every blocklist update in the main app
- [ ] Extension compiles against `SafariServices.framework`

**Apple compliance (Spec 00 §11):**
- [ ] §11.4 — extension bundle ID follows `{mainBundleID}.SafariContentBlocker`
- [ ] §11.2 — no model loading; extension only reads from shared container

---

#### ⬜ T-05-008 · INTEGRATE · P0 — SMSTriage extension instance integration

| Field | Value |
|---|---|
| **Type** | INTEGRATE |
| **Priority** | P0 |
| **Spec ref** | §4.1 — SMSTriage.extensionInstance() wiring |
| **Depends on** | T-05-002, T-05-003 |
| **Estimated effort** | S |
| **Files to create/modify** | `ios/App/GemmaKit/Sources/Inference/SMSTriage.swift`, `ios/App/GemmaKit/Sources/Models/ModelLoader.swift`, `ios/App/GemmaKit/Tests/SMSTriageExtensionTests.swift` |

**What to build:**
In `SMSTriage.swift`, add `static func extensionInstance() throws -> SMSTriage`: read `SharedContainerSchema.distilbertModelPath` from `UserDefaults(suiteName: SharedContainerSchema.appGroupId)` — if the value is nil or empty, throw `GemScanError.modelNotReady`. Otherwise, initialise a new `SMSTriage` instance pointing at the shared container path with `.cpuOnly` compute units and return it. Do not cache the instance (extensions may have a different lifecycle than the main app). In `ModelLoader.swift`, implement `func syncPathToAppGroup()`: after successfully downloading and compiling the DistilBERT model, write its absolute path to `UserDefaults(suiteName: SharedContainerSchema.appGroupId)` under key `SharedContainerSchema.distilbertModelPath`. Call `syncPathToAppGroup()` at the end of the first-launch model download flow. In `SMSTriageExtensionTests.swift`, write `testExtensionInstanceThrowsWhenPathNotSet()` and `testExtensionInstanceSucceedsAfterPathWritten()`.

**Acceptance criteria:**
- [ ] `SMSTriage.extensionInstance()` throws `GemScanError.modelNotReady` when `distilbertModelPath` is not set — verified by `testExtensionInstanceThrowsWhenPathNotSet()`
- [ ] `SMSTriage.extensionInstance()` returns a valid instance after `ModelLoader.syncPathToAppGroup()` has been called — verified by `testExtensionInstanceSucceedsAfterPathWritten()`
- [ ] The returned instance uses `.cpuOnly` compute units
- [ ] `syncPathToAppGroup()` is called exactly once during first-launch model setup

**Apple compliance (Spec 00 §11):**
- [ ] §11.2 — `.cpuOnly` enforced in extension instance to stay within 50 MB memory ceiling

---

#### ⬜ T-05-009 · INTEGRATE · P1 — MessageFilterServer ↔ ILMessageFilterExtension

| Field | Value |
|---|---|
| **Type** | INTEGRATE |
| **Priority** | P1 |
| **Spec ref** | §4.2 — Verdict persistence and MessageFilterServer read path |
| **Depends on** | T-05-003, T-04-009 |
| **Estimated effort** | S |
| **Files to create/modify** | `ios/App/Extensions/SMSFilter/MessageFilterExtension.swift`, `ios/App/GemmaKit/Tests/MessageFilterIntegrationTests.swift` |

**What to build:**
After classification in `ILMessageFilterExtension.handle(_:context:completion:)`, compute `senderHash = SHA256(queryRequest.sender ?? "").hexString` and write the following dictionary to `UserDefaults(suiteName: SharedContainerSchema.appGroupId)` under key `"filter_history_\(senderHash)"`: `["verdict": verdictString, "user_allowed": false, "scan_count": existingCount + 1]`. Read `existingCount` from the same key before writing (default 0 if absent). Create `ios/App/GemmaKit/Tests/MessageFilterIntegrationTests.swift` as an `XCTestCase` subclass. Write `testMessageFilterServerReadsExtensionVerdicts()`: simulate an extension classification by writing the dict to a test App Group defaults, then call `MessageFilterServer.execute(tool: "check_sender_history", input: ["sender_hash": senderHash])` and assert `previous_verdict` equals the written verdict string and `scan_count` equals `"1"`.

**Acceptance criteria:**
- [ ] `ILMessageFilterExtension` writes the verdict dict with the correct key format `"filter_history_{sha256hex}"`
- [ ] `scan_count` increments on each subsequent classification of the same sender
- [ ] `testMessageFilterServerReadsExtensionVerdicts()` passes without real SMS delivery
- [ ] The test uses a shared `UserDefaults` suite, not a mock

**Apple compliance (Spec 00 §11):**
- [ ] §11.3 — no raw sender phone number written to shared defaults; only SHA-256 hash used as key

---

#### ⬜ T-05-010 · IMPLEMENT · P1 — SharedContainerSchema read/write tests

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P1 |
| **Spec ref** | §2.2 — SharedContainerSchema data contract |
| **Depends on** | T-05-002 |
| **Estimated effort** | S |
| **Files to create/modify** | `ios/App/GemmaKit/Tests/SharedContainerTests.swift` |

**What to build:**
Create `ios/App/GemmaKit/Tests/SharedContainerTests.swift` as an `XCTestCase` subclass. Write three test cases. `testWriteAndReadDistilbertPath()`: write a test path string to `UserDefaults(suiteName: SharedContainerSchema.appGroupId)` under `SharedContainerSchema.distilbertModelPath`, then read it back and assert it equals the written value; clean up in `tearDown()`. `testScamPhoneEntryEncodesE164Correctly()`: construct `ScamPhoneEntry(phoneNumber: 14155551234, riskScore: 0.9)`, encode with `JSONEncoder`, decode with `JSONDecoder`, and assert `decoded.phoneNumber == Int64(14155551234)` — also confirm `Int64(14155551234)` represents the E.164 number `+14155551234` with `+` and `-` stripped. `testSchemaKeyNamesUseGemscanPrefix()`: iterate all `SharedContainerSchema` key constants (as a hard-coded list in the test), and assert each begins with `"gemscan."`.

**Acceptance criteria:**
- [ ] `testWriteAndReadDistilbertPath` passes and cleans up the key in `tearDown()`
- [ ] `testScamPhoneEntryEncodesE164Correctly` verifies both encode and decode round-trip
- [ ] `testSchemaKeyNamesUseGemscanPrefix` covers all five key constants
- [ ] Tests do not depend on a real device App Group (use `UserDefaults(suiteName:)` which works in simulators)

**Apple compliance (Spec 00 §11):**
- [ ] §11.7 — N/A (unit tests only)

---

#### ⬜ T-05-011 · TEST · P1 — Extension memory ceiling tests

| Field | Value |
|---|---|
| **Type** | TEST |
| **Priority** | P1 |
| **Spec ref** | §11.2 — Spec 00 §11 extension memory ceilings |
| **Depends on** | T-05-003, T-05-004 |
| **Estimated effort** | M |
| **Files to create/modify** | `ios/App/GemmaKitUITests/ExtensionMemoryTests.swift` |

**What to build:**
Create `ios/App/GemmaKitUITests/ExtensionMemoryTests.swift` as an `XCTestCase` subclass using XCTest performance APIs. `testSMSFilterMemoryUnder50MB()`: use `XCTMemoryMetric` in an `measure(metrics:)` block; within the block, invoke the `ILMessageFilterExtension` handler with 10 consecutive fake message bodies via direct method call (not a real SMS delivery); assert `XCTMemoryMetric.peakMemoryUsage < 50 * 1024 * 1024` bytes. `testCallDirectoryMemoryUnder120MB()`: initialise a `CallDirectoryExtension` with a `MockCXCallDirectoryExtensionContext` containing 1000 `ScamPhoneEntry` records; call `beginRequest(with: mockContext)` inside an `XCTMemoryMetric` measure block; assert peak RSS < 120 MB. Both tests run on simulator — document that real-device values may differ.

**Acceptance criteria:**
- [ ] `testSMSFilterMemoryUnder50MB` runs on the iOS simulator without requiring a real SMS
- [ ] Peak memory for 10-message batch classification stays under 50 MB
- [ ] `testCallDirectoryMemoryUnder120MB` uses a `MockCXCallDirectoryExtensionContext` (no real CallKit)
- [ ] Peak memory for 1000-entry `addBlockingEntries` stays under 120 MB

**Apple compliance (Spec 00 §11):**
- [ ] §11.2 — memory ceiling tests are part of CI gate; PRs that regress beyond ceiling are blocked

---

#### ⬜ T-05-012 · TEST · P1 — CallDirectory phone encoding test

| Field | Value |
|---|---|
| **Type** | TEST |
| **Priority** | P1 |
| **Spec ref** | §2.2 — ScamPhoneEntry E.164 encoding |
| **Depends on** | T-05-002, T-05-004 |
| **Estimated effort** | S |
| **Files to create/modify** | `ios/App/GemmaKit/Tests/CallDirectoryTests.swift` |

**What to build:**
Create `ios/App/GemmaKit/Tests/CallDirectoryTests.swift` as an `XCTestCase` subclass. Write `testCallDirectoryPhoneNumberEncoding()`: construct `ScamPhoneEntry(phoneNumber: 14155551234, riskScore: 0.85)`, cast `entry.phoneNumber` to `CXCallDirectoryPhoneNumber`, and assert it equals `CXCallDirectoryPhoneNumber(14155551234)`. Also verify that a `CallDirectoryExtension` processing this entry calls `MockContext.addBlockingEntry(withNextSequentialPhoneNumber: CXCallDirectoryPhoneNumber(14155551234))`. Write `testCallDirectoryRejectsInvalidNumber()`: construct `ScamPhoneEntry(phoneNumber: -1, riskScore: 0.9)` and `ScamPhoneEntry(phoneNumber: 0, riskScore: 0.9)`; pass both to `CallDirectoryExtension` via a mock context; assert neither triggers an `addBlockingEntry` call (entries are silently skipped) and no crash occurs.

**Acceptance criteria:**
- [ ] `CXCallDirectoryPhoneNumber(14155551234)` equals the `phoneNumber` field directly
- [ ] Negative and zero phone numbers result in zero `addBlockingEntry` calls
- [ ] No crash or assertion failure for invalid numbers
- [ ] `MockCXCallDirectoryExtensionContext` records all `addBlockingEntry` calls for assertion

**Apple compliance (Spec 00 §11):**
- [ ] §11.4 — `CXCallDirectoryPhoneNumber` is `Int64` as required by CallKit API

---

#### ⬜ T-05-013 · DOCUMENT · P2 — Extension developer setup guide

| Field | Value |
|---|---|
| **Type** | DOCUMENT |
| **Priority** | P2 |
| **Spec ref** | §2.1 — Developer onboarding for extensions |
| **Depends on** | T-05-001, T-05-002, T-05-003, T-05-004 |
| **Estimated effort** | S |
| **Files to create/modify** | `docs/extension-setup.md`, `ios/App/GemmaKit/Sources/Extensions/SharedContainerSchema.swift` |

**What to build:**
Create `docs/extension-setup.md` covering: (1) how to enable the App Groups capability in the Apple Developer portal for the main App ID and each of the five extension IDs; (2) how to add each `.entitlements` file to its respective Xcode target via Build Settings → Code Signing Entitlements (include a table mapping target name → `.entitlements` path → Build Settings key); (3) how to test each extension in the iOS simulator (ILMessageFilterExtension in Messages settings, CallDirectory in Phone settings, Share from Safari share sheet, AppIntents via Shortcuts app); (4) known simulator limitations for `ILMessageFilterExtension` (real SMS filtering requires a physical device and carrier network; simulator only allows direct method invocation in tests). Add inline code comments to `SharedContainerSchema.swift` explaining the E.164 encoding convention with concrete examples: `// E.164 encoding: strip '+' and all non-decimal chars // +14155551234 → 14155551234 (Int64) // +44 20 7946 0958 → 442079460958 (Int64)`.

**Acceptance criteria:**
- [ ] `docs/extension-setup.md` exists and covers all four sections listed above
- [ ] The Xcode target → `.entitlements` path table is present
- [ ] `SharedContainerSchema.swift` has at least two E.164 examples in inline comments
- [ ] The simulator limitations section explicitly calls out `ILMessageFilterExtension` device-only constraint

**Apple compliance (Spec 00 §11):**
- [ ] §11.7 — N/A (documentation only)

---

#### ⬜ T-05-014 · VALIDATE · P1 — Extensions Apple compliance

| Field | Value |
|---|---|
| **Type** | VALIDATE |
| **Priority** | P1 |
| **Spec ref** | §11.2, §11.4 — Spec 00 §11 extension memory and entitlement requirements |
| **Depends on** | T-05-001, T-05-003, T-05-004, T-05-005, T-05-006, T-05-007, T-05-008, T-05-011 |
| **Estimated effort** | S |
| **Files to create/modify** | `ios/App/Extensions/` (all extension files — fix issues found, no new files) |

**What to build:**
Run the full Spec 00 §11.7 PR compliance checklist for the M5 milestone. Steps: (1) Verify all five `.entitlements` files are assigned to their respective Xcode targets — run `xcodebuild build -scheme App` and confirm zero "entitlement not found" build warnings; (2) Open `ios/App/Extensions/SMSFilter/MessageFilterExtension.swift` and confirm `SMSTriage.extensionInstance()` is initialised with `.cpuOnly` compute units (grep for `.cpuOnly` in the file — must appear at least once); (3) Run a static search for force-unwraps (`!`) in all files under `ios/App/Extensions/` — any `!` that is not a `guard let ... else` unwrap must be refactored to a safe `guard`/`if let` pattern; (4) Verify `ILMessageFilterExtension` memory stays under 50 MB and `CallDirectory` under 120 MB by running the tests from T-05-011 on CI; (5) Complete Spec 00 §11.2 (extension memory ceilings) and §11.4 (entitlements match capabilities) checklist items in the M5 PR description.

**Acceptance criteria:**
- [ ] `xcodebuild build -scheme App` completes with zero "entitlement not found" warnings
- [ ] `.cpuOnly` appears in `MessageFilterExtension.swift` (confirmed by grep)
- [ ] Zero force-unwraps (`!`) in `ios/App/Extensions/` outside of `guard let` patterns
- [ ] T-05-011 memory tests pass on CI simulator
- [ ] PR description contains completed Spec 00 §11.2 and §11.4 checklist

**Apple compliance (Spec 00 §11):**
- [ ] §11.2 — extension memory ceilings enforced: SMSFilter < 50 MB, all others < 120 MB
- [ ] §11.4 — entitlements in all five `.entitlements` files verified against Apple Developer portal capabilities

---

#### ⬜ T-05-015 · IMPLEMENT · P1 — CallKit pre-answer screening integration

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P1 |
| **Spec ref** | §4.2 — Mode B: CallKit Pre-Answer Screening |
| **Depends on** | T-05-004, T-04-008 |
| **Estimated effort** | M |
| **Files to create/modify** | `ios/App/Plugins/GemmaPlugin+CallKit.swift`, `ios/App/GemmaKit/Tests/CallKitScreeningTests.swift` |

**What to build:**
Create `ios/App/Plugins/GemmaPlugin+CallKit.swift` as an extension on `GemmaPlugin`. Implement `CXCallObserverDelegate` conformance to receive incoming call notifications. In `callObserver(_:callChanged:)`, when a new incoming call is detected: extract the caller's phone number from `CXCall.handle?.value`, compute `SHA256(phoneDigits)`, look up the hash in the `CallDirectoryExtension`'s scam phone list and also call `MCPClient.shared.call(server: "phone_reputation", tool: "check", input: ["text": phoneDigits], callerAgentId: .orchestrator)`. If the combined risk score exceeds 0.7, present a local notification banner via `UNUserNotificationCenter` with title "Suspected Scam Call" and the risk percentage. This is a static lookup only — no audio capture occurs. Register the `CXCallObserver` in `GemmaPlugin.load()` alongside MCP server registration. Create `CallKitScreeningTests.swift` verifying: a known scam number triggers the notification, an unknown number does not.

**Acceptance criteria:**
- [ ] `CXCallObserver` is registered during `GemmaPlugin.load()`
- [ ] Known scam phone hash triggers a `UNUserNotificationCenter` alert
- [ ] No audio capture or recording occurs — only static phone hash lookup
- [ ] `callerAgentId: .orchestrator` used for all MCP calls in this path

**Apple compliance (Spec 00 §11):**
- [ ] §11.3 — No raw phone number stored or logged; only SHA-256 hash used
- [ ] §11.4 — `NSContactsUsageDescription` covers caller identification use case

---

#### ⬜ T-05-016 · IMPLEMENT · P0 — URL scheme handler for deep links

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P0 |
| **Spec ref** | §3.3 — Share extension URL-scheme handoff; §3.4 — AppIntents URL handoff |
| **Depends on** | T-05-005, T-05-006, T-01-006 |
| **Estimated effort** | S |
| **Files to create/modify** | `ios/App/App/AppDelegate.swift` (or `SceneDelegate.swift`), `ios/App/App/Info.plist`, `src/app/analyse/page.tsx` |

**What to build:**
Register the `gemscan://` URL scheme in `Info.plist` under `CFBundleURLTypes` with `CFBundleURLSchemes: ["gemscan"]`. In `AppDelegate` (or `SceneDelegate`), implement `application(_:open:options:)` to handle `gemscan://analyse?task=<base64url>` URLs. Decode the `task` query parameter from base64url back to `AgentTask` JSON, then route to the analyse page via Capacitor's web view navigation. On the TypeScript side, update `src/app/analyse/page.tsx` to check `window.location.search` for a `task` parameter on mount — if present, decode and auto-trigger analysis. This is the bridge that makes ShareExtension (T-05-005) and AppIntents (T-05-006) hand-offs work end-to-end.

**Acceptance criteria:**
- [ ] `Info.plist` contains `CFBundleURLSchemes: ["gemscan"]`
- [ ] Opening `gemscan://analyse?task=<validBase64>` from Safari launches GemScan and navigates to `/analyse`
- [ ] Invalid base64 in the `task` parameter shows an error, does not crash
- [ ] `src/app/analyse/page.tsx` reads and decodes the `task` param on mount

**Apple compliance (Spec 00 §11):**
- [ ] §11.4 — URL scheme `gemscan` registered in `Info.plist`; no conflict with system URL schemes
