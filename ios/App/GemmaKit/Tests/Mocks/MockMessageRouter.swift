import Foundation
@testable import GemmaKit

/// A mock message router that returns pre-configured results for testing.
///
/// Configure ``nextResult`` to control the ``AgentResult`` returned by
/// ``dispatch(task:)``. Tracks all dispatched tasks for assertion.
actor MockMessageRouter: MessageRouterProtocol {

    // MARK: - Configuration

    /// The result to return from the next ``dispatch`` call.
    var nextResult: AgentResult?

    /// If set, ``dispatch`` will throw this error.
    var nextError: Error?

    /// Optional delay in nanoseconds to simulate latency.
    var simulatedDelayNs: UInt64 = 0

    // MARK: - Call Tracking

    /// All tasks dispatched to this mock.
    private(set) var dispatchedTasks: [AgentTask] = []

    // MARK: - MessageRouterProtocol

    func dispatch(task: AgentTask) async throws -> AgentResult {
        dispatchedTasks.append(task)

        if simulatedDelayNs > 0 {
            try await Task.sleep(nanoseconds: simulatedDelayNs)
        }

        if let error = nextError {
            throw error
        }

        if let result = nextResult {
            return result
        }

        // Return a default safe result
        return AgentResult(
            taskId: task.id,
            agentId: AgentID.orchestrator,
            verdict: .safe,
            confidence: 0.95,
            reasoning: ["Mock analysis: message appears safe"],
            language: "en",
            toolCallsLog: [],
            latencyMs: 100,
            modelTier: .e2b,
            escalatedToE4B: false
        )
    }

    // MARK: - Test Helpers

    /// Resets all configuration and call history.
    func reset() {
        nextResult = nil
        nextError = nil
        simulatedDelayNs = 0
        dispatchedTasks = []
    }

    /// Sets the mock to return a specific verdict.
    func setVerdict(_ verdict: ScamVerdict, confidence: Double = 0.9) {
        nextResult = AgentResult(
            taskId: "mock-task",
            agentId: AgentID.orchestrator,
            verdict: verdict,
            confidence: confidence,
            reasoning: ["Mock reasoning for \(verdict.rawValue)"],
            language: "en",
            toolCallsLog: [],
            latencyMs: 50,
            modelTier: .e2b,
            escalatedToE4B: false
        )
    }

    /// Returns the number of tasks dispatched.
    var dispatchCount: Int {
        dispatchedTasks.count
    }

    /// Returns the last dispatched task, if any.
    var lastTask: AgentTask? {
        dispatchedTasks.last
    }
}
