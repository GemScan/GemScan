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
    /// Short explanation as 1-2 bullets, total under 25 words combined.
    public let reasoning: [String]
    /// Actionable guidance for the user (40-60 words). Surfaced beneath the
    /// explanation in the verdict card; tells the user what to do next.
    /// Optional for backward-compat with results persisted before this field
    /// was added — current agent runs always populate it.
    public let suggestion: String?
    /// The text the model actually classified — for SMS / email tasks this
    /// is the user's input; for screenshot tasks it is the OCR
    /// transcription produced by Apple Vision before classification. The
    /// UI shows it back to the user so they can confirm what was checked.
    /// Optional for back-compat with results persisted before this field
    /// existed.
    public let analyzedText: String?
    /// BCP-47 language tag of the reasoning output.
    public let language: String
    /// Records of all MCP tool calls made during execution.
    public let toolCallsLog: [ToolCallRecord]
    /// Total analysis latency in milliseconds.
    public let latencyMs: Int
    /// The model tier that produced this result.
    public let modelTier: ModelTier
    /// Whether the verdict was forced to `.scam` by the orchestrator because
    /// the underlying agent returned a confidence below the safety threshold.
    /// The agent's original confidence is preserved in ``confidence``.
    public let lowConfidenceFallback: Bool

    public init(
        taskId: String,
        agentId: String,
        verdict: ScamVerdict,
        confidence: Double,
        reasoning: [String],
        suggestion: String? = nil,
        analyzedText: String? = nil,
        language: String,
        toolCallsLog: [ToolCallRecord] = [],
        latencyMs: Int,
        modelTier: ModelTier,
        lowConfidenceFallback: Bool = false
    ) {
        self.taskId = taskId
        self.agentId = agentId
        self.verdict = verdict
        self.confidence = confidence
        self.reasoning = reasoning
        self.suggestion = suggestion
        self.analyzedText = analyzedText
        self.language = language
        self.toolCallsLog = toolCallsLog
        self.latencyMs = latencyMs
        self.modelTier = modelTier
        self.lowConfidenceFallback = lowConfidenceFallback
    }

    /// Returns a copy of this result with the verdict forced to `.scam`,
    /// the `lowConfidenceFallback` flag set, and updated latency. The agent's
    /// original confidence is preserved so the UI can show how unsure we were.
    public func markingLowConfidenceScam(latencyMs override: Int) -> AgentResult {
        AgentResult(
            taskId: taskId,
            agentId: agentId,
            verdict: .scam,
            confidence: confidence,
            reasoning: reasoning,
            suggestion: suggestion,
            analyzedText: analyzedText,
            language: language,
            toolCallsLog: toolCallsLog,
            latencyMs: override,
            modelTier: modelTier,
            lowConfidenceFallback: true
        )
    }
}
