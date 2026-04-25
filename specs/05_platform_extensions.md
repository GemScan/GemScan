# Spec 05 — Platform Extensions

---

## 1. Overview

GemScan integrates with platform message-routing infrastructure via native app extensions. These extensions run in **separate sandboxed processes** with strict memory ceilings and no direct access to the main app's model weights. They rely on the lightweight **DistilBERT SMS triage classifier** for real-time filtering and the **App Group shared container** for data exchange with the main app.

### Extension Inventory

| Extension | Platform | Memory ceiling | Model | Purpose |
|---|---|---|---|---|
| `ILMessageFilterExtension` | iOS | 50 MB total | DistilBERT (≤5 MB) | SMS unknown-sender triage |
| `CXCallDirectoryExtension` | iOS | 50 MB | DistilBERT | Incoming call label + blocking |
| `ShareExtension` | iOS | 120 MB | None (hands off to main app) | Share Sheet ingestion |
| `AppIntentsExtension` | iOS | 60 MB | None | Siri shortcut + widget integration |
| `SafariContentBlocker` | iOS | 6 MB list | None | In-Safari URL blocking |
| `SmsReceiver` (Broadcast) | Android | — | DistilBERT (TFLite) | SMS_RECEIVED intent handler |
| `CallScreeningService` | Android | — | DistilBERT (TFLite) | Incoming call screening |
| `ShareActivity` | Android | — | None | Android Share Sheet |

---

## 2. App Group Shared Container

All iOS extensions share data with the main app via an **App Group** container (`group.com.gemscan`). No extension can write model weights or inference results — it can only write compact triage results.

### Shared Data Schema

```swift
// GemmaKit/Sources/Extensions/SharedContainerSchema.swift
struct SharedContainerSchema {
    static let appGroupId = "group.com.gemscan"

    // Keys written by main app, read by extensions
    static let distilbertModelPath = "distilbert_model_path"    // Path to compiled .mlmodelc
    static let scamPatternsBundlePath = "scam_patterns_path"    // Path to patterns JSON
    static let userLanguageCode = "user_language_code"          // BCP-47

    // Keys written by extensions, read by main app
    static let pendingAnalysisTasks = "pending_analysis_tasks"  // JSON array of AgentTask stubs
    static let triageResultCache = "triage_result_cache"        // JSON dict: senderHash → TriageResult

    // Guardian mode status (read/write by main app and extensions)
    static let guardianModeEnabled = "guardian_mode_enabled"
    static let trustedContactId = "trusted_contact_id"
}

struct TriageResult: Codable {
    let senderHash: String      // SHA-256 of sender identifier
    let label: TriageLabel
    let confidence: Double
    let timestampMs: Int64
}

enum TriageLabel: String, Codable {
    case safe, junk, transaction, promotion, unknown
}
```

---

## 3. iOS Extensions

### 3.1 ILMessageFilterExtension — SMS Triage

The `ILMessageFilterExtension` is invoked by iOS for every SMS from an unknown sender. It must return a classification decision within **5 seconds** with a **50 MB RSS ceiling** (enforced by iOS).

