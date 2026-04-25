import Foundation
import os

/// Specialist agent for SMS and email scam classification.
///
/// `TextAgent` implements a two-tier analysis strategy:
/// 1. **DistilBERT fast-path**: If ``SMSTriage`` confidence exceeds 0.95 and the
///    label is safe, the result is returned immediately without invoking the LLM.
/// 2. **E2B LLM fallback**: For uncertain triage results, the agent gathers
///    context from MCP tools and runs grammar-constrained generation.
///
/// MCP tools used: `scam_patterns`, `sqlite_vec`, `contacts`, `url_reputation`,
/// `phone_reputation`, `message_filter`.
public actor TextAgent {

    // MARK: - Properties

    /// The on-device inference engine for LLM generation.
    private let inferenceEngine: InferenceEngine

    /// The DistilBERT-based SMS triage classifier for fast-path filtering.
    private let smsTriage: SMSTriage

    /// Logger for agent events.
    private let logger = GemScanLogger.agents

    /// Confidence threshold above which DistilBERT safe results skip the LLM.
    private let fastPathThreshold: Double = 0.95

    // MARK: - Initialization

    /// Creates a new text agent with the given inference engine and triage classifier.
    ///
    /// - Parameters:
    ///   - inferenceEngine: The shared inference engine for LLM calls.
    ///   - smsTriage: The DistilBERT classifier for SMS fast-path.
    public init(inferenceEngine: InferenceEngine, smsTriage: SMSTriage = SMSTriage()) {
        self.inferenceEngine = inferenceEngine
        self.smsTriage = smsTriage
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

        // MARK: DistilBERT fast-path for SMS

        if task.type == .classifySMS {
            if let fastResult = try await attemptFastPath(
                task: task,
                content: content,
                startTime: startTime
            ) {
                return fastResult
            }
        }

        // MARK: LLM analysis with MCP tool context

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
            language: language ?? "en",
            toolCallsLog: toolCallRecords,
            latencyMs: latencyMs,
            modelTier: .e2b,
            escalatedToE4B: false
        )
    }

    // MARK: - Private Helpers

    /// Attempts the DistilBERT fast-path for SMS classification.
    ///
    /// - Returns: An ``AgentResult`` if the fast-path succeeds, or `nil` if the LLM path is needed.
    private func attemptFastPath(
        task: AgentTask,
        content: String,
        startTime: CFAbsoluteTime
    ) async throws -> AgentResult? {
        let senderHash = content.hashValue.description
        let messageHash = content.data(using: .utf8)?.hashValue.description ?? ""

        do {
            let triageResult = try await smsTriage.classify(
                senderHash: senderHash,
                messageHash: messageHash
            )

            if triageResult.label == .safe, triageResult.confidence > fastPathThreshold {
                let latencyMs = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)
                logger.info("TextAgent fast-path: safe with confidence \(String(format: "%.3f", triageResult.confidence)) in \(latencyMs)ms")

                return AgentResult(
                    taskId: task.id,
                    agentId: AgentID.textAgent,
                    verdict: .safe,
                    confidence: triageResult.confidence,
                    reasoning: ["Message passed DistilBERT fast-path check with high confidence."],
                    language: task.payload.language ?? "en",
                    toolCallsLog: [],
                    latencyMs: latencyMs,
                    modelTier: .distilbert,
                    escalatedToE4B: false
                )
            }

            logger.info("TextAgent fast-path inconclusive (label=\(triageResult.label.rawValue), confidence=\(String(format: "%.3f", triageResult.confidence))), falling through to LLM")
        } catch {
            logger.warning("TextAgent fast-path failed: \(error.localizedDescription), falling through to LLM")
        }

        return nil
    }

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
        let tools = ["scam_patterns", "sqlite_vec", "contacts", "url_reputation", "phone_reputation", "message_filter"]
        logger.info("TextAgent would call MCP tools: \(tools.joined(separator: ", "))")

        return "MCP tool integration pending. Analysing content directly."
    }
}
