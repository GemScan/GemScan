import Foundation
import os

/// MCP server that provides session context signals for risk adjustment.
///
/// Returns time-of-day, session duration, and notification pressure indicators
/// that agents use to adjust scam probability thresholds (e.g., late-night
/// sessions under high notification pressure are more susceptible).
public actor ScreenTimeServer: MCPServer {

    public let name = "screen_time"
    public let tools = ["get_session_context"]

    /// Logger for MCP operations.
    private let logger = GemScanLogger.mcp

    /// Session start timestamp, set when the server is initialized.
    private let sessionStart: Date

    public init() {
        self.sessionStart = Date()
    }

    public func handle(toolName: String, input: [String: Any]) async throws -> [String: Any] {
        switch toolName {
        case "get_session_context":
            return getSessionContext()
        default:
            throw makeUnknownToolError(toolName)
        }
    }

    // MARK: - Tools

    /// Returns the current session context for risk-factor adjustment.
    ///
    /// - Returns: Dictionary with `session_duration_min` (Double),
    ///   `time_of_day` (String: "morning", "afternoon", "evening", "night"),
    ///   and `notification_pressure` (Double 0-1).
    private func getSessionContext() -> [String: Any] {
        let now = Date()
        let durationMinutes = now.timeIntervalSince(sessionStart) / 60.0

        // Determine time-of-day bucket
        let hour = Calendar.current.component(.hour, from: now)
        let timeOfDay: String
        switch hour {
        case 6..<12:
            timeOfDay = "morning"
        case 12..<17:
            timeOfDay = "afternoon"
        case 17..<21:
            timeOfDay = "evening"
        default:
            timeOfDay = "night"
        }

        // Estimate notification pressure from session duration and time of day.
        // Longer sessions and late-night hours correlate with higher pressure.
        var pressure: Double = 0.0
        if durationMinutes > 30 { pressure += 0.2 }
        if durationMinutes > 60 { pressure += 0.2 }
        if timeOfDay == "night" { pressure += 0.3 }
        if timeOfDay == "evening" { pressure += 0.1 }
        pressure = min(1.0, pressure)

        logger.info("get_session_context: duration=\(String(format: "%.1f", durationMinutes))m tod=\(timeOfDay) pressure=\(String(format: "%.2f", pressure))")
        return [
            "session_duration_min": durationMinutes,
            "time_of_day": timeOfDay,
            "notification_pressure": pressure,
        ]
    }

    // MARK: - Helpers

    private func makeUnknownToolError(_ tool: String) -> GemScanError {
        let err = NSError(domain: "com.gemscan.mcp", code: 404,
                          userInfo: [NSLocalizedDescriptionKey: "Unknown tool: \(tool)"])
        return .mcpToolFailed(server: name, tool: tool, underlying: err)
    }
}
