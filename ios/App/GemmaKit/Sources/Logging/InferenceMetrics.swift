import Foundation

/// Telemetry snapshot captured after each inference run.
public struct InferenceMetrics: Codable, Sendable {
    /// The task identifier this metric belongs to.
    public let taskId: String
    /// The model tier used (e.g. "e2b", "e4b", "distilbert").
    public let modelTier: String
    /// Whether the task was escalated from e2b to e4b.
    public let escalatedToE4B: Bool
    /// Time to first token in milliseconds.
    public let firstTokenLatencyMs: Double
    /// Total wall-clock latency in milliseconds.
    public let totalLatencyMs: Double
    /// Tokens generated per second.
    public let tokensPerSecond: Double
    /// Peak resident set size in bytes during inference.
    public let peakRSSBytes: Int
    /// Number of MCP tool calls made.
    public let toolCallCount: Int
    /// The scam verdict string.
    public let verdict: String
    /// Confidence score in the range [0, 1].
    public let confidence: Double
    /// ISO 639-1 language code of the input.
    public let language: String
    /// Timestamp of this metric record.
    public let timestamp: Date

    private enum CodingKeys: String, CodingKey {
        case taskId
        case modelTier
        case escalatedToE4B
        case firstTokenLatencyMs
        case totalLatencyMs
        case tokensPerSecond
        case peakRSSBytes
        case toolCallCount
        case verdict
        case confidence
        case language
        case timestamp
    }

    public init(
        taskId: String,
        modelTier: String,
        escalatedToE4B: Bool,
        firstTokenLatencyMs: Double,
        totalLatencyMs: Double,
        tokensPerSecond: Double,
        peakRSSBytes: Int,
        toolCallCount: Int,
        verdict: String,
        confidence: Double,
        language: String,
        timestamp: Date
    ) {
        self.taskId = taskId
        self.modelTier = modelTier
        self.escalatedToE4B = escalatedToE4B
        self.firstTokenLatencyMs = firstTokenLatencyMs
        self.totalLatencyMs = totalLatencyMs
        self.tokensPerSecond = tokensPerSecond
        self.peakRSSBytes = peakRSSBytes
        self.toolCallCount = toolCallCount
        self.verdict = verdict
        self.confidence = confidence
        self.language = language
        self.timestamp = timestamp
    }

    /// Creates an empty metrics snapshot with zeroed-out fields.
    /// - Parameters:
    ///   - taskId: The task identifier.
    ///   - tier: The model tier string.
    /// - Returns: An `InferenceMetrics` instance with all numeric fields set to zero.
    public static func empty(taskId: String, tier: String) -> InferenceMetrics {
        InferenceMetrics(
            taskId: taskId,
            modelTier: tier,
            escalatedToE4B: false,
            firstTokenLatencyMs: 0,
            totalLatencyMs: 0,
            tokensPerSecond: 0,
            peakRSSBytes: 0,
            toolCallCount: 0,
            verdict: "",
            confidence: 0,
            language: "en",
            timestamp: Date()
        )
    }
}
