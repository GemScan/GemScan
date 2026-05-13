import Foundation
import os

// MARK: - InferenceBackend Protocol

/// A protocol defining the contract for on-device inference backends.
///
/// Conforming types wrap a specific inference runtime (e.g. MLX Swift or llama.cpp)
/// and expose a uniform streaming generation interface to ``InferenceEngine``.
public protocol InferenceBackend: Sendable {

    /// Generates text from the given prompt, optionally constrained by a GBNF grammar.
    ///
    /// - Parameters:
    ///   - prompt: The input text prompt for the model.
    ///   - grammar: An optional ``GrammarConstraint`` that restricts the output format.
    ///   - maxTokens: The maximum number of tokens to generate.
    /// - Returns: An `AsyncStream` that yields generated text tokens incrementally.
    func generate(prompt: String, grammar: GrammarConstraint?, maxTokens: Int) async throws -> AsyncStream<String>

    /// Loads a model of the specified tier into memory.
    ///
    /// - Parameter tier: The model tier to load (e.g. `.e2b`).
    func loadModel(tier: ModelTier) async throws

    /// Unloads the currently loaded model and frees associated memory.
    func unloadModel() async

    /// Whether a model is currently loaded and ready for inference.
    var isLoaded: Bool { get async }
}