```swift
// ios/App/Extensions/MessageFilter/MessageFilterExtension.swift
import IdentityLookup
import GemmaKit

final class MessageFilterExtension: ILMessageFilterExtension {}

extension MessageFilterExtension: ILMessageFilterQueryHandling {

    func handle(_ queryRequest: ILMessageFilterQueryRequest,
                context: ILMessageFilterExtensionContext,
                completion: @escaping (ILMessageFilterQueryResponse) -> Void) {

        let logger = Logger(subsystem: "com.gemscan.messagefilter", category: "SMSFilter")

        guard let messageBody = queryRequest.messageBody,
              let sender = queryRequest.sender else {
            completion(ILMessageFilterQueryResponse())    // Default: allow
            return
        }

        Task {
            do {
                let triage = try await SMSTriage.extensionInstance().classify(text: messageBody)
                logger.info("SMS triage: \(triage.label.rawValue) confidence=\(triage.confidence)")

                // Write result to shared container for main app context
                writeTriageResult(senderHash: sha256(sender), result: triage)

                let response = ILMessageFilterQueryResponse()
                switch triage.label {
                case .junk where triage.confidence > 0.90:
                    response.action = .junk
                case .transaction:
                    response.action = .transaction
                case .promotion:
                    response.action = .promotion
                default:
                    response.action = .none    // Don't filter; let main app do deep analysis
                }
                completion(response)
            } catch {
                logger.error("SMS triage failed: \(error)")
                completion(ILMessageFilterQueryResponse())    // Safe default: allow
            }
        }
    }

    func handle(_ networkRequest: ILMessageFilterNetworkRequest,
                context: ILMessageFilterExtensionContext,
                completion: @escaping (ILMessageFilterNetworkResponse, NSData?) -> Void) {
        // GemScan does not use network-based message filtering
        let response = ILMessageFilterNetworkResponse()
        completion(response, nil)
    }

    private func writeTriageResult(senderHash: String, result: TriageResult) {
        let defaults = UserDefaults(suiteName: SharedContainerSchema.appGroupId)
        var cache = (try? JSONDecoder().decode([String: TriageResult].self,
            from: defaults?.data(forKey: SharedContainerSchema.triageResultCache) ?? Data())) ?? [:]
        cache[senderHash] = result
        if let encoded = try? JSONEncoder().encode(cache) {
            defaults?.set(encoded, forKey: SharedContainerSchema.triageResultCache)
        }
    }
}
```

**Memory budget for SMS Filter extension:**
- DistilBERT `.mlmodelc`: ≤5 MB (compiled Core ML, `cpuOnly: true`)
- Extension process overhead: ~8–12 MB
- Text buffers and Swift runtime: ~10 MB
- **Total: well under 50 MB ceiling**

### 3.2 CXCallDirectoryExtension — Call Directory

Provides a local database of known scam phone numbers for system-level call labelling. The Call Directory extension does not perform real-time inference — it loads a pre-built list at install time and refreshes when GemScan updates it.

```swift
// ios/App/Extensions/CallDirectory/CallDirectoryHandler.swift
import CallKit

class CallDirectoryHandler: CXCallDirectoryProvider {

    override func beginRequest(with context: CXCallDirectoryExtensionContext) {
        let logger = Logger(subsystem: "com.gemscan.calldirectory", category: "CallDirectory")

        // Load known scam numbers from App Group shared container
        guard let defaults = UserDefaults(suiteName: SharedContainerSchema.appGroupId),
              let data = defaults.data(forKey: "known_scam_numbers"),
              let numbers = try? JSONDecoder().decode([ScamPhoneEntry].self, from: data) else {
            logger.warning("No scam number database found in shared container")
            context.completeRequest()
            return
        }

        logger.info("Loading \(numbers.count) scam numbers into Call Directory")

        // Add blocking entries — must be sorted ascending by phone number
        let sorted = numbers.sorted { $0.phoneNumber < $1.phoneNumber }
        for entry in sorted where entry.shouldBlock {
            context.addBlockingEntry(withNextSequentialPhoneNumber: entry.phoneNumber)
        }

        // Add identification labels
        for entry in sorted where !entry.shouldBlock {
            context.addIdentificationEntry(
                withNextSequentialPhoneNumber: entry.phoneNumber,
                label: entry.label    // e.g. "Suspected Scam — GemScan"
            )
        }

        context.completeRequest()
    }
}

struct ScamPhoneEntry: Codable {
    let phoneNumber: Int64    // E.164 format as integer (required by CX API)
    let label: String
    let shouldBlock: Bool
    let reportCount: Int
}
```

### 3.3 ShareExtension

Receives content from the iOS Share Sheet (URLs, text, images) and hands it off to the main GemScan app for deep analysis. The Share Extension does **not** run inference — it only validates the payload type and passes it via a deeplink.

