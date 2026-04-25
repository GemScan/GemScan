import Foundation
@testable import GemmaKit

/// A mock MCP client that returns pre-configured tool results for testing.
///
/// Configure ``toolResults`` with server/tool keys to control what each
/// tool call returns. Tracks all calls for assertion in tests.
actor MockMCPClient {

    // MARK: - Configuration

    /// Pre-configured results keyed by "server/tool".
    /// When a call is made, the mock looks up the key and returns the corresponding value.
    var toolResults: [String: [String: Any]] = [:]

    /// If set, all calls will throw this error.
    var nextError: Error?

    /// Access control matrix (mirrors MCPClient). Set to nil to skip access checks.
    var accessControl: [String: Set<String>]? = nil

    // MARK: - Call Tracking

    /// Records of all calls made to this mock.
    struct CallRecord: Sendable {
        let agentId: String
        let server: String
        let tool: String
        let input: [String: Any]

        /// Composite key for looking up results.
        var key: String { "\(server)/\(tool)" }
    }

    private(set) var calls: [CallRecord] = []

    // MARK: - Public API

    /// Simulates an MCP tool call.
    ///
    /// - Parameters:
    ///   - agentId: The calling agent's identifier.
    ///   - server: The target server name.
    ///   - tool: The tool name to invoke.
    ///   - input: Input parameters for the tool.
    /// - Returns: The pre-configured result for this server/tool pair.
    /// - Throws: The configured ``nextError``, or an access denied error
    ///   if the agent is not in the access control allowlist.
    func call(
        agentId: String,
        server: String,
        tool: String,
        input: [String: Any]
    ) async throws -> [String: Any] {
        let record = CallRecord(agentId: agentId, server: server, tool: tool, input: input)
        calls.append(record)

        // Check access control if configured
        if let acl = accessControl {
            guard let allowed = acl[agentId], allowed.contains(server) else {
                let reason = NSError(
                    domain: "com.gemscan.mcp.mock",
                    code: 403,
                    userInfo: [NSLocalizedDescriptionKey: "Mock: Access denied for agent '\(agentId)' to server '\(server)'"]
                )
                throw GemScanError.mcpToolFailed(server: server, tool: tool, underlying: reason)
            }
        }

        if let error = nextError {
            throw error
        }

        let key = "\(server)/\(tool)"
        guard let result = toolResults[key] else {
            return ["status": "ok", "mock": true]
        }

        return result
    }

    // MARK: - Test Helpers

    /// Resets all configuration and call history.
    func reset() {
        toolResults = [:]
        nextError = nil
        accessControl = nil
        calls = []
    }

    /// Sets a result for a specific server/tool combination.
    func setResult(server: String, tool: String, result: [String: Any]) {
        toolResults["\(server)/\(tool)"] = result
    }

    /// Returns the number of calls made to a specific server/tool.
    func callCount(server: String, tool: String) -> Int {
        let key = "\(server)/\(tool)"
        return calls.filter { $0.key == key }.count
    }

    /// Returns all calls made by a specific agent.
    func calls(byAgent agentId: String) -> [CallRecord] {
        calls.filter { $0.agentId == agentId }
    }
}
