import Foundation
@testable import GemmaKit

/// A mock inference backend that returns pre-set outputs for testing.
///
/// Use ``nextOutput`` to configure the text that ``generate(prompt:grammar:maxTokens:)``
/// will yield. Supports tracking call history for assertions.
actor MockInferenceBackend: InferenceBackend {

    // MARK: - Configuration

    /// The text to return from the next ``generate`` call.
    /// Each string in the array becomes one token in the stream.
    var nextTokens: [String] = ["mock", " ", "output"]

    /// If set, ``generate`` will throw this error instead of returning tokens.
    var nextError: Error?

    /// If set, ``loadModel`` will throw this error.
    var loadError: Error?

    /// Whether the model is currently loaded.
    private(set) var _isLoaded: Bool = false

    var isLoaded: Bool {
        _isLoaded
    }

    // MARK: - Call Tracking

    /// Records of all ``generate`` calls made to this mock.
    private(set) var generateCalls: [(prompt: String, grammar: GrammarConstraint?, maxTokens: Int)] = []

    /// Records of all ``loadModel`` calls.
    private(set) var loadModelCalls: [ModelTier] = []

    /// Number of times ``unloadModel`` was called.
    private(set) var unloadCount: Int = 0

    // MARK: - InferenceBackend

    func generate(
        prompt: String,
        grammar: GrammarConstraint?,
        maxTokens: Int
    ) async throws -> AsyncStream<String> {
        generateCalls.append((prompt: prompt, grammar: grammar, maxTokens: maxTokens))

        if let error = nextError {
            throw error
        }

        let tokens = nextTokens
        return AsyncStream { continuation in
            for token in tokens {
                continuation.yield(token)
            }
            continuation.finish()
        }
    }

    func loadModel(tier: ModelTier) async throws {
        loadModelCalls.append(tier)

        if let error = loadError {
            throw error
        }

        _isLoaded = true
    }

    func unloadModel() async {
        unloadCount += 1
        _isLoaded = false
    }

    // MARK: - Test Helpers

    /// Resets all recorded calls and configuration.
    func reset() {
        nextTokens = ["mock", " ", "output"]
        nextError = nil
        loadError = nil
        _isLoaded = false
        generateCalls = []
        loadModelCalls = []
        unloadCount = 0
    }

    /// Convenience: set the mock to return a single complete string.
    func setOutput(_ text: String) {
        nextTokens = [text]
    }

    /// Convenience: pre-load the mock so isLoaded returns true.
    func preload() {
        _isLoaded = true
    }
}
