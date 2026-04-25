import Foundation
import os

// MARK: - WhisperASR

/// High-level automatic speech recognition wrapper combining ``WhisperModel``
/// transcription with language detection.
///
/// This actor provides a simplified interface for the audio analysis pipeline,
/// handling model lifecycle and returning structured transcription results.
public actor WhisperASR {

    // MARK: - Properties

    /// The underlying Whisper model instance.
    private let whisperModel: WhisperModel

    /// The audio decoder for converting compressed audio to PCM.
    private let audioDecoder: AudioDecoder

    /// Logger for inference operations.
    private let logger = GemScanLogger.inference

    // MARK: - Types

    /// The result of a speech recognition operation.
    public struct ASRResult: Sendable {
        /// The transcribed text content.
        public let text: String
        /// The detected BCP-47 language code (e.g. "en", "es", "ja").
        public let language: String
        /// Duration of the audio in seconds.
        public let audioDurationSeconds: Double
        /// Time taken for transcription in seconds.
        public let processingTimeSeconds: Double
    }

    // MARK: - Initialization

    /// Creates a new WhisperASR instance.
    ///
    /// - Parameters:
    ///   - whisperModel: The Whisper model to use. Defaults to a new instance.
    ///   - audioDecoder: The audio decoder to use. Defaults to a new instance.
    public init(
        whisperModel: WhisperModel = WhisperModel(),
        audioDecoder: AudioDecoder = AudioDecoder()
    ) {
        self.whisperModel = whisperModel
        self.audioDecoder = audioDecoder
    }

    // MARK: - Public API

    /// Transcribes an audio file with automatic language detection.
    ///
    /// This method handles the full pipeline: decoding the audio file to PCM,
    /// running Whisper inference, and packaging the result.
    ///
    /// - Parameter fileURL: The URL of the audio file to transcribe.
    /// - Returns: An ``ASRResult`` containing the transcription, language, and timing metadata.
    /// - Throws: ``GemScanError`` if decoding or transcription fails.
    public func transcribe(fileURL: URL) async throws -> ASRResult {
        logger.info("Starting ASR pipeline for \(fileURL.lastPathComponent)")

        let startTime = CFAbsoluteTimeGetCurrent()

        // Decode audio to 16kHz mono PCM
        let samples = try await audioDecoder.decode(fileURL: fileURL)
        let audioDuration = Double(samples.count) / 16_000.0

        // Run Whisper transcription
        let (text, language) = try await whisperModel.transcribe(audio: samples)

        let processingTime = CFAbsoluteTimeGetCurrent() - startTime
        let realTimeFactor = audioDuration > 0 ? processingTime / audioDuration : 0

        logger.info("ASR complete: \(text.count) chars, language=\(language), RTF=\(String(format: "%.2f", realTimeFactor))")

        return ASRResult(
            text: text,
            language: language,
            audioDurationSeconds: audioDuration,
            processingTimeSeconds: processingTime
        )
    }

    /// Pre-loads the Whisper model so the first transcription is fast.
    public func warmUp() async throws {
        try await whisperModel.load()
    }

    /// Unloads the Whisper model to reclaim memory.
    public func tearDown() async {
        await whisperModel.unload()
    }
}
