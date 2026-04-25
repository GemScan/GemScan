import UIKit
import MobileCoreServices
import os

/// Safari Content Blocker extension for GemScan.
///
/// Serves a JSON blocklist to Safari that blocks network requests to known
/// scam domains. The blocklist is generated from the same domain database
/// used by ``URLReputationServer``.
final class ContentBlockerRequestHandler: NSObject, NSExtensionRequestHandling {

    /// Logger for extension lifecycle events.
    private let logger = GemScanLogger.extensions

    func beginRequest(with context: NSExtensionContext) {
        logger.info("ContentBlocker: beginRequest")

        let blocklistJSON = generateBlocklistJSON()

        let attachment = NSItemProvider(
            item: blocklistJSON as NSSecureCoding,
            typeIdentifier: "public.json" as String
        )

        let item = NSExtensionItem()
        item.attachments = [attachment]

        context.completeRequest(returningItems: [item])
        logger.info("ContentBlocker: request completed")
    }

    // MARK: - Blocklist Generation

    /// Generates the Safari content blocker JSON rules.
    ///
    /// Each rule blocks all resource types from the specified scam domains.
    /// The format follows the WebKit Content Blocker specification.
    ///
    /// - Returns: The JSON data for the blocklist rules.
    private func generateBlocklistJSON() -> NSData {
        let domains = loadBlocklistDomains()
        var rules: [[String: Any]] = []

        for domain in domains {
            let rule: [String: Any] = [
                "trigger": [
                    "url-filter": ".*",
                    "if-domain": ["*\(domain)"],
                ],
                "action": [
                    "type": "block",
                ],
            ]
            rules.append(rule)
        }

        // Check for updated blocklist version from shared container
        if let defaults = UserDefaults(suiteName: SharedContainerSchema.appGroupId),
           let version = defaults.string(forKey: SharedContainerSchema.safariBlocklistVersion) {
            logger.info("ContentBlocker: using blocklist version \(version)")
        }

        guard let data = try? JSONSerialization.data(withJSONObject: rules, options: []) else {
            logger.error("ContentBlocker: failed to serialize blocklist JSON")
            // Return empty array as fallback
            return "[]".data(using: .utf8)! as NSData
        }

        logger.info("ContentBlocker: generated \(rules.count) blocking rules")
        return data as NSData
    }

    /// Loads blocklist domains from the bundle or shared container.
    private func loadBlocklistDomains() -> [String] {
        // Try shared container first (may have updated list)
        if let defaults = UserDefaults(suiteName: SharedContainerSchema.appGroupId),
           let domains = defaults.stringArray(forKey: "gemscan.safariBlocklistDomains") {
            return domains
        }

        // Fall back to bundled blocklist
        guard let url = Bundle.main.url(forResource: "blocklist", withExtension: "json") else {
            logger.warning("ContentBlocker: blocklist.json not found")
            return []
        }

        guard let data = try? Data(contentsOf: url),
              let domains = try? JSONDecoder().decode([String].self, from: data) else {
            logger.error("ContentBlocker: failed to decode blocklist.json")
            return []
        }

        return domains
    }
}