```swift
// ios/App/Extensions/Share/ShareViewController.swift
import UIKit
import Social
import UniformTypeIdentifiers

class ShareViewController: UIViewController {
    private let logger = Logger(subsystem: "com.gemscan.share", category: "ShareExtension")

    override func viewDidLoad() {
        super.viewDidLoad()
        Task { await processSharedContent() }
    }

    private func processSharedContent() async {
        guard let extensionContext else { return }

        for item in extensionContext.inputItems as? [NSExtensionItem] ?? [] {
            for provider in item.attachments ?? [] {
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    await handleURL(provider: provider)
                } else if provider.hasItemConformingToTypeIdentifier(UTType.text.identifier) {
                    await handleText(provider: provider)
                } else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    await handleImage(provider: provider)
                }
            }
        }
    }

    private func handleURL(provider: NSItemProvider) async {
        do {
            let item = try await provider.loadItem(forTypeIdentifier: UTType.url.identifier)
            guard let url = item as? URL else { return }
            logger.info("Share: URL received [\(url.host ?? "unknown host")]")
            openMainApp(with: "gemscan://analyse?type=url&url=\(url.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")
        } catch {
            logger.error("Share URL load failed: \(error)")
        }
    }

    private func handleText(provider: NSItemProvider) async {
        do {
            let item = try await provider.loadItem(forTypeIdentifier: UTType.text.identifier)
            guard let text = item as? String else { return }
            logger.info("Share: Text received [\(text.count) chars]")
            // Store in shared container, then open app
            storeSharedText(text)
            openMainApp(with: "gemscan://analyse?type=text")
        } catch {
            logger.error("Share text load failed: \(error)")
        }
    }

    private func handleImage(provider: NSItemProvider) async {
        do {
            let item = try await provider.loadItem(forTypeIdentifier: UTType.image.identifier)
            guard let image = item as? UIImage,
                  let jpeg = image.jpegData(compressionQuality: 0.8) else { return }
            logger.info("Share: Image received [\(jpeg.count) bytes]")
            storeSharedImage(jpeg)
            openMainApp(with: "gemscan://analyse?type=image")
        } catch {
            logger.error("Share image load failed: \(error)")
        }
    }

    private func openMainApp(with urlString: String) {
        guard let url = URL(string: urlString) else { return }
        extensionContext?.open(url, completionHandler: nil)
        extensionContext?.completeRequest(returningItems: nil)
    }

    private func storeSharedText(_ text: String) {
        let defaults = UserDefaults(suiteName: SharedContainerSchema.appGroupId)
        defaults?.set(text, forKey: "shared_text_pending")
    }

    private func storeSharedImage(_ jpeg: Data) {
        let defaults = UserDefaults(suiteName: SharedContainerSchema.appGroupId)
        defaults?.set(jpeg, forKey: "shared_image_pending")
    }
}
```

### 3.4 App Intents Extension (Siri + Widgets)

```swift
// ios/App/Extensions/AppIntents/GemScanIntents.swift
import AppIntents

struct CheckClipboardIntent: AppIntent {
    static var title: LocalizedStringResource = "Check Clipboard for Scams"
    static var description: IntentDescription = "GemScan analyses your clipboard for scam content."

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Trigger the main app via URL scheme
        let url = URL(string: "gemscan://analyse?type=clipboard")!
        await UIApplication.shared.open(url)
        return .result(dialog: "Opening GemScan to check your clipboard.")
    }
}

struct GemScanShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CheckClipboardIntent(),
            phrases: ["Check clipboard with \(.applicationName)", "Is this a scam \(.applicationName)"],
            shortTitle: "Check for Scams",
            systemImageName: "shield.checkerboard"
        )
    }
}
```

### 3.5 Safari Content Blocker

Blocks known-scam URLs inside Safari using the bundled blocklist. Updated via OTA signed JSON bundles. Memory ceiling: 6 MB for the entire content blocker rules list.

