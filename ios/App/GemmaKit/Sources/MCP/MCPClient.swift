import Foundation
import os

// MARK: - MCPServer Protocol

/// A Model Context Protocol server that exposes a set of tools.
///
/// Each server is an actor to ensure thread-safe state management.
/// Servers register their tool names at startup and respond to
/// ``handle(toolName:input:)`` invocations routed by ``MCPClient``.
public protocol MCPServer: Actor {
    /// Human-readable server name used for logging and access control.
    var name: String { get }

    /// The set of tool names this server exposes.
    var tools: [String] { get }

    /// Handles a tool invocation and returns the result dictionary.
    ///
    /// - Parameters:
    ///   - toolName: The name of the tool being invoked.
    ///   - input: The input parameters for the tool call.
    /// - Returns: A dictionary containing the tool's output.
    /// - Throws: ``GemScanError/mcpToolFailed(server:tool:underlying:)`` on failure.
    func handle(toolName: String, input: [String: Any]) async throws -> [String: Any]
}

// MARK: - MCPClient

/// Routes MCP tool calls to registered servers, enforcing per-agent access control.
///
/// The access control matrix defines which agents may invoke which servers.
/// Any call from an agent to a server not in its allowlist is rejected
/// with ``GemScanError/mcpToolFailed(server:tool:underlying:)``.
public actor MCPClient {

    /// Logger for MCP operations.
    private let logger = GemScanLogger.mcp

    /// Registered servers keyed by their name.
    private var servers: [String: any MCPServer] = [:]

    /// Agent-to-server access control allowlist.
    ///
    /// Keys are agent identifiers (see ``AgentID``), values are sets of
    /// server names the agent is permitted to call.
    private let accessControl: [String: Set<String>] = [
        AgentID.textAgent: [
            "scam_patterns", "sqlite_vec", "contacts",
            "url_reputation", "message_filter"
        ],
        AgentID.urlAgent: [
            "sqlite_vec", "url_reputation", "whois"
        ],
        AgentID.imageAgent: [
            "sqlite_vec", "reverse_image", "url_reputation"
        ],
        AgentID.orchestrator: [
            "scam_patterns", "sqlite_vec", "contacts",
            "url_reputation", "message_filter",
            "whois", "reverse_image", "clipboard_watcher", "screen_time"
        ],
    ]

    /// Creates a new MCP client with no servers registered.
    public init() {}

    /// Registers an MCP server for tool routing.
    ///
    /// - Parameter server: The server to register.
    public func register(server: any MCPServer) async {
        let serverName = await server.name
        servers[serverName] = server
        let toolCount = await server.tools.count
        logger.info("Registered MCP server '\(serverName)' with \(toolCount) tool(s)")
    }

    /// Invokes a tool on the specified server, subject to access control.
    ///
    /// - Parameters:
    ///   - agentId: The agent making the call (must appear in the access control matrix).
    ///   - server: The server name to route to.
    ///   - tool: The tool name to invoke.
    ///   - input: The input parameters for the tool call.
    /// - Returns: The tool's result dictionary.
    /// - Throws: ``GemScanError/mcpToolFailed(server:tool:underlying:)`` if access is
    ///   denied, the server is not registered, or the tool call fails.
    public func call(
        agentId: String,
        server: String,
        tool: String,
        input: [String: Any]
    ) async throws -> [String: Any] {
        // Enforce access control
        guard let allowed = accessControl[agentId], allowed.contains(server) else {
            let reason = NSError(
                domain: "com.gemscan.mcp",
                code: 403,
                userInfo: [NSLocalizedDescriptionKey: "Agent '\(agentId)' is not allowed to call server '\(server)'"]
            )
            logger.warning("Access denied: agent '\(agentId)' -> server '\(server)', tool '\(tool)'")
            throw GemScanError.mcpToolFailed(server: server, tool: tool, underlying: reason)
        }

        // Look up server
        guard let targetServer = servers[server] else {
            let reason = NSError(
                domain: "com.gemscan.mcp",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Server '\(server)' is not registered"]
            )
            logger.error("Server '\(server)' not found for tool '\(tool)'")
            throw GemScanError.mcpToolFailed(server: server, tool: tool, underlying: reason)
        }

        logger.info("Routing call: agent=\(agentId) server=\(server) tool=\(tool)")

        do {
            let result = try await targetServer.handle(toolName: tool, input: input)
            logger.info("Tool '\(tool)' on server '\(server)' completed successfully")
            return result
        } catch {
            logger.error("Tool '\(tool)' on server '\(server)' failed: \(error.localizedDescription)")
            throw GemScanError.mcpToolFailed(server: server, tool: tool, underlying: error)
        }
    }
}
