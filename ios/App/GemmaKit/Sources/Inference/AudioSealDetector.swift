import Foundation
import os

// MARK: - AudioSealDetector

/// High-level deepfake audio detection wrapper combining ``AudioSealModel``
/// with threshold-based classification.
///
/// This actor provides a simplified interface for determining whether an audio
/// file contains AI-synthesised speech, with configurable detection thresholds.
public actor AudioSealDetector {

    // MARK: - Properties

    /// The underlying AudioSeal model instance.
    private let audioSealModel: AudioSealModel

    /// The audio decoder for converting compressed audio to PCM.
    private let audioDecoder: AudioDecoder

    /// Logger for inference operations.
    private let logger = GemScanLogger.inference

    /// The probability threshold above which audio is classified as synthetic.
    private let syntheticThreshold: Double

    // MARK: - Types

    /// Classification result for an audio deepfake detection check.
    public enum Classification: String, Sendable {
        /// The audio is likely produced by a human.
        case human
        /// The audio is likely AI-generated or synthetic.
        case synthetic
        /// The result is ambiguous and falls near the decision boundary.
        case uncertain
    }

    /// The full result of a deepfake detection operation.
    public struct DetectionResult: Sendable {
        /// The raw synthesis probability (0.0 = human, 1.0 = AI).
        public let probability: Double
        /// The threshold-based classification.
        public let classification: Classification
        /// Time taken for detection in seconds.
        public let processingTimeSeconds: Double
    }

    // MARK: - Initialization

    /// Creates a new AudioSeal detector.
    ///
    /// - Parameters:
    ///   - audioSealModel: The AudioSeal model to use. Defaults to a new instance.
    ///   - audioDecoder: The audio decoder to use. Defaults to a new instance.
    ///   - syntheticThreshold: Probability threshold for synthetic classification. Defaults to 0.5.
    public init(
        audioSealModel: AudioSealModel = AudioSealModel(),
        audioDecoder: AudioDecoder = AudioDecoder(),
        syntheticThreshold: Double = 0.5
    ) {
        self.audioSealModel = audioSealModel
        self.audioDecoder = audioDecoder
        self.syntheticThreshold = syntheticThreshold
    }

    // MARK: - Public API

    /// Analyzes an audio file for AI synthesis.
    ///
    /// This method handles decoding the audio, running the AudioSeal detector,
    /// and applying threshold-based classification.
    ///
    /// - Parameter fileURL: The URL of the audio file to analyze.
    /// - Returns: A ``DetectionResult`` with the probability, classification, and timing.
    /// - Throws: ``GemScanError`` if decoding or detection fails.
    public func detect(fileURL: URL) async throws -> DetectionResult {
        logger.info("Starting deepfake detection for \(fileURL.lastPathComponent)")

        let startTime = CFAbsoluteTimeGetCurrent()

        // Decode audio to 16kHz mono PCM
        let samples = try await audioDecoder.decode(fileURL: fileURL)

        // Run AudioSeal detection
        let probability = try await audioSealModel.detectSynthesis(audio: samples)

        let processingTime = CFAbsoluteTimeGetCurrent() - startTime

        // Classify based on threshold with an uncertainty band
        let classification: Classification
        let uncertaintyMargin = 0.15
        if probability >= syntheticThreshold + uncertaintyMargin {
            classification = .synthetic
        } else if probability <= syntheticThreshold - uncertaintyMargin {
            classification = .human
        } else {
            classification = .uncertain
        }

        logger.info("Detection complete: p=\(String(format: "%.4f", probability)), class=\(classification.rawValue), time=\(String(format: "%.2f", processingTime))s")

        return DetectionResult(
            probability: probability,
            classification: classification,
            processingTimeSeconds: processingTime
        )
    }

    /// Pre-loads the AudioSeal model so the first detection is fast.
    public func warmUp() async throws {
        try await audioSealModel.load()
    }

    /// Unloads the AudioSeal model to reclaim memory.
    public func tearDown() async {
        await audioSealModel.unload()
    }
}
