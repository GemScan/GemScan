import Foundation
import os

/// The top-level orchestrator that receives all tasks and delegates to specialist agents.
///
/// `OrchestratorAgent` implements the ReAct pattern (Reason-Act-Observe):
/// 1. **Reason**: Determine which specialist agent should handle the task.
/// 2. **Act**: Dispatch to the specialist agent.
/// 3. **Observe**: Evaluate the result and apply the conservative low-confidence
///    fallback when the specialist isn't sure enough.
///
/// Low-confidence fallback:
/// - If E2B confidence is below 0.75, force the verdict to `.scam` (the
///   conservative choice — false-positive a few benign messages rather than
///   miss a real scam).
///
/// Gemma 4 E2B is the only on-device model: no E4B escalation, no DistilBERT
/// fast-path. The dedicated dispute adjudication step (formerly `JudgeAgent`)
/// is gone with it — there is no second opinion to weigh against.
public actor OrchestratorAgent {

    // MARK: - Properties

    /// Shared singleton instance for app-wide access.
    public static let shared = OrchestratorAgent()

    /// The on-device inference engine for LLM generation.
    private var inferenceEngine: InferenceEngine?

    /// The text classification specialist agent.
    private var textAgent: TextAgent?

    /// The URL analysis specialist agent.
    private var urlAgent: URLAgent?

    /// The image analysis specialist agent.
    private var imageAgent: ImageAgent?

    /// The voice analysis specialist agent.
    private var voiceAgent: VoiceAgent?

    /// Logger for orchestrator events.
    private let logger = GemScanLogger.agents

    /// Confidence threshold below which E2B results are forced to `.scam`.
    private let e2bLowConfidenceThreshold: Double = 0.75

    // MARK: - Initialization

    /// Creates a new orchestrator agent.
    ///
    /// Call ``configure(inferenceEngine:)`` before dispatching tasks.
    public init() {}

    /// Configures the orchestrator with an inference engine and instantiates all specialist agents.
    ///
    /// - Parameter inferenceEngine: The shared inference engine.
    public func configure(inferenceEngine: InferenceEngine) {
        self.inferenceEngine = inferenceEngine
        self.textAgent = TextAgent(inferenceEngine: inferenceEngine)
        self.urlAgent = URLAgent(inferenceEngine: inferenceEngine)
        self.imageAgent = ImageAgent(inferenceEngine: inferenceEngine)
        self.voiceAgent = VoiceAgent(inferenceEngine: inferenceEngine)

        logger.info("OrchestratorAgent configured with all specialist agents")
    }

    // MARK: - Public API

    /// Dispatches a task through the agent pipeline using the ReAct pattern.
    ///
    /// Routes the task to the appropriate specialist agent, evaluates the result,
    /// and applies the low-confidence safety fallback if needed.
    ///
    /// - Parameter task: The agent task to process.
    /// - Returns: An ``AgentResult`` with the final verdict.
    /// - Throws: ``GemScanError`` on configuration, inference, or timeout errors.
    public func dispatch(task: AgentTask) async throws -> AgentResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        logger.info("Orchestrator dispatching task \(task.id), type: \(task.type.rawValue)")

        guard inferenceEngine != nil else {
            throw GemScanError.inferenceError(message: "OrchestratorAgent not configured. Call configure(inferenceEngine:) first.")
        }

        // MARK: Reason — Route to specialist agent

        let specialistResult = try await routeToSpecialist(task: task)

        // MARK: Observe — Apply low-confidence safety fallback if needed

        let finalResult: AgentResult
        let totalLatencyMs = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)

        if specialistResult.confidence < e2bLowConfidenceThreshold, specialistResult.verdict != .scam {
            logger.info("Orchestrator forcing scam verdict on task \(task.id): \(specialistResult.modelTier.rawValue) confidence \(String(format: "%.3f", specialistResult.confidence)) < \(self.e2bLowConfidenceThreshold)")
            finalResult = specialistResult.markingLowConfidenceScam(latencyMs: totalLatencyMs)
        } else {
            finalResult = specialistResult
        }

        let confidenceStr = String(format: "%.3f", finalResult.confidence)
        // swiftlint:disable:next line_length
        logger.info("Orchestrator completed task \(task.id): verdict=\(finalResult.verdict.rawValue), confidence=\(confidenceStr), totalLatency=\(totalLatencyMs)ms, lowConfidenceFallback=\(finalResult.lowConfidenceFallback)")

        return finalResult
    }

    // MARK: - Private Helpers

    /// Routes a task to the appropriate specialist agent based on task type.
    ///
    /// - Parameter task: The task to route.
    /// - Returns: The specialist agent's ``AgentResult``.
    private func routeToSpecialist(task: AgentTask) async throws -> AgentResult {
        switch task.type {
        case .classifySMS, .classifyEmail:
            guard let textAgent else {
                throw GemScanError.inferenceError(message: "TextAgent not available")
            }
            return try await textAgent.analyse(task: task)

        case .checkURL:
            guard let urlAgent else {
                throw GemScanError.inferenceError(message: "URLAgent not available")
            }
            return try await urlAgent.analyse(task: task)

        case .analyseScreenshot:
            guard let imageAgent else {
                throw GemScanError.inferenceError(message: "ImageAgent not available")
            }
            return try await imageAgent.analyse(task: task)

        case .scoreVoice:
            guard let voiceAgent else {
                throw GemScanError.inferenceError(message: "VoiceAgent not available")
            }
            return try await voiceAgent.analyse(task: task)

        case .explainVerdict:
            // For explain-verdict tasks, the orchestrator handles them directly
            return try await handleExplainVerdict(task: task)
        }
    }

    /// Handles explainVerdict tasks by summarizing a prior result at sixth-grade level.
    ///
    /// - Parameter task: The task with a `.multimodal` payload containing a prior result.
    /// - Returns: An ``AgentResult`` with a simplified explanation.
    private func handleExplainVerdict(task: AgentTask) async throws -> AgentResult {
        guard let inferenceEngine else {
            throw GemScanError.inferenceError(message: "InferenceEngine not available")
        }

        let startTime = CFAbsoluteTimeGetCurrent()

        let prompt = """
        Explain the following scam analysis result in simple terms that a sixth-grader could understand.
        Use 2-3 short bullet points. Do not use technical jargon.

        Task payload: \(String(describing: task.payload))

        Respond with a JSON object: {"verdict": "...", "confidence": ..., "reasoning": [...], "toolCalls": []}
        """

        let grammar = GrammarConstraint.textAgentGrammar()

        let rawOutput = try await inferenceEngine.generate(
            task: prompt,
            modelTier: .e2b,
            grammar: grammar
        )

        let parsed = try ParsedVerdict.parse(from: rawOutput)

        let latencyMs = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)

        return AgentResult(
            taskId: task.id,
            agentId: AgentID.orchestrator,
            verdict: parsed.verdict,
            confidence: parsed.confidence,
            reasoning: parsed.reasoning,
            language: "en",
            toolCallsLog: [],
            latencyMs: latencyMs,
            modelTier: .e2b
        )
    }
}
