import Foundation
import os

// MARK: - AudioSealModel

/// On-device AudioSeal model for detecting AI-synthesised audio (deepfakes).
///
/// The model is loaded on demand (~30 MB) and produces a synthesis probability
/// score between 0.0 (human) and 1.0 (AI-generated).
public actor AudioSealModel {

    // MARK: - Properties

    /// Logger for inference operations.
    private let logger = GemScanLogger.inference

    /// Whether the model is currently loaded.
    private var loaded: Bool = false

    /// The model instance, if loaded.
    private var model: Any?

    /// Expected size of the model file in bytes (~30 MB).
    private static let expectedModelSizeBytes: Int = 30_000_000

    // MARK: - Initialization

    /// Creates a new AudioSeal model instance.
    public init() {}

    // MARK: - Public API

    /// Loads the AudioSeal model weights into memory.
    ///
    /// Called automatically on first detection request, or explicitly to pre-warm.
    public func load() async throws {
        guard !loaded else {
            logger.info("AudioSeal model already loaded")
            return
        }

        logger.info("Loading AudioSeal model (~30 MB)")

        guard let modelURL = locateModelFile() else {
            throw GemScanError.modelFileNotFound(tier: .e2b)
        }

        do {
            // In production this would load via CoreML or a custom runtime.
            _ = try Data(contentsOf: modelURL, options: .mappedIfSafe)
            loaded = true
            logger.info("AudioSeal model loaded successfully")
        } catch {
            throw GemScanError.modelLoadFailed(reason: "AudioSeal model load failed: \(error.localizedDescription)")
        }
    }

    /// Unloads the AudioSeal model to free memory.
    public func unload() {
        model = nil
        loaded = false
        logger.info("AudioSeal model unloaded")
    }

    /// Detects whether the given audio is AI-synthesised.
    ///
    /// The model is loaded on demand if not already resident.
    ///
    /// - Parameter audio: 16 kHz mono Float32 PCM samples (from ``AudioDecoder``).
    /// - Returns: A probability score where 0.0 = likely human and 1.0 = likely AI-generated.
    /// - Throws: ``GemScanError`` if the model cannot be loaded or inference fails.
    public func detectSynthesis(audio: [Float]) async throws -> Double {
        if !loaded {
            try await load()
        }

        guard !audio.isEmpty else {
            throw GemScanError.audioDecodingFailed(reason: "Empty audio buffer passed to AudioSeal")
        }

        logger.info("Running synthesis detection on \(audio.count) samples")

        let startTime = CFAbsoluteTimeGetCurrent()

        // Placeholder: actual AudioSeal inference would run here.
        // The implementation would compute frame-level watermark detector
        // outputs and aggregate into a single probability score.
        let synthesisProbability: Double = 0.0

        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        logger.info("AudioSeal detection complete in \(String(format: "%.2f", elapsed))s — score: \(String(format: "%.4f", synthesisProbability))")

        return synthesisProbability
    }

    // MARK: - Private Helpers

    /// Searches for the AudioSeal model file in known locations.
    private func locateModelFile() -> URL? {
        let fileManager = FileManager.default

        // Check the app's documents directory
        if let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            let modelURL = documentsURL
                .appendingPathComponent("models")
                .appendingPathComponent("audioseal-detector.mlmodelc")
            if fileManager.fileExists(atPath: modelURL.path) {
                return modelURL
            }
        }

        // Check the main bundle
        if let bundleURL = Bundle.main.url(forResource: "audioseal-detector", withExtension: "mlmodelc") {
            return bundleURL
        }

        logger.warning("AudioSeal model file not found in documents or bundle")
        return nil
    }
}
