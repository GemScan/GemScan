import Foundation
import os

/// Protocol defining the message routing contract for the agent pipeline.
///
/// Conforming types accept an ``AgentTask`` and return an ``AgentResult``
/// after routing the task through the appropriate agent(s).
public protocol MessageRouterProtocol: Sendable {
    /// Dispatches a task to the appropriate agent and returns the result.
    ///
    /// - Parameter task: The agent task to dispatch.
    /// - Returns: The final ``AgentResult`` after agent processing.
    /// - Throws: ``GemScanError`` on routing, inference, or timeout errors.
    func dispatch(task: AgentTask) async throws -> AgentResult
}

/// Routes incoming agent tasks to the correct specialist agent with timeout enforcement.
///
/// `MessageRouter` serves as the entry point for the analysis pipeline. It:
/// 1. Logs the routing decision.
/// 2. Wraps the dispatch in a timeout derived from `task.timeoutMs`.
/// 3. Delegates to the ``OrchestratorAgent`` for actual agent selection and execution.
///
/// Routing rules:
/// - `classifySMS`, `classifyEmail` -> TextAgent (via Orchestrator)
/// - `checkURL` -> URLAgent (via Orchestrator)
/// - `analyseScreenshot` -> ImageAgent (via Orchestrator)
/// - `explainVerdict` -> OrchestratorAgent directly
public actor MessageRouter: MessageRouterProtocol {

    // MARK: - Properties

    /// The orchestrator agent that manages specialist agent delegation.
    private let orchestrator: OrchestratorAgent

    /// Logger for routing decisions and lifecycle events.
    private let logger = GemScanLogger.router

    // MARK: - Initialization

    /// Creates a new message router with the given orchestrator.
    ///
    /// - Parameter orchestrator: The orchestrator agent to delegate to.
    ///   Defaults to the shared singleton.
    public init(orchestrator: OrchestratorAgent = .shared) {
        self.orchestrator = orchestrator
    }

    // MARK: - MessageRouterProtocol

    /// Dispatches a task with timeout enforcement.
    ///
    /// The timeout is taken from ``AgentTask/timeoutMs``. If the agent pipeline
    /// does not complete within the allowed time, the task is cancelled and
    /// a ``GemScanError/inferenceTimeout(taskId:limitMs:)`` is thrown.
    ///
    /// - Parameter task: The agent task to dispatch.
    /// - Returns: The final ``AgentResult``.
    /// - Throws: ``GemScanError`` on timeout, routing, or inference errors.
    public func dispatch(task: AgentTask) async throws -> AgentResult {
        let targetAgent = routingTarget(for: task.type)
        logger.info("Routing task \(task.id) (type: \(task.type.rawValue)) -> \(targetAgent)")

        let timeoutNs = UInt64(task.timeoutMs) * 1_000_000

        let result: AgentResult = try await withThrowingTaskGroup(of: AgentResult.self) { group in
            // Agent execution task
            group.addTask {
                try await self.orchestrator.dispatch(task: task)
            }

            // Timeout watchdog task
            group.addTask {
                try await Task.sleep(nanoseconds: timeoutNs)
                throw GemScanError.inferenceTimeout(taskId: task.id, limitMs: task.timeoutMs)
            }

            // Return whichever finishes first
            guard let first = try await group.next() else {
                throw GemScanError.inferenceTimeout(taskId: task.id, limitMs: task.timeoutMs)
            }
            group.cancelAll()
            return first
        }

        logger.info("Task \(task.id) completed: verdict=\(result.verdict.rawValue), latency=\(result.latencyMs)ms")

        return result
    }

    // MARK: - Private Helpers

    /// Returns the human-readable routing target name for logging.
    ///
    /// - Parameter taskType: The type of task being routed.
    /// - Returns: A descriptive string of the target agent.
    private func routingTarget(for taskType: AgentTaskType) -> String {
        switch taskType {
        case .classifySMS, .classifyEmail:
            return AgentID.textAgent
        case .checkURL:
            return AgentID.urlAgent
        case .analyseScreenshot:
            return AgentID.imageAgent
        case .explainVerdict:
            return AgentID.orchestrator
        }
    }
}
