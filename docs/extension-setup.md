# iOS Extension Development Guide

How to develop, debug, and test GemScan's five iOS extensions.

---

## App Group

All extensions share data through a single App Group:

```
group.com.gemscan
```

This is configured in each target's **Signing & Capabilities** tab in Xcode and in the corresponding `.entitlements` file.

### SharedContainerSchema

Data shared between the main app and extensions is stored in the App Group container using `UserDefaults(suiteName:)` and file-based storage.

| Key | Type | Description |
|-----|------|-------------|
| `filterEnabled` | `Bool` | SMS filter active state |
| `blockListVersion` | `Int` | Current phone block list version |
| `safariRulesVersion` | `Int` | Safari blocker rules version |
| `guardianPublicKey` | `Data` | Ed25519 public key for Guardian Mode |
| `scanHistory` | `[Data]` | Recent scan results (last 100) |
| `userSensitivity` | `String` | low / medium / high |
| `modelManifest` | `Data` | Current model manifest JSON |

Access pattern:

```swift
let defaults = UserDefaults(suiteName: "group.com.gemscan")!
let enabled = defaults.bool(forKey: "filterEnabled")
```

For larger data, use the shared container directory:

```swift
let container = FileManager.default
    .containerURL(forSecurityApplicationGroupIdentifier: "group.com.gemscan")!
let modelPath = container.appendingPathComponent("models/distilbert.mlmodel")
```

---

## SMS Filter Extension

**Target:** `GemScanSMSFilter`
**Framework:** `IdentityLookup`
**Model:** DistilBERT (66M parameters, ~50 MB)

### Constraints

| Constraint | Limit |
|-----------|-------|
| Memory | 50 MB ceiling |
| Time | 5-second window per message |
| Network | None (offline only) |
| Storage | App Group shared container |

### How It Works

1. System delivers unknown sender messages to `MessageFilterExtension`.
2. Extension loads DistilBERT from shared container.
3. Runs inference on message text.
4. Returns `.allow`, `.junk`, or `.promotion` within 5 seconds.

```swift
class MessageFilterExtension: ILMessageFilterExtension {
    override func handle(
        _ queryRequest: ILMessageFilterQueryRequest,
        context: ILMessageFilterExtensionContext,
        completion: @escaping (ILMessageFilterQueryResponse) -> Void
    ) {
        let response = ILMessageFilterQueryResponse()
        let verdict = DistilBERTClassifier.shared.classify(queryRequest.messageBody ?? "")
        response.action = verdict == .scam ? .junk : .allow
        completion(response)
    }
}
```

### Testing

```bash
# Unit test the classifier in isolation
xcodebuild test -scheme GemScanSMSFilterTests \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

Manual testing: **Settings > Messages > Unknown & Spam > GemScan** must be enabled on device.

---

## Call Directory Extension

**Target:** `GemScanCallDirectory`
**Framework:** `CallKit`

### Phone Number Format

CallKit requires phone numbers as `Int64` in E.164 format without the `+` prefix:

```swift
// "+1 (555) 867-5309" → 15558675309
let number: CXCallDirectoryPhoneNumber = 15558675309
```

Numbers must be added in **ascending numerical order** or the extension will fail silently.

### Implementation

```swift
class CallDirectoryHandler: CXCallDirectoryProvider {
    override func beginRequest(with context: CXCallDirectoryExtensionContext) {
        let numbers = loadBlockedNumbers() // from App Group
        for number in numbers.sorted() {
            context.addBlockingEntry(withNextSequentialPhoneNumber: number)
        }
        context.addIdentificationEntry(
            withNextSequentialPhoneNumber: 15550001234,
            label: "Suspected Scam"
        )
        context.completeRequest()
    }
}
```

### Testing

- Use `CXCallDirectoryManager.sharedInstance.reloadExtension(withIdentifier:)` to trigger a reload.
- Verify in **Settings > Phone > Call Blocking & Identification**.

---

## Share Extension

**Target:** `GemScanShare`
**Framework:** `Social` / `UIKit`

### Accepted Payload Types

| UTI | Description |
|-----|-------------|
| `public.plain-text` | Text messages, URLs |
| `public.url` | Web links |
| `public.image` | Screenshots, photos |

### Deep Linking

After receiving shared content, the extension saves it to the App Group container and opens the main app via URL scheme:

```swift
let url = URL(string: "gemscan://scan?source=share&id=\(taskId)")!
extensionContext?.open(url)
```

### Memory Limit

Share extensions have a 120 MB memory ceiling. Image payloads are resized to 1024x1024 max before processing.

---

## App Intents (Siri / Shortcuts)

**Target:** Main app (AppIntents framework)
**Minimum iOS:** 16.0

### Available Intents

| Intent | Phrase | Action |
|--------|--------|--------|
| `ScanTextIntent` | "Scan this message with GemScan" | Analyze text for scams |
| `CheckURLIntent` | "Check this link with GemScan" | URL reputation check |
| `ToggleFilterIntent` | "Turn on GemScan filter" | Enable/disable SMS filter |

### Implementation

```swift
struct ScanTextIntent: AppIntent {
    static var title: LocalizedStringResource = "Scan Text"
    