```swift
// ios/App/Extensions/SafariBlocker/ContentBlockerRequestHandler.swift
import SafariServices

class ContentBlockerRequestHandler: NSObject, NSExtensionRequestHandling {
    func beginRequest(with context: NSExtensionContext) {
        let logger = Logger(subsystem: "com.gemscan.safariblock", category: "ContentBlocker")

        // Load blocklist from App Group container (written by main app on OTA update)
        let defaults = UserDefaults(suiteName: SharedContainerSchema.appGroupId)
        guard let rulesData = defaults?.data(forKey: "safari_content_blocker_rules"),
              let rulesURL = writeRulesToTemporaryFile(data: rulesData) else {
            logger.warning("No content blocker rules found")
            context.completeRequest(returningItems: nil)
            return
        }

        logger.info("Loaded content blocker rules [\(rulesData.count) bytes]")
        let attachment = NSItemProvider(contentsOf: rulesURL)!
        let item = NSExtensionItem()
        item.attachments = [attachment]
        context.completeRequest(returningItems: [item])
    }

    private func writeRulesToTemporaryFile(data: Data) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("blockerrules.json")
        do {
            try data.write(to: url)
            return url
        } catch {
            return nil
        }
    }
}
```

---

## 4. Voice Agent Audio Platform Constraints

> **Critical:** iOS strictly prohibits recording the far end of a live phone call without carrier-level consent. GemScan operates in three legally compliant modes only.

### Mode A — Post-Call Near-End Audio (Primary)

The user records their own side of the call using the microphone, then taps "Check this call" after hanging up. This captures any information the scammer conveyed (since the user recites or describes it).

```swift
// Activation: user taps "Record my call notes" button in active mode
// Implementation: AVAudioEngine recording of microphone input only
// Privacy: recording starts only on user tap, stops on tap; no background recording
```

### Mode B — CallKit Pre-Answer Screening

Before answering an incoming call, GemScan checks the caller's phone number against the local reputation database and the DistilBERT-driven Call Directory. This is a **static lookup only** — no audio is captured.

```swift
// CXCallDirectoryExtension provides pre-populated labels
// Main app's CXProvider delegate receives incoming call notification
// UI shows "Suspected Scam" banner before user answers
// No audio involved — purely metadata-based
```

### Mode C — User-Initiated Share (Audio Clip)

The user explicitly shares an audio file (e.g., a scam voicemail) with GemScan via the Share Sheet or Files app. The user consents to analysis by initiating the share.

```swift
// ShareExtension receives audio/m4a or audio/mpeg
// Passes to VoiceAgent for transcript + deepfake analysis
// User sees explicit confirmation dialog before analysis begins
```

**AudioSeal integration note:** AudioSeal deepfake detection runs on-device via an MLX-compiled model. It requires the audio waveform in float32 format. The VoiceAgent converts the base64 payload before passing to `AudioSealDetector.shared.score()`.

---

## 5. Android Extensions

### 5.1 SMS Broadcast Receiver

```kotlin
// android/app/src/main/kotlin/com/gemscan/router/SmsReceiver.kt
package com.gemscan.router

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import android.util.Log
import com.gemscan.inference.DistilBertTriage
import kotlinx.coroutines.*

class SmsReceiver : BroadcastReceiver() {
    companion object { private const val TAG = "GemScan/SmsReceiver" }

    private val scope = CoroutineScope(Dispatchers.Default + SupervisorJob())

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return

        val pendingResult = goAsync()
        val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)

        scope.launch {
            try {
                for (message in messages) {
                    val body = message.messageBody ?: continue
                    val sender = message.originatingAddress ?: continue
                    val triage = DistilBertTriage.getInstance(context).classify(body)
                    Log.i(TAG, "SMS triage: ${triage.label} sender=[${sender.length} chars]")

                    if (triage.label == TriageLabel.JUNK && triage.confidence > 0.90) {
                        // Notify main app to show scam warning
                        sendWarningBroadcast(context, sender, triage)
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "SMS triage failed: ${e.message}")
            } finally {
                pendingResult.finish()
            }
        }
    }

    private fun sendWarningBroadcast(context: Context, sender: String, triage: TriageResult) {
        val intent = Intent("com.gemscan.SMS_SCAM_WARNING").apply {
            putExtra("sender_length", sender.length)
            putExtra("confidence", triage.confidence.toFloat())
            putExtra("label", triage.label.name)
        }
        context.sendBroadcast(intent)
    }
}
```

