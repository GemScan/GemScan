import UIKit
import os

/// GemScan application delegate.
///
/// Handles the `gemscan://` URL scheme for deep links from extensions
/// (Share Extension, Shortcuts, notifications) and configures app-level
/// services at launch.
@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    /// Logger for app-level events.
    private let logger = GemScanLogger.ui

    // MARK: - UIApplicationDelegate

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        logger.info("GemScan: didFinishLaunchingWithOptions")

        // Process any pending analysis tasks from extensions
        processPendingExtensionTasks()

        return true
    }

    /// Handles incoming URLs for the `gemscan://` scheme.
    ///
    /// Supported routes:
    /// - `gemscan://analyse?task=<taskId>` — Analyse a shared item from an extension
    /// - `gemscan://scan?url=<encodedURL>` — Direct URL scan
    /// - `gemscan://verdict?id=<resultId>` — View a previous verdict
    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        logger.info("GemScan: open URL — \(url.scheme ?? "nil")://\(url.host ?? "nil")")

        guard url.scheme == "gemscan" else {
            logger.warning("GemScan: unsupported URL scheme: \(url.scheme ?? "nil")")
            return false
        }

        guard let host = url.host else {
            logger.warning("GemScan: URL has no host component")
            return false
        }

        let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let params = Dictionary(
            uniqueKeysWithValues: queryItems.compactMap { item in
                guard let value = item.value else { return nil }
                return (item.name, value)
            }
        )

        switch host {
        case "analyse":
            return handleAnalyseDeepLink(params: params)
        case "scan":
            return handleScanDeepLink(params: params)
        case "verdict":
            return handleVerdictDeepLink(params: params)
        default:
            logger.warning("GemScan: unknown deep link route: \(host)")
            return false
        }
    }

    // MARK: - UISceneSession

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        return UISceneConfiguration(
            name: "Default Configuration",
            sessionRole: connectingSceneSession.role
        )
    }

    // MARK: - Deep Link Handlers

    /// Handles the `gemscan://analyse?task=<taskId>` deep link.
    ///
    /// Retrieves the pending analysis task from the shared container
    /// and dispatches it to the agent pipeline.
    private func handleAnalyseDeepLink(params: [String: String]) -> Bool {
        guard let taskId = params["task"] else {
            logger.warning("analyse deep link: missing 'task' parameter")
            return false
        }

        logger.info("analyse deep link: task=\(taskId)")

        guard let defaults = UserDefaults(suiteName: SharedContainerSchema.appGroupId) else {
            logger.error("analyse deep link: App Group defaults not available")
            return false
        }

        // Find and remove the pending task
        var pending = defaults.array(forKey: SharedContainerSchema.pendingAnalysisTasks) as? [[String: Any]] ?? []
        guard let taskIndex = pending.firstIndex(where: { ($0["id"] as? String) == taskId }) else {
            logger.warning("analyse deep link: task \(taskId) not found in pending list")
            return false
        }

        let taskPayload = pending[taskIndex]
        pending.remove(at: taskIndex)
        defaults.set(pending, forKey: SharedContainerSchema.pendingAnalysisTasks)

        // Post notification for the UI layer to pick up
        NotificationCenter.default.post(
            name: .gemScanAnalyseTaskReceived,
            object: nil,
            userInfo: taskPayload
        )

        return true
    }

    /// Handles the `gemscan://scan?url=<encodedURL>` deep link.
    private func handleScanDeepLink(params: [String: String]) -> Bool {
        guard let urlString = params["url"] else {
            logger.warning("scan deep link: missing 'url' parameter")
            return false
        }

        logger.info("scan deep link: url length=\(urlString.count)")

        NotificationCenter.default.post(
            name: .gemScanScanURLReceived,
            object: nil,
            userInfo: ["url": urlString]
        )

        return true
    }

    /// Handles the `gemscan://verdict?id=<resultId>` deep link.
    private func handleVerdictDeepLink(params: [String: String]) -> Bool {
        guard let resultId = params["id"] else {
            logger.warning("verdict deep link: missing 'id' parameter")
            return false
        }

        logger.info("verdict deep link: id=\(resultId)")

        NotificationCenter.default.post(
            name: .gemScanVerdictViewRequested,
            object: nil,
            userInfo: ["resultId": resultId]
        )

        return true
    }

    // MARK: - Extension Task Processing

    /// Processes any pending analysis tasks left by extensions.
    private func processPendingExtensionTasks() {
        guard let defaults = UserDefaults(suiteName: SharedContainerSchema.appGroupId) else {
            return
        }

        let pending = defaults.array(forKey: SharedContainerSchema.pendingAnalysisTasks) as? [[String: Any]] ?? []

        if !pending.isEmpty {
            logger.info("Found \(pending.count) pending extension task(s)")
        }

        // Tasks will be processed when the UI layer is ready and observes the notification
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when an analyse task is received via deep link from an extension.
    static let gemScanAnalyseTaskReceived = Notification.Name("com.gemscan.analyseTaskReceived")
    /// Posted when a direct URL scan is requested via deep link.
    static let gemScanScanURLReceived = Notification.Name("com.gemscan.scanURLReceived")
    /// Posted when a verdict view is requested via deep link.
    static let gemScanVerdictViewRequested = Notification.Name("com.gemscan.verdictViewRequested")
}
