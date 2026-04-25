import Foundation
import os

/// The top-level orchestrator that receives all tasks and delegates to specialist agents.
///
/// `OrchestratorAgent` implements the ReAct pattern (Reason-Act-Observe):
/// 1. **Reason**: Determine which specialist agent should handle the task.
/// 2. **Act**: Dispatch to the specialist agent.
/// 3. **Observe**: Evaluate the result and decide whether escalation is needed.
///
/// Escalation logic:
/// - If E2B confidence is below 0.75, re-run the task with E4B.
/// - If specialist agents produce disputed verdicts, invoke ``JudgeAgent``
///   for PhishDebate adjudication.
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

    /// The adjudication agent for disputed verdicts.
    private var judgeAgent: JudgeAgent?

    /// Logger for orchestrator events.
    private let logger = GemScanLogger.agents

    /// Confidence threshold below which E2B results trigger E4B escalation.
    private let escalationThreshold: Double = 0.75

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
        self.judgeAgent = JudgeAgent(inferenceEngine: inferenceEngine)

        logger.info("OrchestratorAgent configured with all specialist agents")
    }

    // MARK: - Public API

    /// Dispatches a task through the agent pipeline using the ReAct pattern.
    ///
    /// Routes the task to the appropriate specialist agent, evaluates the result,
    /// and escalates if needed.
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

        // MARK: Observe — Evaluate result and decide on escalation

        let finalResult: AgentResult

        if specialistResult.modelTier == .e2b, specialistResult.confidence < escalationThreshold {
            // Escalate to E4B
            logger.info("Orchestrator escalating task \(task.id): E2B confidence \(String(format: "%.3f", specialistResult.confidence)) < \(self.escalationThreshold)")

            finalResult = try await escalateToE4B(task: task, originalResult: specialistResult, startTime: startTime)
        } else if specialistResult.modelTier == .distilbert, specialistResult.confidence < 0.90 {
            // DistilBERT result was below comfort threshold, run full LLM path
            logger.info("Orchestrator escalating task \(task.id): DistilBERT confidence \(String(format: "%.3f", specialistResult.confidence)) below comfort threshold")

            finalResult = try await escalateToE4B(task: task, originalResult: specialistResult, startTime: startTime)
        } else {
            finalResult = specialistResult
        }

        let totalLatencyMs = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)
        logger.info("Orchestrator completed task \(task.id): verdict=\(finalResult.verdict.rawValue), confidence=\(String(format: "%.3f", finalResult.confidence)), totalLatency=\(totalLatencyMs)ms, escalated=\(finalResult.escalatedToE4B)")

        return finalResult
    }

    /// Handles disputed verdicts by invoking the JudgeAgent for PhishDebate adjudication.
    ///
    /// - Parameters:
    ///   - task: The original task.
    ///   - disputedResults: The conflicting results from specialist agents.
    /// - Returns: The judge's final ``AgentResult``.
    /// - Throws: ``GemScanError`` on configuration or inference errors.
    public func adjudicateDispute(
        task: AgentTask,
        disputedResults: [AgentResult]
    ) async throws -> AgentResult {
        guard let judgeAgent else {
            throw GemScanError.inferenceError(message: "JudgeAgent not available. Configure the orchestrator first.")
        }

        logger.info("Orchestrator invoking JudgeAgent for dispute adjudication on task \(task.id)")

        return try await judgeAgent.adjudicate(task: task, disputedResults: disputedResults)
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

    /// Escalates a low-confidence E2B result to E4B.
    ///
    /// Re-runs the full specialist agent analysis but this time with E4B loaded,
    /// or dispatches to the JudgeAgent if the original and escalated results disagree.
    ///
    /// - Parameters:
    ///   - task: The original task.
    ///   - originalResult: The low-confidence E2B result.
    ///   - startTime: The pipeline start time for latency tracking.
    /// - Returns: The escalated ``AgentResult``.
    private func escalateToE4B(
        task: AgentTask,
        originalResult: AgentResult,
        startTime: CFAbsoluteTime
    ) async throws -> AgentResult {
        guard let inferenceEngine else {
            throw GemScanError.inferenceError(message: "InferenceEngine not available for escalation")
        }

        // Load E4B if needed
        try await inferenceEngine.loadE4BIfNeeded()

        // Re-run the specialist with a fresh task
        let escalatedResult = try await routeToSpecialist(task: task)

        // If verdicts disagree, invoke the JudgeAgent
        if escalatedResult.verdict != originalResult.verdict {
            logger.info("Orchestrator: E2B and E4B verdicts disagree — invoking JudgeAgent")

            guard let judgeAgent else {
                // Fall back to the escalated result if JudgeAgent is unavailable
                let latencyMs = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)
                return escalatedResult.markingEscalated(latencyMs: latencyMs)
            }

            let judgeResult = try await judgeAgent.adjudicate(
                task: task,
                disputedResults: [originalResult, escalatedResult]
            )

            return judgeResult
        }

        let latencyMs = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)
        return escalatedResult.markingEscalated(latencyMs: latencyMs)
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
            modelTier: .e2b,
            escalatedToE4B: false
        )
    }
}
