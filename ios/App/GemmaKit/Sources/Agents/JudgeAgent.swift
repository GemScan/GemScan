import Foundation
import os

/// Adjudication agent that resolves disputed verdicts using the PhishDebate pattern.
///
/// `JudgeAgent` runs a three-pass debate to reach a final verdict:
/// 1. **Defence counsel**: Argues the content is safe.
/// 2. **Prosecution rebuttal**: Argues the content is a scam.
/// 3. **Final verdict**: The judge weighs both sides and renders judgement.
///
/// Always uses E4B for maximum reasoning quality. This agent is invoked by
/// the ``OrchestratorAgent`` when specialist agents disagree or when
/// confidence is borderline.
///
/// MCP tools used: `scam_patterns`, `sqlite_vec`.
public actor JudgeAgent {

    // MARK: - Properties

    /// The on-device inference engine for LLM generation.
    private let inferenceEngine: InferenceEngine

    /// Logger for agent events.
    private let logger = GemScanLogger.agents

    // MARK: - Initialization

    /// Creates a new judge agent with the given inference engine.
    ///
    /// - Parameter inferenceEngine: The shared inference engine for LLM calls.
    public init(inferenceEngine: InferenceEngine) {
        self.inferenceEngine = inferenceEngine
    }

    // MARK: - Public API

    /// Adjudicates disputed verdicts from specialist agents.
    ///
    /// Runs the three-pass PhishDebate pattern and returns a final verdict.
    ///
    /// - Parameters:
    ///   - task: The original agent task.
    ///   - disputedResults: The conflicting ``AgentResult`` values from specialist agents.
    /// - Returns: An ``AgentResult`` containing the judge's final verdict.
    /// - Throws: ``GemScanError`` on inference or parsing failure.
    public func adjudicate(
        task: AgentTask,
        disputedResults: [AgentResult]
    ) async throws -> AgentResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        logger.info("JudgeAgent starting adjudication for task \(task.id) with \(disputedResults.count) disputed results")

        // Ensure E4B is loaded for maximum reasoning quality
        try await inferenceEngine.loadE4BIfNeeded()

        var toolCallRecords: [ToolCallRecord] = []

        // Prepare context summaries
        let originalContent = summarizePayload(task.payload)
        let agentResults = formatDisputedResults(disputedResults)

        let scamPatterns = await fetchScamPatterns(
            content: originalContent,
            toolCallRecords: &toolCallRecords
        )

        let vectorResult = await vectorSearch(
            content: originalContent,
            toolCallRecords: &toolCallRecords
        )

        // MARK: Pass 1 — Defence counsel

        logger.info("JudgeAgent Pass 1: Defence counsel")

        let defencePrompt = JudgeAgentPrompts.system + "\n\n" + JudgeAgentPrompts.defenceCounsel(
            originalContent: originalContent,
            agentResults: agentResults,
            scamPatterns: scamPatterns
        )

        let defenceOutput = try await inferenceEngine.generate(
            task: defencePrompt,
            modelTier: .e4b,
            grammar: nil
        )

        // MARK: Pass 2 — Prosecution rebuttal

        logger.info("JudgeAgent Pass 2: Prosecution rebuttal")

        let prosecutionPrompt = JudgeAgentPrompts.system + "\n\n" + JudgeAgentPrompts.prosecutionRebuttal(
            originalContent: originalContent,
            defenceArguments: defenceOutput,
            agentResults: agentResults,
            scamPatterns: scamPatterns
        )

        let prosecutionOutput = try await inferenceEngine.generate(
            task: prosecutionPrompt,
            modelTier: .e4b,
            grammar: nil
        )

        // MARK: Pass 3 — Final verdict

        logger.info("JudgeAgent Pass 3: Final verdict")

        let verdictPrompt = JudgeAgentPrompts.system + "\n\n" + JudgeAgentPrompts.finalVerdict(
            originalContent: originalContent,
            defenceArguments: defenceOutput,
            prosecutionArguments: prosecutionOutput,
            vectorResult: vectorResult
        )

        let grammar = GrammarConstraint.judgeAgentGrammar()

        let rawOutput = try await inferenceEngine.generate(
            task: verdictPrompt,
            modelTier: .e4b,
            grammar: grammar
        )

        let parsed = try ParsedVerdict.parse(from: rawOutput)

        // Validate reasoning readability
        let combinedReasoning = parsed.reasoning.joined(separator: " ")
        let (grade, passes) = ExplainerValidator.validate(text: combinedReasoning)
        if !passes {
            logger.info("JudgeAgent reasoning grade level \(String(format: "%.1f", grade)) exceeds threshold (soft enforcement)")
        }

        let latencyMs = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)

        logger.info("JudgeAgent completed: verdict=\(parsed.verdict.rawValue), confidence=\(String(format: "%.3f", parsed.confidence)), latency=\(latencyMs)ms")

        return AgentResult(
            taskId: task.id,
            agentId: AgentID.judgeAgent,
            verdict: parsed.verdict,
            confidence: parsed.confidence,
            reasoning: parsed.reasoning,
            language: "en",
            toolCallsLog: toolCallRecords,
            latencyMs: latencyMs,
            modelTier: .e4b,
            escalatedToE4B: true
        )
    }

    // MARK: - Private Helpers

    /// Summarizes the task payload into a brief content description for prompts.
    private func summarizePayload(_ payload: AgentPayload) -> String {
        switch payload {
        case let .text(content, _):
            let truncated = content.count > 500 ? String(content.prefix(500)) + "..." : content
            return truncated
        case let .url(url):
            return "URL: \(url)"
        case .image:
            return "[Screenshot image]"
        case .audio:
            return "[Audio recording]"
        case let .multimodal(parts, _):
            return "Multimodal content with \(parts.count) parts"
        }
    }

    /// Formats disputed agent results into a readable string for prompts.
    private func formatDisputedResults(_ results: [AgentResult]) -> String {
        results.map { result in
            "Agent \(result.agentId): verdict=\(result.verdict.rawValue), confidence=\(String(format: "%.3f", result.confidence)), reasoning=\(result.reasoning.joined(separator: "; "))"
        }.joined(separator: "\n")
    }

    /// Fetches matching scam patterns from the database via MCP.
    private func fetchScamPatterns(
        content: String,
        toolCallRecords: inout [ToolCallRecord]
    ) async -> String {
        // TODO: Integrate with MCP client to call scam_patterns.
        logger.info("JudgeAgent would call scam_patterns MCP tool")

        return "Scam pattern lookup pending (MCP integration required)."
    }

    /// Performs vector similarity search against known scam patterns.
    private func vectorSearch(
        content: String,
        toolCallRecords: inout [ToolCallRecord]
    ) async -> String {
        // TODO: Integrate with MCP client to call sqlite_vec.
        logger.info("JudgeAgent would call sqlite_vec for vector similarity search")

        return "Vector similarity search pending (MCP integration required)."
    }
}
