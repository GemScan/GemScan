import Foundation
import os

/// Specialist agent for URL reputation and phishing detection.
///
/// `URLAgent` performs parallel MCP tool calls for URL reputation and WHOIS
/// data, then feeds the combined context to Gemma E2B with grammar-constrained
/// generation to produce a structured verdict.
///
/// MCP tools used: `sqlite_vec`, `url_reputation`, `whois`.
public actor URLAgent {

    // MARK: - Properties

    /// The on-device inference engine for LLM generation.
    private let inferenceEngine: InferenceEngine

    /// Logger for agent events.
    private let logger = GemScanLogger.agents

    // MARK: - Initialization

    /// Creates a new URL agent with the given inference engine.
    ///
    /// - Parameter inferenceEngine: The shared inference engine for LLM calls.
    public init(inferenceEngine: InferenceEngine) {
        self.inferenceEngine = inferenceEngine
    }

    // MARK: - Public API

    /// Analyses a URL for phishing or scam indicators and returns a verdict.
    ///
    /// - Parameter task: The agent task containing a `.url` payload.
    /// - Returns: An ``AgentResult`` with the classification verdict.
    /// - Throws: ``GemScanError`` on inference or parsing failure.
    public func analyse(task: AgentTask) async throws -> AgentResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        logger.info("URLAgent starting analysis for task \(task.id)")

        guard case let .url(urlString) = task.payload else {
            throw GemScanError.inferenceError(message: "URLAgent received non-URL payload")
        }

        // MARK: Parallel MCP tool calls

        var toolCallRecords: [ToolCallRecord] = []

        let (reputationResult, whoisResult, vectorResult) = await gatherToolContext(
            url: urlString,
            toolCallRecords: &toolCallRecords
        )

        // MARK: Grammar-constrained generation

        let prompt = URLAgentPrompts.system + "\n\n" + URLAgentPrompts.checkURL(
            url: urlString,
            reputationResult: reputationResult,
            whoisResult: whoisResult,
            vectorResult: vectorResult
        )

        let grammar = GrammarConstraint.urlAgentGrammar()

        let rawOutput = try await inferenceEngine.generate(
            task: prompt,
            modelTier: .e2b,
            grammar: grammar
        )

        let parsed = try ParsedVerdict.parse(from: rawOutput)

        // Validate reasoning readability
        let combinedReasoning = parsed.reasoning.joined(separator: " ")
        let (grade, passes) = ExplainerValidator.validate(text: combinedReasoning)
        if !passes {
            logger.info("URLAgent reasoning grade level \(String(format: "%.1f", grade)) exceeds threshold (soft enforcement)")
        }

        let latencyMs = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)

        logger.info("URLAgent completed: verdict=\(parsed.verdict.rawValue), confidence=\(String(format: "%.3f", parsed.confidence)), latency=\(latencyMs)ms")

        return AgentResult(
            taskId: task.id,
            agentId: AgentID.urlAgent,
            verdict: parsed.verdict,
            confidence: parsed.confidence,
            reasoning: parsed.reasoning,
            language: "en",
            toolCallsLog: toolCallRecords,
            latencyMs: latencyMs,
            modelTier: .e2b,
            escalatedToE4B: false
        )
    }

    // MARK: - Private Helpers

    /// Gathers MCP tool context by running url_reputation and whois lookups concurrently.
    ///
    /// - Parameters:
    ///   - url: The URL to check.
    ///   - toolCallRecords: Inout array to append tool call records to.
    /// - Returns: A tuple of (reputationResult, whoisResult, vectorResult) strings.
    private func gatherToolContext(
        url: String,
        toolCallRecords: inout [ToolCallRecord]
    ) async -> (String, String, String) {
        // TODO: Integrate with MCP client for real parallel tool calls.
        // url_reputation/check_url + whois/lookup run concurrently.
        let tools = ["url_reputation", "whois", "sqlite_vec"]
        logger.info("URLAgent would call MCP tools concurrently: \(tools.joined(separator: ", "))")

        return (
            "URL reputation check pending (MCP integration required).",
            "WHOIS lookup pending (MCP integration required).",
            "Vector similarity search pending (MCP integration required)."
        )
    }
}
