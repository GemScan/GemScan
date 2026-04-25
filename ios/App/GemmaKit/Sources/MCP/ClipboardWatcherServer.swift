import Foundation
import UIKit
import os

/// MCP server that extracts risk signals from the current clipboard contents.
///
/// No raw clipboard content is ever returned through the MCP interface.
/// Only structural signals (URL count, phone presence, text length, risk indicators)
/// are exposed to agents.
public actor ClipboardWatcherServer: MCPServer {

    public let name = "clipboard_watcher"
    public let tools = ["get_clipboard_signals"]

    /// Logger for MCP operations.
    private let logger = GemScanLogger.mcp

    public init() {}

    public func handle(toolName: String, input: [String: Any]) async throws -> [String: Any] {
        switch toolName {
        case "get_clipboard_signals":
            return await getClipboardSignals()
        default:
            throw makeUnknownToolError(toolName)
        }
    }

    // MARK: - Tools

    /// Extracts risk signals from the current clipboard without exposing raw content.
    ///
    /// - Returns: Dictionary with `url_count` (Int), `has_phone` (Bool),
    ///   `text_length` (Int), and `risk_signals` ([String]).
    @MainActor
    private func getClipboardSignals() -> [String: Any] {
        let pasteboard = UIPasteboard.general
        var urlCount = 0
        var hasPhone = false
        var textLength = 0
        var riskSignals: [String] = []

        guard let text = pasteboard.string else {
            logger.info("get_clipboard_signals: no text on clipboard")
            return [
                "url_count": 0,
                "has_phone": false,
                "text_length": 0,
                "risk_signals": [] as [String],
            ]
        }

        textLength = text.count

        // Detect URLs
        if let urlDetector = try? NSDataDetector(
            types: NSTextCheckingResult.CheckingType.link.rawValue
        ) {
            let range = NSRange(text.startIndex..., in: text)
            let urlMatches = urlDetector.matches(in: text, range: range)
            urlCount = urlMatches.count
            if urlCount > 3 {
                riskSignals.append("many_urls")
            }
        }

        // Detect phone numbers
        if let phoneDetector = try? NSDataDetector(
            types: NSTextCheckingResult.CheckingType.phoneNumber.rawValue
        ) {
            let range = NSRange(text.startIndex..., in: text)
            let phoneMatches = phoneDetector.matches(in: text, range: range)
            hasPhone = !phoneMatches.isEmpty
            if hasPhone {
                riskSignals.append("contains_phone")
            }
        }

        // Long text might indicate a copied scam message
        if textLength > 500 {
            riskSignals.append("long_text")
        }

        logger.info("get_clipboard_signals: urls=\(urlCount) has_phone=\(hasPhone) len=\(textLength)")
        return [
            "url_count": urlCount,
            "has_phone": hasPhone,
            "text_length": textLength,
            "risk_signals": riskSignals,
        ]
    }

    // MARK: - Helpers

    private func makeUnknownToolError(_ tool: String) -> GemScanError {
        let err = NSError(domain: "com.gemscan.mcp", code: 404,
                          userInfo: [NSLocalizedDescriptionKey: "Unknown tool: \(tool)"])
        return .mcpToolFailed(server: name, tool: tool, underlying: err)
    }
}
