import Foundation
import os

/// Specialist agent for voice call scam detection.
///
/// `VoiceAgent` follows a three-step pipeline:
/// 1. Transcribe audio via ``WhisperASR``.
/// 2. Run ``AudioSealDetector`` for deepfake/synthetic voice detection.
/// 3. Check phone reputation and generate a grammar-constrained verdict.
///
/// MCP tools used: `sqlite_vec`, `phone_reputation`.
public actor VoiceAgent {

    // MARK: - Properties

    /// The on-device inference engine for LLM generation.
    private let inferenceEngine: InferenceEngine

    /// Whisper-based automatic speech recognition.
    private let whisperASR: WhisperASR

    /// AudioSeal-based deepfake voice detection.
    private let audioSealDetector: AudioSealDetector

    /// Logger for agent events.
    private let logger = GemScanLogger.agents

    // MARK: - Initialization

    /// Creates a new voice agent with the given dependencies.
    ///
    /// - Parameters:
    ///   - inferenceEngine: The shared inference engine for LLM calls.
    ///   - whisperASR: The Whisper ASR instance for transcription.
    ///   - audioSealDetector: The AudioSeal detector for deepfake analysis.
    public init(
        inferenceEngine: InferenceEngine,
        whisperASR: WhisperASR = WhisperASR(),
        audioSealDetector: AudioSealDetector = AudioSealDetector()
    ) {
        self.inferenceEngine = inferenceEngine
        self.whisperASR = whisperASR
        self.audioSealDetector = audioSealDetector
    }

    // MARK: - Public API

    /// Analyses a voice call recording for scam indicators and returns a verdict.
    ///
    /// - Parameter task: The agent task containing an `.audio` payload.
    /// - Returns: An ``AgentResult`` with the classification verdict.
    /// - Throws: ``GemScanError`` on inference, transcription, or parsing failure.
    public func analyse(task: AgentTask) async throws -> AgentResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        logger.info("VoiceAgent starting analysis for task \(task.id)")

        guard case let .audio(base64Data, _) = task.payload else {
            throw GemScanError.inferenceError(message: "VoiceAgent received non-audio payload")
        }

        // MARK: Step 1 — Decode and save audio to temporary file

        guard let audioData = Data(base64Encoded: base64Data) else {
            throw GemScanError.audioDecodingFailed(reason: "Invalid base64 audio data")
        }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wav")

        try audioData.write(to: tempURL)
        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }

        // MARK: Step 2 — Parallel: Whisper ASR + AudioSeal detection

        var toolCallRecords: [ToolCallRecord] = []

        async let asrResultTask = whisperASR.transcribe(fileURL: tempURL)
        async let deepfakeResultTask = audioSealDetector.detect(fileURL: tempURL)

        let asrResult: WhisperASR.ASRResult
        let deepfakeResult: AudioSealDetector.DetectionResult

        do {
            asrResult = try await asrResultTask
            deepfakeResult = try await deepfakeResultTask
        } catch {
            throw GemScanError.audioIngestionUnavailable(reason: "ASR or deepfake detection failed: \(error.localizedDescription)")
        }

        logger.info("VoiceAgent transcription: \(asrResult.text.prefix(100))..., deepfake prob: \(String(format: "%.4f", deepfakeResult.probability))")

        // MARK: Step 3 — Phone reputation check

        let phoneReputation = await checkPhoneReputation(
            transcript: asrResult.text,
            toolCallRecords: &toolCallRecords
        )

        // MARK: Step 4 — Vector similarity search

        let vectorResult = await vectorSearch(
            transcript: asrResult.text,
            toolCallRecords: &toolCallRecords
        )

        // MARK: Step 5 — Grammar-constrained generation

        let prompt = VoiceAgentPrompts.system + "\n\n" + VoiceAgentPrompts.scoreVoice(
            transcript: asrResult.text,
            language: asrResult.language,
            deepfakeProbability: deepfakeResult.probability,
            deepfakeClassification: deepfakeResult.classification.rawValue,
            phoneReputation: phoneReputation,
            vectorResult: vectorResult
        )

        let grammar = GrammarConstraint.voiceAgentGrammar()

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
            logger.info("VoiceAgent reasoning grade level \(String(format: "%.1f", grade)) exceeds threshold (soft enforcement)")
        }

        let latencyMs = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)

        logger.info("VoiceAgent completed: verdict=\(parsed.verdict.rawValue), confidence=\(String(format: "%.3f", parsed.confidence)), latency=\(latencyMs)ms")

        return AgentResult(
            taskId: task.id,
            agentId: AgentID.voiceAgent,
            verdict: parsed.verdict,
            confidence: parsed.confidence,
            reasoning: parsed.reasoning,
            language: asrResult.language,
            toolCallsLog: toolCallRecords,
            latencyMs: latencyMs,
            modelTier: .e2b
        )
    }

    // MARK: - Private Helpers

    /// Checks phone reputation for numbers extracted from the transcript.
    ///
    /// - Parameters:
    ///   - transcript: The transcribed audio text.
    ///   - toolCallRecords: Inout array to append tool call records to.
    /// - Returns: A formatted phone reputation result string.
    private func checkPhoneReputation(
        transcript: String,
        toolCallRecords: inout [ToolCallRecord]
    ) async -> String {
        // TODO: Integrate with MCP client to call phone_reputation.
        // Extract phone numbers from transcript first.
        logger.info("VoiceAgent would call phone_reputation for extracted numbers")

        return "Phone reputation check pending (MCP integration required)."
    }

    /// Performs vector similarity search against known scam voice patterns.
    ///
    /// - Parameters:
    ///   - transcript: The transcribed audio text to search against.
    ///   - toolCallRecords: Inout array to append tool call records to.
    /// - Returns: A formatted vector search result string.
    private func vectorSearch(
        transcript: String,
        toolCallRecords: inout [ToolCallRecord]
    ) async -> String {
        // TODO: Integrate with MCP client to call sqlite_vec.
        logger.info("VoiceAgent would call sqlite_vec for vector similarity search")

        return "Vector similarity search pending (MCP integration required)."
    }
}
