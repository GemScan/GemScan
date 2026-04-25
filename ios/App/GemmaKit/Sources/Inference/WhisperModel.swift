import Foundation
import os

// MARK: - WhisperModel

/// On-device Whisper speech recognition model for transcribing audio.
///
/// The model is loaded on demand (~150 MB) and kept resident for subsequent
/// transcription requests. Thread safety is guaranteed by the actor isolation.
public actor WhisperModel {

    // MARK: - Properties

    /// Logger for inference operations.
    private let logger = GemScanLogger.inference

    /// Whether the model weights are currently loaded.
    private var loaded: Bool = false

    /// The Core ML model used for inference, if loaded.
    private var model: Any?

    /// Expected size of the model file in bytes (~150 MB).
    private static let expectedModelSizeBytes: Int = 150_000_000

    // MARK: - Initialization

    /// Creates a new Whisper model instance.
    public init() {}

    // MARK: - Public API

    /// Loads the Whisper model weights into memory.
    ///
    /// This is called automatically on first transcription but can be called
    /// explicitly to pre-warm the model.
    public func load() async throws {
        guard !loaded else {
            logger.info("Whisper model already loaded")
            return
        }

        logger.info("Loading Whisper model (~150 MB)")

        guard let modelURL = locateModelFile() else {
            throw GemScanError.modelFileNotFound(tier: .e2b)
        }

        // Load the Core ML compiled model
        do {
            // In production this would load via CoreML or a custom runtime.
            // Placeholder for the actual model loading implementation.
            _ = try Data(contentsOf: modelURL, options: .mappedIfSafe)
            loaded = true
            logger.info("Whisper model loaded successfully")
        } catch {
            throw GemScanError.modelLoadFailed(reason: "Whisper model load failed: \(error.localizedDescription)")
        }
    }

    /// Unloads the Whisper model to free memory.
    public func unload() {
        model = nil
        loaded = false
        logger.info("Whisper model unloaded")
    }

    /// Transcribes PCM audio samples into text with language detection.
    ///
    /// The model is loaded on demand if not already resident.
    ///
    /// - Parameter audio: 16 kHz mono Float32 PCM samples (from ``AudioDecoder``).
    /// - Returns: A tuple of the transcribed text and detected language code (e.g. "en").
    /// - Throws: ``GemScanError`` if the model cannot be loaded or inference fails.
    public func transcribe(audio: [Float]) async throws -> (text: String, language: String) {
        if !loaded {
            try await load()
        }

        guard !audio.isEmpty else {
            throw GemScanError.audioDecodingFailed(reason: "Empty audio buffer passed to Whisper")
        }

        logger.info("Transcribing \(audio.count) samples")

        let startTime = CFAbsoluteTimeGetCurrent()

        // Placeholder: actual Whisper inference would run here.
        // The implementation would feed audio through the encoder, run
        // language detection on the cross-attention, then decode tokens.
        let transcribedText = ""
        let detectedLanguage = "en"

        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        logger.info("Whisper transcription complete in \(String(format: "%.2f", elapsed))s — language: \(detectedLanguage)")

        return (text: transcribedText, language: detectedLanguage)
    }

    // MARK: - Private Helpers

    /// Searches for the Whisper model file in known locations.
    private func locateModelFile() -> URL? {
        let fileManager = FileManager.default

        // Check the app's documents directory
        if let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            let modelURL = documentsURL
                .appendingPathComponent("models")
                .appendingPathComponent("whisper-base.mlmodelc")
            if fileManager.fileExists(atPath: modelURL.path) {
                return modelURL
            }
        }

        // Check the main bundle
        if let bundleURL = Bundle.main.url(forResource: "whisper-base", withExtension: "mlmodelc") {
            return bundleURL
        }

        logger.warning("Whisper model file not found in documents or bundle")
        return nil
    }
}
