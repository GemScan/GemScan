import Foundation
import os

/// Structured log events emitted throughout the GemScan pipeline.
///
/// Each case formats a human-readable, PII-free log string suitable for
/// `os_log` and Console.app filtering. Events are categorized by subsystem
/// so they can be independently enabled or silenced.
public enum LogEvent: CustomStringConvertible, Sendable {

    // MARK: - Model Lifecycle

    /// A model tier was successfully loaded into memory.
    case modelLoaded(tier: ModelTier, loadTimeMs: Int)
    /// A model tier was unloaded from memory.
    case modelUnloaded(tier: ModelTier)

    // MARK: - Task Lifecycle

    /// An agent task was dispatched into the pipeline.
    case taskStarted(taskId: String, type: AgentTaskType)
    /// An agent task completed with a verdict.
    case taskCompleted(taskId: String, verdict: ScamVerdict, latencyMs: Int)

    // MARK: - Tool Calls

    /// An MCP tool call began.
    case toolCallStarted(server: String, tool: String)
    /// An MCP tool call completed.
    case toolCallCompleted(server: String, tool: String, durationMs: Int, success: Bool)

    // MARK: - Escalation

    /// A task was escalated from E2B to E4B due to low confidence.
    case escalation(taskId: String, fromTier: ModelTier, toTier: ModelTier, confidence: Double)

    // MARK: - Verdict

    /// A final verdict was produced and delivered to the UI.
    case verdictProduced(taskId: String, verdict: ScamVerdict, confidence: Double, modelTier: ModelTier)

    // MARK: - Thermal

    /// The device downgraded operations due to thermal pressure.
    case thermalDowngrade(from: ProcessInfo.ThermalState, to: ProcessInfo.ThermalState)

    // MARK: - CustomStringConvertible

    public var description: String {
        switch self {
        case let .modelLoaded(tier, loadTimeMs):
            return "[model] Loaded \(tier.rawValue) in \(loadTimeMs)ms"
        case let .modelUnloaded(tier):
            return "[model] Unloaded \(tier.rawValue)"
        case let .taskStarted(taskId, type):
            return "[task] Started \(taskId) type=\(type.rawValue)"
        case let .taskCompleted(taskId, verdict, latencyMs):
            return "[task] Completed \(taskId) verdict=\(verdict.rawValue) latency=\(latencyMs)ms"
        case let .toolCallStarted(server, tool):
            return "[mcp] Tool call started: \(server)/\(tool)"
        case let .toolCallCompleted(server, tool, durationMs, success):
            let status = success ? "ok" : "failed"
            return "[mcp] Tool call completed: \(server)/\(tool) duration=\(durationMs)ms status=\(status)"
        case let .escalation(taskId, fromTier, toTier, confidence):
            return "[escalation] Task \(taskId) escalated \(fromTier.rawValue)->\(toTier.rawValue) confidence=\(String(format: "%.2f", confidence))"
        case let .verdictProduced(taskId, verdict, confidence, modelTier):
            return "[verdict] Task \(taskId) verdict=\(verdict.rawValue) confidence=\(String(format: "%.2f", confidence)) model=\(modelTier.rawValue)"
        case let .thermalDowngrade(from, to):
            return "[thermal] Downgrade from \(LogEvent.thermalName(from)) to \(LogEvent.thermalName(to))"
        }
    }

    // MARK: - Helpers

    /// Emits this event to the appropriate GemScan logger at the info level.
    public func emit() {
        let logger = Self.logger(for: self)
        logger.info("\(self.description)")
    }

    /// Emits this event at the warning level.
    public func emitWarning() {
        let logger = Self.logger(for: self)
        logger.warning("\(self.description)")
    }

    /// Emits this event at the error level.
    public func emitError() {
        let logger = Self.logger(for: self)
        logger.error("\(self.description)")
    }

    // MARK: - Private

    /// Selects the appropriate logger category for this event.
    private static func logger(for event: LogEvent) -> Logger {
        switch event {
        case .modelLoaded, .modelUnloaded:
            return GemScanLogger.inference
        case .taskStarted, .taskCompleted:
            return GemScanLogger.router
        case .toolCallStarted, .toolCallCompleted:
            return GemScanLogger.mcp
        case .escalation, .verdictProduced:
            return GemScanLogger.agents
        case .thermalDowngrade:
            return GemScanLogger.metrics
        }
    }

    /// Returns a human-readable name for a thermal state.
    private static func thermalName(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal:  return "nominal"
        case .fair:     return "fair"
        case .serious:  return "serious"
        case .critical: return "critical"
        @unknown default: return "unknown"
        }
    }
}