### 5.2 Call Screening Service

```kotlin
// android/app/src/main/kotlin/com/gemscan/router/GemScanCallScreeningService.kt
package com.gemscan.router

import android.telecom.Call
import android.telecom.CallScreeningService
import android.util.Log
import com.gemscan.mcp.PhoneReputationServer
import kotlinx.coroutines.*

class GemScanCallScreeningService : CallScreeningService() {
    companion object { private const val TAG = "GemScan/CallScreening" }

    private val scope = CoroutineScope(Dispatchers.Default + SupervisorJob())

    override fun onScreenCall(callDetails: Call.Details) {
        scope.launch {
            val number = callDetails.handle?.schemeSpecificPart ?: run {
                respondToCall(callDetails, buildResponse(shouldBlock = false))
                return@launch
            }

            val reputationResult = PhoneReputationServer().execute("check", mapOf(
                "transcript_excerpt" to number.take(20)
            ))
            val riskScore = reputationResult["max_risk_score"]?.toDoubleOrNull() ?: 0.0

            Log.i(TAG, "Call screening risk_score=$riskScore number_len=${number.length}")

            val response = buildResponse(
                shouldBlock = riskScore > 0.90,
                shouldReject = riskScore > 0.75,
                callScreeningAppName = "GemScan"
            )
            respondToCall(callDetails, response)
        }
    }

    private fun buildResponse(
        shouldBlock: Boolean = false,
        shouldReject: Boolean = false,
        callScreeningAppName: String? = null
    ): CallResponse {
        return CallResponse.Builder()
            .setDisallowCall(shouldBlock)
            .setRejectCall(shouldReject)
            .setSkipCallLog(false)
            .build()
    }
}
```

---

## 6. Extension Memory Budget Summary

| Extension | Process ceiling | DistilBERT | Runtime overhead | Headroom |
|---|---|---|---|---|
| ILMessageFilterExtension | 50 MB | 5 MB | 12 MB | 33 MB |
| CXCallDirectoryExtension | 50 MB | 0 MB (list only) | 8 MB | 42 MB |
| ShareExtension | 120 MB | 0 MB | 15 MB | 105 MB |
| AppIntentsExtension | 60 MB | 0 MB | 10 MB | 50 MB |
| SafariContentBlocker | 6 MB rules | 0 MB | — | — |

---

## 7. Extension Testing Checklist

- [ ] `ILMessageFilterExtension` returns `.junk` for known scam SMS (XCUITest)
- [ ] `ILMessageFilterExtension` stays under 45 MB RSS for 1000 sequential classifications (XCTest memory test)
- [ ] `CXCallDirectoryExtension` loads 10,000 entries without crash
- [ ] ShareExtension passes URL payload to main app via deeplink (XCUITest: Share Sheet flow)
- [ ] ShareExtension passes image payload via App Group shared container
- [ ] `GemScanIntents` registers with Siri (XCUITest: invoke shortcut)
- [ ] SafariContentBlocker rules load without exceeding 6 MB file size limit
- [ ] Android `SmsReceiver` fires broadcast on junk classification (JUnit 5 + MockK)
- [ ] Android `GemScanCallScreeningService` blocks calls with risk score > 0.90 (JUnit 5)
- [ ] App Group `group.com.gemscan` entitlement present in all extension targets (CI check)
