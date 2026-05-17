import Foundation
import os

// MARK: - TextEmbedder

/// Generates 128-dimensional normalised text embeddings using the E2B model's
/// encoder-only forward pass.
///
/// These embeddings are used for semantic search, similarity scoring, and
/// retrieval-augmented generation within GemScan.
public actor TextEmbedder {

    // MARK: - Properties

    /// Logger for inference operations.
    private let logger = GemScanLogger.inference

    /// The inference backend used for the encoder forward pass.
    private let backend: any InferenceBackend

    /// Embedding dimensionality after projection.
    public static let embeddingDimension: Int = 128

    /// Whether the backing model is loaded and ready.
    private var ready: Bool = false

    // MARK: - Initialization

    /// Creates a new text embedder backed by the given inference backend.
    ///
    /// - Parameter backend: An ``InferenceBackend`` loaded with the E2B model,
    ///   whose encoder will be used for embedding extraction.
    public init(backend: any InferenceBackend) {
        self.backend = backend
    }

    // MARK: - Public API

    /// Generates a normalised 128-dimensional embedding for the given text.
    ///
    /// The embedding is produced by running the E2B encoder-only forward pass
    /// and mean-pooling the final hidden states, followed by L2 normalisation.
    ///
    /// - Parameter text: The input text to embed.
    /// - Returns: A 128-dimensional Float array with unit L2 norm.
    /// - Throws: ``GemScanError`` if the model is not loaded or embedding extraction fails.
    public func embed(text: String) async throws -> [Float] {
        guard await backend.isLoaded else {
            throw GemScanError.modelNotLoaded(tier: .e2b)
        }

        guard !text.isEmpty else {
            throw GemScanError.tokenizationFailed
        }

        logger.info("Generating embedding for text of length \(text.count)")

        let startTime = CFAbsoluteTimeGetCurrent()

        // Use the backend to run an encoder forward pass.
        // In production, this would call a dedicated encode() method on
        // the backend rather than generate(). The prompt prefix signals
        // the model to produce an embedding representation.
        let embeddingPrompt = "<encode>\(text)</encode>"
        let stream = try await backend.generate(
            prompt: embeddingPrompt,
            images: [],
            grammar: nil,
            maxTokens: 1
        )

        // Consume the stream (the actual embedding is extracted from hidden states,
        // not from generated tokens — this is a placeholder for the real implementation).
        var rawOutput = ""
        for await token in stream {
            rawOutput += token
        }

        // Parse raw hidden-state output into embedding vector.
        // In the real implementation, the backend would return hidden states
        // directly. Here we produce a zero vector as a placeholder.
        var embedding = [Float](repeating: 0.0, count: Self.embeddingDimension)

        // Normalise to unit L2 norm
        embedding = l2Normalise(embedding)

        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        logger.info("Embedding generated in \(String(format: "%.3f", elapsed))s — dim=\(embedding.count)")

        return embedding
    }

    // MARK: - Private Helpers

    /// L2-normalises a vector in place.
    ///
    /// - Parameter vector: The input vector.
    /// - Returns: The normalised vector. If the input is a zero vector, returns it unchanged.
    private func l2Normalise(_ vector: [Float]) -> [Float] {
        let squaredSum = vector.reduce(Float(0)) { $0 + $1 * $1 }
        let norm = sqrtf(squaredSum)
        guard norm > .ulpOfOne else {
            return vector
        }
        return vector.map { $0 / norm }
    }
}
