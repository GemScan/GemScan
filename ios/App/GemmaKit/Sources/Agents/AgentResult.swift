import Foundation

/// The scam verdict produced by the agent pipeline.
///
/// Raw values match the TypeScript `ScamVerdict` union exactly.
public enum ScamVerdict: String, Codable, Sendable {
    case safe       = "safe"
    case suspicious = "suspicious"
    case scam       = "scam"
}

/// A record of a single MCP tool call made during agent execution.
///
/// Field names match the TypeScript `ToolCallRecord` interface for
/// cross-bridge serialization.
public struct ToolCallRecord: Codable, Sendable {
    /// The MCP server that handled the call.
    public let serverName: String
    /// The tool name that was invoked.
    public let toolName: String
    /// Non-sensitive summary of the input (no PII).
    public let inputSummary: String
    /// Wall-clock duration of the call in milliseconds.
    public let durationMs: Int
    /// Whether the call completed successfully.
    public let success: Bool

    public init(
        serverName: String,
        toolName: String,
        inputSummary: String,
        durationMs: Int,
        success: Bool
    ) {
        self.serverName = serverName
        self.toolName = toolName
        self.inputSummary = inputSummary
        self.durationMs = durationMs
        self.success = success
    }
}

/// The result produced by a completed agent analysis task.
///
/// All field names use camelCase matching the TypeScript `AgentResult` interface.
public struct AgentResult: Codable, Sendable {
    /// The task identifier this result corresponds to.
    public let taskId: String
    /// The agent that produced this result (e.g. "text-agent", "orchestrator").
    public let agentId: String
    /// The scam verdict.
    public let verdict: ScamVerdict
    /// Confidence score in the range [0.0, 1.0].
    public let confidence: Double
    /// Human-readable reasoning bullets (2-3 items, sixth-grade reading level).
    public let reasoning: [String]
    /// BCP-47 language tag of the reasoning output.
    public let language: String
    /// Records of all MCP tool calls made during execution.
    public let toolCallsLog: [ToolCallRecord]
    /// Total analysis latency in milliseconds.
    public let latencyMs: Int
    /// The model tier that produced this result.
    public let modelTier: ModelTier
    /// Whether the task was escalated from E2B to E4B.
    public let escalatedToE4B: Bool

    public init(
        taskId: String,
        agentId: String,
        verdict: ScamVerdict,
        confidence: Double,
        reasoning: [String],
        language: String,
        toolCallsLog: [ToolCallRecord] = [],
        latencyMs: Int,
        modelTier: ModelTier,
        escalatedToE4B: Bool = false
    ) {
        self.taskId = taskId
        self.agentId = agentId
        self.verdict = verdict
        self.confidence = confidence
        self.reasoning = reasoning
        self.language = language
        self.toolCallsLog = toolCallsLog
        self.latencyMs = latencyMs
        self.modelTier = modelTier
        self.escalatedToE4B = escalatedToE4B
    }

    /// Returns a copy of this result marked as escalated with updated latency.
    public func markingEscalated(latencyMs override: Int) -> AgentResult {
        AgentResult(
            taskId: taskId,
            agentId: agentId,
            verdict: verdict,
            confidence: confidence,
            reasoning: reasoning,
            language: language,
            toolCallsLog: toolCallsLog,
            latencyMs: override,
            modelTier: modelTier,
            escalatedToE4B: true
        )
    }
}
