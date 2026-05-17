import Foundation
import os

/// Specialist agent for screenshot and image scam analysis.
///
/// `ImageAgent` runs on Gemma 4 E2B (the only on-device Gemma 4 tier that
/// fits in the iOS app memory budget). The 4-bit quant keeps the multimodal
/// vision tower, so screenshot analysis still works. The agent follows a
/// two-step process:
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
    /// Uses Gemma 4 E2B (4-bit, multimodal). The vision tower is part of the
    /// E2B quant — no separate model load is required.
    ///
    /// - Parameter task: The agent task containing an `.image` payload.
    /// - Returns: An ``AgentResult`` with the classification verdict.
    /// - Throws: ``GemScanError`` on inference or parsing failure.
    public func analyse(task: AgentTask) async throws -> AgentResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        logger.info("ImageAgent starting analysis for task \(task.id)")

        guard case let .image(base64Data, mimeType) = task.payload else {
            throw GemScanError.inferenceError(message: "ImageAgent received non-image payload")
        }

        guard let imageBytes = Data(base64Encoded: base64Data) else {
            throw GemScanError.inferenceError(message: "ImageAgent could not decode base64 image payload")
        }
        logger.info("ImageAgent decoded \(imageBytes.count) bytes of \(mimeType.rawValue) for vision input")

        // MARK: Grammar-constrained vision generation
        //
        // We hand the raw image bytes to MLX, which routes them through
        // Gemma 4 E2B's vision tower and fuses the visual tokens with the
        // text prompt. No OCR pre-pass — the model reads pixels directly.

        let toolCallRecords: [ToolCallRecord] = []

        let prompt = ImageAgentPrompts.system + "\n\n" + ImageAgentPrompts.analyseScreenshot()

        let grammar = GrammarConstraint.imageAgentGrammar()

        let rawOutput = try await inferenceEngine.generate(
            task: prompt,
            modelTier: .e2b,
            images: [imageBytes],
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
            suggestion: parsed.suggestion,
            language: "en",
            toolCallsLog: toolCallRecords,
            latencyMs: latencyMs,
            modelTier: .e2b
        )
    }
}
