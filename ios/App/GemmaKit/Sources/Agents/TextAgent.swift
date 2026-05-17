import Foundation
import os

/// Specialist agent for SMS and email scam classification.
///
/// `TextAgent` runs every input through Gemma 4 E2B with MCP-tool context
/// and grammar-constrained generation. The earlier DistilBERT fast-path
/// was retired together with the SMS triage tier — everything is the LLM
/// path now.
///
/// MCP tools used: `scam_patterns`, `sqlite_vec`, `contacts`, `url_reputation`,
/// `message_filter`.
public actor TextAgent {

    // MARK: - Properties

    /// The on-device inference engine for LLM generation.
    private let inferenceEngine: InferenceEngine

    /// Logger for agent events.
    private let logger = GemScanLogger.agents

    // MARK: - Initialization

    /// Creates a new text agent with the given inference engine.
    ///
    /// - Parameter inferenceEngine: The shared inference engine for LLM calls.
    public init(inferenceEngine: InferenceEngine) {
        self.inferenceEngine = inferenceEngine
    }

    // MARK: - Public API

    /// Analyses a text-based task (SMS or email) and returns a scam verdict.
    ///
    /// - Parameter task: The agent task containing a `.text` payload.
    /// - Returns: An ``AgentResult`` with the classification verdict.
    /// - Throws: ``GemScanError`` on inference or parsing failure.
    public func analyse(task: AgentTask) async throws -> AgentResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        logger.info("TextAgent starting analysis for task \(task.id), type: \(task.type.rawValue)")

        guard case let .text(content, language) = task.payload else {
            throw GemScanError.inferenceError(message: "TextAgent received non-text payload")
        }

        var toolCallRecords: [ToolCallRecord] = []

        let toolResults = await gatherToolContext(
            content: content,
            taskType: task.type,
            toolCallRecords: &toolCallRecords
        )

        let prompt: String
        switch task.type {
        case .classifySMS:
            prompt = TextAgentPrompts.classifySMS(
                messageContent: content,
                toolResults: toolResults,
                language: language
            )
        case .classifyEmail:
            prompt = TextAgentPrompts.classifyEmail(
                emailContent: content,
                toolResults: toolResults,
                language: language
            )
        default:
            throw GemScanError.inferenceError(message: "TextAgent cannot handle task type: \(task.type.rawValue)")
        }

        let fullPrompt = TextAgentPrompts.system + "\n\n" + prompt
        let grammar = GrammarConstraint.textAgentGrammar()

        let rawOutput = try await inferenceEngine.generate(
            task: fullPrompt,
            modelTier: .e2b,
            grammar: grammar
        )

        let parsed = try ParsedVerdict.parse(from: rawOutput)

        // Validate reasoning readability
        let combinedReasoning = parsed.reasoning.joined(separator: " ")
        let (grade, passes) = ExplainerValidator.validate(text: combinedReasoning)
        if !passes {
            logger.info("TextAgent reasoning grade level \(String(format: "%.1f", grade)) exceeds threshold (soft enforcement)")
        }

        let latencyMs = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)

        logger.info("TextAgent completed: verdict=\(parsed.verdict.rawValue), confidence=\(String(format: "%.3f", parsed.confidence)), latency=\(latencyMs)ms")

        return AgentResult(
            taskId: task.id,
            agentId: AgentID.textAgent,
            verdict: parsed.verdict,
            confidence: parsed.confidence,
            reasoning: parsed.reasoning,
            suggestion: parsed.suggestion,
            language: language ?? "en",
            toolCallsLog: toolCallRecords,
            latencyMs: latencyMs,
            modelTier: .e2b
        )
    }

    // MARK: - Private Helpers

    /// Gathers MCP tool context for the LLM prompt.
    ///
    /// Calls scam_patterns, sqlite_vec, and other relevant tools in parallel
    /// where possible. Tool failures are logged but do not abort the pipeline.
    ///
    /// - Parameters:
    ///   - content: The message content being analysed.
    ///   - taskType: The type of text task (SMS or email).
    ///   - toolCallRecords: Inout array to append tool call records to.
    /// - Returns: A formatted string of tool results for the LLM prompt.
    private func gatherToolContext(
        content: String,
        taskType: AgentTaskType,
        toolCallRecords: inout [ToolCallRecord]
    ) async -> String {
        // TODO: Integrate with MCP client to call real tools.
        // For now, return placeholder context indicating tool calls would happen.
        let tools = ["scam_patterns", "sqlite_vec", "contacts", "url_reputation", "message_filter"]
        logger.info("TextAgent would call MCP tools: \(tools.joined(separator: ", "))")

        return "MCP tool integration pending. Analysing content directly."
    }
}
