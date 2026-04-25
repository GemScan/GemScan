import os

/// Centralized namespace for all GemScan loggers.
///
/// Each static property targets a specific subsystem category,
/// making it easy to filter logs in Console.app or Instruments.
public enum GemScanLogger {
    /// Logger for on-device inference operations.
    public static let inference = Logger(subsystem: "com.gemscan", category: "inference")
    /// Logger for agent pipeline events.
    public static let agents = Logger(subsystem: "com.gemscan", category: "agents")
    /// Logger for MCP server communication.
    public static let mcp = Logger(subsystem: "com.gemscan", category: "mcp")
    /// Logger for task routing and scheduling.
    public static let router = Logger(subsystem: "com.gemscan", category: "router")
    /// Logger for app-extension lifecycle.
    public static let extensions = Logger(subsystem: "com.gemscan", category: "extensions")
    /// Logger for plugin loading and management.
    public static let plugin = Logger(subsystem: "com.gemscan", category: "plugin")
    /// Logger for UI-layer events.
    public static let ui = Logger(subsystem: "com.gemscan", category: "ui")
    /// Logger for metrics and telemetry collection.
    public static let metrics = Logger(subsystem: "com.gemscan", category: "metrics")
}