    @Parameter(title: "Message")
    var message: String
    
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let result = await OrchestratorAgent.shared.scan(.text(message))
        return .result(value: result.verdict.rawValue)
    }
}
```

### Testing

- Open Shortcuts app and create a shortcut using GemScan actions.
- Test via Siri: "Hey Siri, scan this message with GemScan."

---

## Safari Content Blocker

**Target:** `GemScanSafariBlocker`
**Framework:** `SafariServices`

### JSON Rules Format

The blocker uses a JSON rule list stored in the extension bundle:

```json
[
    {
        "trigger": {
            "url-filter": "evil-phishing-site\\.com"
        },
        "action": {
            "type": "block"
        }
    },
    {
        "trigger": {
            "url-filter": ".*",
            "if-domain": ["known-scam.net", "fake-bank.org"]
        },
        "action": {
            "type": "block"
        }
    }
]
```

Rules are regenerated from the MCP URLReputation server's block list and synced to the extension via the App Group container.

### Updating Rules

```swift
SFContentBlockerManager.reloadContentBlocker(
    withIdentifier: "com.gemscan.safari-blocker"
) { error in
    if let error { os_log(.error, "Reload failed: \(error)") }
}
```

Rule list maximum: **50,000 entries** (Safari limit).

---

## Debugging Extensions in Xcode

1. **Attach to process:** In Xcode, go to **Debug > Attach to Process by PID or Name** and enter the extension's bundle ID.
2. **Use breakpoints:** Set breakpoints in extension code; they will hit when the system activates the extension.
3. **Console logs:** Filter by subsystem `com.gemscan` in Console.app.
4. **SMS Filter debugging:** Send a test message from a number not in Contacts to trigger the filter.

### Common Debugging Issues

- Extensions run in a **separate process** — main app breakpoints will not hit.
- Memory limit violations cause silent termination with no crash log. Use **Instruments > Allocations** to profile.
- Call Directory extensions fail silently if numbers are not sorted ascending.

---

## Entitlement Files

Each extension target has its own `.entitlements` file:

```
ios/App/GemScanSMSFilter/GemScanSMSFilter.entitlements
ios/App/GemScanCallDirectory/GemScanCallDirectory.entitlements
ios/App/GemScanShare/GemScanShare.entitlements
ios/App/GemScanSafariBlocker/GemScanSafariBlocker.entitlements
```

Required entitlements per extension:

| Extension | Entitlements |
|-----------|-------------|
| SMS Filter | App Groups, com.apple.developer.networking.networkextension |
| Call Directory | App Groups |
| Share | App Groups |
| App Intents | (none beyond standard) |
| Safari Blocker | App Groups |

### Provisioning

Each extension requires its own provisioning profile. See `docs/secrets.md` for CI setup.
