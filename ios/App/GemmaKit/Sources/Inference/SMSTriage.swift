import Foundation
import CoreML
import os

// MARK: - SMSTriage

/// DistilBERT-based SMS classifier for on-device message filtering.
///
/// Uses a Core ML compiled `.mlmodelc` model to classify SMS messages by
/// sender and message content hashes. This class is designed to be usable
/// both from the main app and from the `ILMessageFilterExtension`.
public final class SMSTriage: @unchecked Sendable {

    // MARK: - Properties

    /// Logger for inference operations.
    private let logger = GemScanLogger.inference

    /// The compiled Core ML model, if loaded.
    private var model: MLModel?

    /// Serial access lock.
    private let lock = NSLock()

    // MARK: - Initialization

    /// Creates a new SMS triage classifier.
    public init() {}

    // MARK: - Public API

    /// Classifies an SMS message using sender and message hashes.
    ///
    /// The model is loaded on first use and kept resident for subsequent calls.
    ///
    /// - Parameters:
    ///   - senderHash: A SHA-256 hash of the sender identifier (PII-safe).
    ///   - messageHash: A SHA-256 hash of the message content (PII-safe).
    /// - Returns: A ``TriageResult`` with the predicted label and confidence.
    /// - Throws: ``GemScanError`` if the model cannot be loaded or prediction fails.
    public func classify(senderHash: String, messageHash: String) async throws -> TriageResult {
        let coreMLModel = try loadModelIfNeeded()

        logger.info("Classifying SMS — sender hash length: \(senderHash.count), message hash length: \(messageHash.count)")

        let startTime = CFAbsoluteTimeGetCurrent()

        // Build the feature provider from hashed inputs
        let featureProvider = try buildFeatureProvider(
            senderHash: senderHash,
            messageHash: messageHash
        )

        // Run prediction
        let prediction: MLFeatureProvider
        do {
            prediction = try await coreMLModel.prediction(from: featureProvider)
        } catch {
            throw GemScanError.modelLoadFailed(reason: "Core ML prediction failed: \(error.localizedDescription)")
        }

        // Extract results
        let result = parseTriageOutput(prediction: prediction, senderHash: senderHash)

        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        logger.info("SMS classified as \(result.label.rawValue) (confidence: \(String(format: "%.3f", result.confidence))) in \(String(format: "%.3f", elapsed))s")

        return result
    }

    // MARK: - Extension Factory

    /// Creates an SMSTriage instance configured for use inside an ILMessageFilterExtension.
    ///
    /// Loads the model from the shared App Group container path stored by the main app
    /// via ``ModelLoader/syncPathToAppGroup(tier:path:)``.
    ///
    /// - Returns: A configured ``SMSTriage`` instance.
    public static func extensionInstance() -> SMSTriage {
        return SMSTriage()
    }

    // MARK: - Private Helpers

    /// Loads the Core ML model if not already loaded.
    private func loadModelIfNeeded() throws -> MLModel {
        lock.lock()
        defer { lock.unlock() }

        if let existing = model {
            return existing
        }

        guard let modelURL = locateCompiledModel() else {
            throw GemScanError.modelFileNotFound(tier: .distilbert)
        }

        do {
            let config = MLModelConfiguration()
            config.computeUnits = .cpuAndNeuralEngine
            let loadedModel = try MLModel(contentsOf: modelURL, configuration: config)
            model = loadedModel
            logger.info("SMS triage Core ML model loaded from \(modelURL.path)")
            return loadedModel
        } catch {
            throw GemScanError.modelLoadFailed(reason: "Failed to load SMS triage model: \(error.localizedDescription)")
        }
    }

    /// Searches for the compiled .mlmodelc in known locations.
    private func locateCompiledModel() -> URL? {
        // Check shared App Group container first (for extension use)
        if let defaults = UserDefaults(suiteName: SharedContainerSchema.appGroupId),
           let pathString = defaults.string(forKey: SharedContainerSchema.distilbertModelPath) {
            let url = URL(fileURLWithPath: pathString)
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }

        // Check the app's documents directory
        let fileManager = FileManager.default
        if let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            let modelURL = documentsURL
                .appendingPathComponent("models")
                .appendingPathComponent("sms-triage.mlmodelc")
            if fileManager.fileExists(atPath: modelURL.path) {
                return modelURL
            }
        }

        // Check the main bundle
        if let bundleURL = Bundle.main.url(forResource: "sms-triage", withExtension: "mlmodelc") {
            return bundleURL
        }

        logger.warning("SMS triage model file not found")
        return nil
    }

    /// Builds a Core ML feature provider from the hashed sender and message.
    private func buildFeatureProvider(
        senderHash: String,
        messageHash: String
    ) throws -> MLFeatureProvider {
        let features: [String: MLFeatureValue] = [
            "sender_hash": MLFeatureValue(string: senderHash),
            "message_hash": MLFeatureValue(string: messageHash),
        ]

        do {
            return try MLDictionaryFeatureProvider(dictionary: features)
        } catch {
            throw GemScanError.tokenizationFailed
        }
    }

    /// Parses the Core ML prediction output into a ``TriageResult``.
    private func parseTriageOutput(prediction: MLFeatureProvider, senderHash: String) -> TriageResult {
        // Attempt to read standard classification outputs
        if let labelValue = prediction.featureValue(for: "label") {
            // MLFeatureValue.stringValue is non-Optional (returns "" if the
            // feature isn't a string), so it can't be unwrapped via if-let.
            let labelString = labelValue.stringValue
            let label = TriageLabel(rawValue: labelString) ?? .unknown

            let confidence: Double
            if let probsValue = prediction.featureValue(for: "labelProbability"),
               let probs = probsValue.dictionaryValue as? [String: Double],
               let topProb = probs[labelString] {
                confidence = topProb
            } else {
                confidence = 1.0
            }

            return TriageResult(senderHash: senderHash, label: label, confidence: confidence)
        }

        // Fallback for unexpected output schema
        logger.warning("Unexpected Core ML output schema — returning unknown")
        return TriageResult(senderHash: senderHash, label: .unknown, confidence: 0.0)
    }
}
