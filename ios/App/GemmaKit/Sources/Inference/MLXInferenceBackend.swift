import Foundation
import os
import MLXLLM
import MLXLMCommon
import MLXHuggingFace
import HuggingFace
import Tokenizers

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
            lock.withLock { modelContainer != nil }
        }
    }

    public func loadModel(tier: ModelTier) async throws {
        logger.info("Loading model \(tier.rawValue) via MLX")

        let configuration = MLXModelRegistry.configuration(for: tier)
        let container = try await LLMModelFactory.shared.loadContainer(
            from: #hubDownloader(),
            using: #huggingFaceTokenizerLoader(),
            configuration: configuration
        )

        lock.withLock { modelContainer = container }

        logger.info("MLX model \(tier.rawValue) loaded")
    }

    public func unloadModel() async {
        lock.withLock { modelContainer = nil }
        logger.info("MLX model unloaded")
    }

    public func generate(
        prompt: String,
        grammar: GrammarConstraint?,
        maxTokens: Int
    ) async throws -> AsyncStream<String> {
        let current = lock.withLock { modelContainer }
        guard let container = current else {
            throw GemScanError.modelNotLoaded(tier: .e2b)
        }

        let (stream, continuation) = AsyncStream<String>.makeStream()

        Task {
            do {
                let output: String = try await container.perform { context in
                    let userInput = UserInput(prompt: prompt)
                    let input = try await context.processor.prepare(input: userInput)
                    var parameters = GenerateParameters()
                    parameters.maxTokens = maxTokens
                    // Explicit closure-arg type and explicit return type pick
                    // the [Int]-callback overload that returns GenerateResult
                    // (vs. the Int-callback overload that returns
                    // GenerateCompletionInfo). The compiler ICEs without
                    // these annotations because the overload is ambiguous.
                    let result: GenerateResult = try MLXLMCommon.generate(
                        input: input,
                        parameters: parameters,
                        context: context
                    ) { (_: [Int]) -> GenerateDisposition in
                        .more
                    }
                    return result.output
                }

                // 2.x's generate() callback yields token IDs, not detokenised
                // strings; emitting tokens incrementally requires a streaming
                // decoder we don't ship yet. For now we yield the full output
                // once so the AsyncStream<String> contract is preserved.
                continuation.yield(output)

                if let grammar = grammar, !grammar.validate(output: output) {
                    self.logger.warning("MLX output failed grammar validation for constraint: \(grammar.name)")
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

