import XCTest
@testable import GemmaKit

/// Tests for InferenceEngine using a mock backend.
final class InferenceEngineTests: XCTestCase {

    private var e2bBackend: MockInferenceBackend!

    override func setUp() async throws {
        try await super.setUp()
        e2bBackend = MockInferenceBackend()
    }

    override func tearDown() async throws {
        e2bBackend = nil
        try await super.tearDown()
    }

    // MARK: - Model Loading

    func testWarmLoadE2B_LoadsModel() async throws {
        let loader = ModelLoader()
        _ = InferenceEngine(e2bBackend: e2bBackend, modelLoader: loader)

        // MockInferenceBackend starts unloaded, so loadModel should be called
        await e2bBackend.preload()
        let isLoaded = await e2bBackend.isLoaded
        XCTAssertTrue(isLoaded)
    }

    // MARK: - Generation

    func testGenerate_E2B_ReturnsTokens() async throws {
        await e2bBackend.preload()
        await e2bBackend.setOutput("{\"verdict\":\"safe\",\"confidence\":0.95}")

        let loader = ModelLoader()
        let engine = InferenceEngine(e2bBackend: e2bBackend, modelLoader: loader)

        let result = try await engine.generate(
            task: "Classify this message",
            modelTier: .e2b
        )

        XCTAssertEqual(result, "{\"verdict\":\"safe\",\"confidence\":0.95}")

        let calls = await e2bBackend.generateCalls
        XCTAssertEqual(calls.count, 1)
        XCTAssertEqual(calls[0].prompt, "Classify this message")
    }

    func testGenerate_ModelNotLoaded_Throws() async throws {
        // e2bBackend is NOT preloaded
        let loader = ModelLoader()
        let engine = InferenceEngine(e2bBackend: e2bBackend, modelLoader: loader)

        do {
            _ = try await engine.generate(task: "test", modelTier: .e2b)
            XCTFail("Expected modelNotLoaded error")
        } catch let error as GemScanError {
            if case .modelNotLoaded(let tier) = error {
                XCTAssertEqual(tier, .e2b)
            } else {
                XCTFail("Expected modelNotLoaded, got: \(error)")
            }
        }
    }

    // MARK: - Token Streaming

    func testGenerate_StreamsTokens() async throws {
        await e2bBackend.preload()
        await e2bBackend.setTokens(["Hello", " ", "world", "!"])

        let loader = ModelLoader()
        let engine = InferenceEngine(e2bBackend: e2bBackend, modelLoader: loader)

        var receivedTokens: [String] = []
        let result = try await engine.generate(
            task: "test",
            modelTier: .e2b,
            tokenHandler: { token in
                receivedTokens.append(token)
            }
        )

        XCTAssertEqual(result, "Hello world!")
        XCTAssertEqual(receivedTokens, ["Hello", " ", "world", "!"])
    }

    // MARK: - Backend Error Propagation

    func testGenerate_BackendError_Propagates() async throws {
        await e2bBackend.preload()
        await e2bBackend.setNextError(GemScanError.inferenceError(message: "test failure"))

        let loader = ModelLoader()
        let engine = InferenceEngine(e2bBackend: e2bBackend, modelLoader: loader)

        do {
            _ = try await engine.generate(task: "test", modelTier: .e2b)
            XCTFail("Expected error propagation")
        } catch {
            // Expected
        }
    }

    // MARK: - Grammar Constraints

    func testGenerate_PassesGrammarToBackend() async throws {
        await e2bBackend.preload()
        await e2bBackend.setOutput("{\"verdict\":\"safe\"}")

        let loader = ModelLoader()
        let engine = InferenceEngine(e2bBackend: e2bBackend, modelLoader: loader)

        let grammar = GrammarConstraint.json
        _ = try await engine.generate(
            task: "test",
            modelTier: .e2b,
            grammar: grammar
        )

        let calls = await e2bBackend.generateCalls
        XCTAssertEqual(calls.count, 1)
        XCTAssertNotNil(calls[0].grammar)
    }
}

// MARK: - MockInferenceBackend convenience extensions

extension MockInferenceBackend {
    func setTokens(_ tokens: [String]) {
        self.nextTokens = tokens
    }

    func setNextError(_ error: Error) {
        self.nextError = error
    }
}
