import Foundation
import os

/// Specialist agent for screenshot and image scam analysis.
///
/// `ImageAgent` runs a two-stage pipeline:
/// 1. **OCR** — Apple's `VNRecognizeTextRequest` extracts text from the
///    screenshot. We use Vision rather than Gemma's vision tower because
///    Gemma 4 E2B at 4-bit quant has weak character-level OCR fidelity,
///    while Vision is purpose-built for this task and ships free with iOS.
/// 2. **Classification** — the extracted text flows through the same
///    Gemma 4 E2B text path used by ``TextAgent``, producing identical
///    reasoning / suggestion / verdict output regardless of input modality.
///
/// If OCR returns no readable text (``ImageOCR/noTextSentinel`` or fewer
/// than ``minimumOCRCharacters`` characters), we short-circuit to a
/// low-confidence `safe` verdict rather than guess.
public actor ImageAgent {

    // MARK: - Properties

    /// The on-device inference engine for LLM generation.
    private let inferenceEngine: InferenceEngine

    /// Logger for agent events.
    private let logger = GemScanLogger.agents

    /// Minimum number of characters in OCR output before we attempt
    /// classification. Below this, transcription is treated as unusable.
    private static let minimumOCRCharacters = 4

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
    /// Runs the two-stage transcribe-then-classify pipeline described in the
    /// type-level documentation.
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
        logger.info("ImageAgent decoded \(imageBytes.count) bytes of \(mimeType.rawValue) for OCR")

        // MARK: Stage 1 — Apple Vision OCR
        //
        // We use `VNRecognizeTextRequest` rather than Gemma's vision tower.
        // Gemma 4 E2B at 4-bit quant has weak character-level fidelity (it
        // hallucinated form-field placeholders during testing), whereas
        // Vision is purpose-built for OCR and is ~95-99% accurate on screen
        // text. The extracted string then flows into Gemma's text path so
        // the LLM still produces the reasoning + verdict.
        let extractedText = try ImageOCR.extractText(from: imageBytes)
        logger.info("ImageAgent Vision OCR produced \(extractedText.count) characters of text")
        // Debug-only: dump the OCR output to the Xcode console. Marked
        // `.public` because os.Logger redacts string interpolations by
        // default. Screenshot text can contain PII — gate this behind a
        // debug build before shipping externally.
        logger.info("ImageAgent Vision OCR text >>>\n\(extractedText, privacy: .public)\n<<<")

        // No usable text → short-circuit to a friendly safe verdict.
        if extractedText.isEmpty
            || extractedText == ImageOCR.noTextSentinel
            || extractedText.count < Self.minimumOCRCharacters {
            let latencyMs = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)
            logger.info("ImageAgent OCR returned no usable text — returning safe verdict")
            return AgentResult(
                taskId: task.id,
                agentId: AgentID.imageAgent,
                verdict: .safe,
                confidence: 0.5,
                reasoning: ["No readable text was found in the image."],
                suggestion: "I couldn't pick out any text in this picture to check, so there's nothing for me to compare against known scam patterns. If this image was supposed to show a message, link, or login screen, try a clearer photo or paste the text directly. Otherwise, this is most likely fine.",
                language: "en",
                toolCallsLog: [],
                latencyMs: latencyMs,
                modelTier: .e2b
            )
        }

        // MARK: Stage 2 — classify the extracted text
        let classifyPrompt = TextAgentPrompts.system
            + "\n\n"
            + ImageAgentPrompts.classifyExtractedText(extractedText: extractedText)
        let grammar = GrammarConstraint.textAgentGrammar()

        let rawVerdict = try await inferenceEngine.generate(
            task: classifyPrompt,
            modelTier: .e2b,
            grammar: grammar
        )

        let parsed = try ParsedVerdict.parse(from: rawVerdict)

        // Soft readability check on reasoning.
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
            toolCallsLog: [],
            latencyMs: latencyMs,
            modelTier: .e2b
        )
    }

}
