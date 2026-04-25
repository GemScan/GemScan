import Foundation
import os

/// Specialist agent for screenshot and image scam analysis.
///
/// `ImageAgent` always uses Gemma E4B (multimodal vision required) and follows
/// a two-step process:
/// 1. Call `reverse_image/extract_text_urls` for OCR to extract text and URLs.
/// 2. Run `generateVision()` with grammar constraints on the image + OCR context.
///
/// MCP tools used: `sqlite_vec`, `url_reputation`, `reverse_image`.
public actor ImageAgent {

    // MARK: - Properties

    /// The on-device inference engine for LLM generation.
    private let inferenceEngine: InferenceEngine

    /// Logger for agent events.
    private let logger = GemScanLogger.agents

    // MARK: - Initialization

    /// Creates a new image agent with the given inference engine.
    ///
    /// - Parameter inferenceEngine: The shared inference engine for LLM calls.
    public init(inferenceEngine: InferenceEngine) {
        self.inferenceEngine = inferenceEngine
    }

    // MARK: - Public API

    /// Analyses a screenshot for scam indicators and returns a verdict.
    ///
    /// This method always uses E4B because multimodal vision is required for
    /// screenshot analysis. The E4B model is loaded on demand if not already resident.
    ///
    /// - Parameter task: The agent task containing an `.image` payload.
    /// - Returns: An ``AgentResult`` with the classification verdict.
    /// - Throws: ``GemScanError`` on inference or parsing failure.
    public func analyse(task: AgentTask) async throws -> AgentResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        logger.info("ImageAgent starting analysis for task \(task.id)")

        guard case let .image(base64Data, _) = task.payload else {
            throw GemScanError.inferenceError(message: "ImageAgent received non-image payload")
        }

        // Ensure E4B is loaded for multimodal vision
        try await inferenceEngine.loadE4BIfNeeded()

        // MARK: Step 1 — OCR via reverse_image/extract_text_urls

        var toolCallRecords: [ToolCallRecord] = []

        let (ocrText, extractedURLs) = await performOCR(
            base64Data: base64Data,
            toolCallRecords: &toolCallRecords
        )

        // MARK: Step 2 — URL reputation for extracted URLs

        let reputationResult = await checkURLReputation(
            urls: extractedURLs,
            toolCallRecords: &toolCallRecords
        )

        // MARK: Step 3 — Vector similarity search

        let vectorResult = await vectorSearch(
            ocrText: ocrText,
            toolCallRecords: &toolCallRecords
        )

        // MARK: Step 4 — Grammar-constrained vision generation

        let prompt = ImageAgentPrompts.system + "\n\n" + ImageAgentPrompts.analyseScreenshot(
            ocrText: ocrText,
            extractedURLs: extractedURLs,
            reputationResult: reputationResult,
            vectorResult: vectorResult
        )

        let grammar = GrammarConstraint.imageAgentGrammar()

        let rawOutput = try await inferenceEngine.generate(
            task: prompt,
            modelTier: .e4b,
            grammar: grammar
        )

        let parsed = try ParsedVerdict.parse(from: rawOutput)

        // Validate reasoning readability
        let combinedReasoning = parsed.reasoning.joined(separator: " ")
        let (grade, passes) = ExplainerValidator.validate(text: combinedReasoning)
        if !passes {
            logger.info("ImageAgent reasoning grade level \(String(format: "%.1f", grade)) exceeds threshold (soft enforcement)")
        }

        let latencyMs = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)

        logger.info("ImageAgent completed: verdict=\(parsed.verdict.rawValue), confidence=\(String(format: "%.3f", parsed.confidence)), latency=\(latencyMs)ms")

        return AgentResult(
            taskId: task.id,
            agentId: AgentID.imageAgent,
            verdict: parsed.verdict,
            confidence: parsed.confidence,
            reasoning: parsed.reasoning,
            language: "en",
            toolCallsLog: toolCallRecords,
            latencyMs: latencyMs,
            modelTier: .e4b,
            escalatedToE4B: false
        )
    }

    // MARK: - Private Helpers

    /// Performs OCR on the image via the reverse_image MCP tool.
    ///
    /// - Parameters:
    ///   - base64Data: The base64-encoded image data.
    ///   - toolCallRecords: Inout array to append tool call records to.
    /// - Returns: A tuple of (extracted text, extracted URLs).
    private func performOCR(
        base64Data: String,
        toolCallRecords: inout [ToolCallRecord]
    ) async -> (String, [String]) {
        // TODO: Integrate with MCP client to call reverse_image/extract_text_urls.
        logger.info("ImageAgent would call reverse_image/extract_text_urls for OCR")

        return ("OCR text extraction pending (MCP integration required).", [])
    }

    /// Checks URL reputation for URLs extracted from the image.
    ///
    /// - Parameters:
    ///   - urls: The URLs to check.
    ///   - toolCallRecords: Inout array to append tool call records to.
    /// - Returns: A formatted reputation result string.
    private func checkURLReputation(
        urls: [String],
        toolCallRecords: inout [ToolCallRecord]
    ) async -> String {
        guard !urls.isEmpty else {
            return "No URLs found in image to check."
        }

        // TODO: Integrate with MCP client to call url_reputation for each URL.
        logger.info("ImageAgent would call url_reputation for \(urls.count) extracted URLs")

        return "URL reputation check pending (MCP integration required)."
    }

    /// Performs vector similarity search against known scam patterns.
    ///
    /// - Parameters:
    ///   - ocrText: The OCR-extracted text to search against.
    ///   - toolCallRecords: Inout array to append tool call records to.
    /// - Returns: A formatted vector search result string.
    private func vectorSearch(
        ocrText: String,
        toolCallRecords: inout [ToolCallRecord]
    ) async -> String {
        // TODO: Integrate with MCP client to call sqlite_vec.
        logger.info("ImageAgent would call sqlite_vec for vector similarity search")

        return "Vector similarity search pending (MCP integration required)."
    }
}
