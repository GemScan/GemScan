import XCTest
@testable import GemmaKit

/// Tests all six agent task types through the mock pipeline to ensure
/// end-to-end routing, processing, and result delivery.
final class AgentRoundTripTests: XCTestCase {

    private var mockRouter: MockMessageRouter!

    override func setUp() async throws {
        try await super.setUp()
        mockRouter = MockMessageRouter()
    }

    override func tearDown() async throws {
        mockRouter = nil
        try await super.tearDown()
    }

    // MARK: - classifySMS

    func testClassifySMS_SafeMessage() async throws {
        await mockRouter.setVerdict(.safe, confidence: 0.95)

        let task = AgentTask(
            type: .classifySMS,
            payload: .text("Hey, are we still on for lunch?", language: "en")
        )

        let result = try await mockRouter.dispatch(task: task)

        XCTAssertEqual(result.verdict, .safe)
        XCTAssertGreaterThan(result.confidence, 0.9)
        XCTAssertFalse(result.reasoning.isEmpty)

        let dispatchCount = await mockRouter.dispatchCount
        XCTAssertEqual(dispatchCount, 1)
    }

    func testClassifySMS_ScamMessage() async throws {
        await mockRouter.setVerdict(.scam, confidence: 0.98)

        let task = AgentTask(
            type: .classifySMS,
            payload: .text("URGENT: Your bank account is compromised! Click here now!", language: "en")
        )

        let result = try await mockRouter.dispatch(task: task)

        XCTAssertEqual(result.verdict, .scam)
        XCTAssertGreaterThan(result.confidence, 0.95)
    }

    // MARK: - classifyEmail

    func testClassifyEmail_SuspiciousMessage() async throws {
        await mockRouter.setVerdict(.suspicious, confidence: 0.72)

        let task = AgentTask(
            type: .classifyEmail,
            payload: .text("Dear Customer, please verify your account details.", language: "en")
        )

        let result = try await mockRouter.dispatch(task: task)

        XCTAssertEqual(result.verdict, .suspicious)
        XCTAssertGreaterThan(result.confidence, 0.5)
    }

    // MARK: - checkURL

    func testCheckURL_PhishingURL() async throws {
        await mockRouter.setVerdict(.scam, confidence: 0.96)

        let task = AgentTask(
            type: .checkURL,
            payload: .url("https://totallylegit-bank.xyz/verify")
        )

        let result = try await mockRouter.dispatch(task: task)

        XCTAssertEqual(result.verdict, .scam)
        XCTAssertEqual(result.language, "en")
    }

    func testCheckURL_LegitimateURL() async throws {
        await mockRouter.setVerdict(.safe, confidence: 0.99)

        let task = AgentTask(
            type: .checkURL,
            payload: .url("https://www.apple.com")
        )

        let result = try await mockRouter.dispatch(task: task)

        XCTAssertEqual(result.verdict, .safe)
    }

    // MARK: - analyseScreenshot

    func testAnalyseScreenshot() async throws {
        await mockRouter.setVerdict(.suspicious, confidence: 0.65)

        let task = AgentTask(
            type: .analyseScreenshot,
            payload: .image("base64encodedimage==", mimeType: .png)
        )

        let result = try await mockRouter.dispatch(task: task)

        XCTAssertEqual(result.verdict, .suspicious)
        let lastTask = await mockRouter.lastTask
        XCTAssertEqual(lastTask?.type, .analyseScreenshot)
    }

    // MARK: - scoreVoice

    func testScoreVoice() async throws {
        await mockRouter.setVerdict(.scam, confidence: 0.88)

        let task = AgentTask(
            type: .scoreVoice,
            payload: .audio("base64encodedaudio==", durationSeconds: 45.0)
        )

        let result = try await mockRouter.dispatch(task: task)

        XCTAssertEqual(result.verdict, .scam)
    }

    // MARK: - explainVerdict

    func testExplainVerdict() async throws {
        let priorResult = AgentResult(
            taskId: "prior-task",
            agentId: AgentID.textAgent,
            verdict: .scam,
            confidence: 0.97,
            reasoning: ["Phishing attempt detected"],
            language: "en",
            toolCallsLog: [],
            latencyMs: 200,
            modelTier: .e2b
        )

        await mockRouter.setVerdict(.scam, confidence: 0.97)

        let task = AgentTask(
            type: .explainVerdict,
            payload: .multimodal(
                parts: [.text("Explain this verdict", language: "en")],
                priorResult: priorResult
            )
        )

        let result = try await mockRouter.dispatch(task: task)

        XCTAssertEqual(result.verdict, .scam)
    }

    // MARK: - Error Handling

    func testDispatch_Timeout() async throws {
        let error = GemScanError.inferenceTimeout(taskId: "test", limitMs: 5000)
        await mockRouter.setError(error)

        let task = AgentTask(
            type: .classifySMS,
            payload: .text("test message", language: "en"),
            timeoutMs: 100
        )

        do {
            _ = try await mockRouter.dispatch(task: task)
            XCTFail("Expected timeout error")
        } catch {
            // Expected
        }
    }

    // MARK: - Task Properties

    func testTaskPreservesProperties() async throws {
        let task = AgentTask(
            id: "custom-id-123",
            type: .classifySMS,
            payload: .text("Hello", language: "hi"),
            priority: .background,
            timeoutMs: 3000
        )

        _ = try await mockRouter.dispatch(task: task)

        let lastTask = await mockRouter.lastTask
        XCTAssertEqual(lastTask?.id, "custom-id-123")
        XCTAssertEqual(lastTask?.type, .classifySMS)
        XCTAssertEqual(lastTask?.priority, .background)
        XCTAssertEqual(lastTask?.timeoutMs, 3000)
        XCTAssertEqual(lastTask?.payload.language, "hi")
    }
}

// MARK: - MockMessageRouter extension for error setting

extension MockMessageRouter {
    func setError(_ error: Error) {
        self.nextError = error
    }
}
