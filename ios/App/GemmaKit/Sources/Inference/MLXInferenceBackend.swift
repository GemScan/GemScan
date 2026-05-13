import Foundation
import os
import MLXLLM

// MARK: - MLXInferenceBackend

/// An ``InferenceBackend`` implementation that uses MLX Swift (MLXLLM) for
/// Apple Silicon-optimised on-device inference.
///
/// Grammar validation is performed post-hoc rather than at sampling time because
/// the MLX Swift runtime does not natively support GBNF-guided decoding.
public final class MLXInferenceBackend: InferenceBackend, @unchecked Sendable {

    // MARK: - Properties

    /// The currently loaded MLX model container, if any.
    private var modelContainer: ModelContainer?

    /// Serial access lock to protect mutable state.
    private let lock = NSLock()

    /// Logger for inference operations.
    private let logger = GemScanLogger.inference

    // MARK: - Initialization

    /// Creates a new MLX inference backend.
    public init() {}

    // MARK: - InferenceBackend Conformance

    public var isLoaded: Bool {
        get async {
            lock.lock()
            defer { lock.unlock() }
            return modelContainer != nil
        }
    }

    public func loadModel(tier: ModelTier) async throws {
        logger.info("Loading model \(tier.rawValue) via MLX")

        let configuration = ModelConfiguration.configuration(for: tier)
        let container = try await ModelContainer.load(configuration: configuration)

        lock.lock()
        modelContainer = container
        lock.unlock()

        logger.info("MLX model \(tier.rawValue) loaded")
    }

    public func unloadModel() async {
        lock.lock()
        modelContainer = nil
        lock.unlock()
        logger.info("MLX model unloaded")
    }

    public func generate(
        prompt: String,
        grammar: GrammarConstraint?,
        maxTokens: Int
    ) async throws -> AsyncStream<String> {
        lock.lock()
        guard let container = modelContainer else {
            lock.unlock()
            throw GemScanError.modelNotLoaded(tier: .e2b)
        }
        lock.unlock()

        let (stream, continuation) = AsyncStream<String>.makeStream()

        Task {
            do {
                let output = try await container.generate(
                    prompt: prompt,
                    maxTokens: maxTokens
                ) { token in
                    continuation.yield(token)
                    return .more
                }

                // Post-hoc grammar validation when a grammar constraint is provided.
                if let grammar = grammar {
                    let fullText = output.summary()
                    if !grammar.validate(output: fullText) {
                        self.logger.warning("MLX output failed grammar validation for constraint: \(grammar.name)")
                    }
                }

                continuation.finish()
            } catch {
                self.logger.error("MLX generation error: \(error.localizedDescription)")
                continuation.finish()
            }
        }

        return stream
    }
}

// MARK: - ModelConfiguration Helpers

private extension ModelConfiguration {

    /// Returns the appropriate MLX model configuration for the given tier.
    ///
    /// E2B and E4B use the mlx-community 8-bit quantised Gemma 4 conversions,
    /// which MLXLLM resolves via the HuggingFace hub on first call to
    /// `ModelContainer.load(configuration:)`. DistilBERT is currently a
    /// placeholder; the production SMS triage model ships as bundled CoreML.
    static func configuration(for tier: ModelTier) -> ModelConfiguration {
        switch tier {
        case .e2b:
            return ModelConfiguration(id: "mlx-community/gemma-4-e2b-it-8bit")
        case .e4b:
            return ModelConfiguration(id: "mlx-community/gemma-4-e4b-it-8bit")
        case .distilbert:
            return ModelConfiguration(id: "distilbert-base-uncased")
        }
    }
}
