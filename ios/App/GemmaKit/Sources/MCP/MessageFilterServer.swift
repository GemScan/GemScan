import Foundation
import os

/// MCP server that bridges to App Group shared data for message filter state.
///
/// Provides sender history, user overrides, and scan counts stored by
/// the ``ILMessageFilterExtension`` and main app in the shared container.
public actor MessageFilterServer: MCPServer {

    public let name = "message_filter"
    public let tools = ["check_sender_history"]

    /// Logger for MCP operations.
    private let logger = GemScanLogger.mcp

    /// Shared UserDefaults for the App Group container.
    private let sharedDefaults: UserDefaults?

    public init() {
        self.sharedDefaults = UserDefaults(suiteName: SharedContainerSchema.appGroupId)
    }

    public func handle(toolName: String, input: [String: Any]) async throws -> [String: Any] {
        switch toolName {
        case "check_sender_history":
            return checkSenderHistory(input: input)
        default:
            throw makeUnknownToolError(toolName)
        }
    }

    // MARK: - Tools

    /// Checks the history for a sender hash in the shared container.
    ///
    /// - Parameter input: Dictionary with `sender_hash` key (SHA-256 hex string).
    /// - Returns: Dictionary with `previous_verdict` (String or nil),
    ///   `user_allowed` (Bool), and `scan_count` (Int).
    private func checkSenderHistory(input: [String: Any]) -> [String: Any] {
        guard let senderHash = input["sender_hash"] as? String else {
            logger.warning("check_sender_history: missing sender_hash")
            return ["previous_verdict": NSNull(), "user_allowed": false, "scan_count": 0]
        }

        guard let defaults = sharedDefaults else {
            logger.warning("check_sender_history: App Group defaults not available")
            return ["previous_verdict": NSNull(), "user_allowed": false, "scan_count": 0]
        }

        // Read sender-specific data from shared container
        let verdictKey = "gemscan.verdict.\(senderHash)"
        let allowedKey = "gemscan.allowed.\(senderHash)"
        let countKey = "gemscan.scanCount.\(senderHash)"

        let previousVerdict = defaults.string(forKey: verdictKey)
        let userAllowed = defaults.bool(forKey: allowedKey)
        let scanCount = defaults.integer(forKey: countKey)

        logger.info("check_sender_history: hash_prefix=\(String(senderHash.prefix(8)))… verdict=\(previousVerdict ?? "none") count=\(scanCount)")

        let verdictValue: Any = previousVerdict.map { $0 as Any } ?? NSNull()
        return [
            "previous_verdict": verdictValue,
            "user_allowed": userAllowed,
            "scan_count": scanCount,
        ]
    }

    // MARK: - Helpers

    private func makeUnknownToolError(_ tool: String) -> GemScanError {
        let err = NSError(domain: "com.gemscan.mcp", code: 404,
                          userInfo: [NSLocalizedDescriptionKey: "Unknown tool: \(tool)"])
        return .mcpToolFailed(server: name, tool: tool, underlying: err)
    }
}
