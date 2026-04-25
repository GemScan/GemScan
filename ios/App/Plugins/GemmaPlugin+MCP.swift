import Foundation
import os

// MARK: - GemmaPlugin MCP Registration

/// Extension that registers all MCP servers at plugin startup.
///
/// Called during `GemmaPlugin.load()` to initialize the MCP infrastructure
/// and register each server with the shared ``MCPClient`` instance.
extension GemmaPlugin {

    /// Registers all 10 MCP servers with the given client.
    ///
    /// Servers are registered in dependency order: data-only servers first,
    /// then servers that may depend on shared container state.
    ///
    /// - Parameter client: The ``MCPClient`` to register servers with.
    static func registerMCPServers(with client: MCPClient) async {
        let logger = GemScanLogger.plugin

        logger.info("Registering MCP servers…")

        // Data-only servers (no external dependencies)
        await client.register(server: ScamPatternsServer())
        await client.register(server: SqliteVecServer())
        await client.register(server: URLReputationServer())
        await client.register(server: WhoisServer())
        await client.register(server: PhoneReputationServer())
        await client.register(server: ReverseImageServer())

        // Servers with system framework dependencies
        await client.register(server: ContactsServer())
        await client.register(server: ClipboardWatcherServer())
        await client.register(server: ScreenTimeServer())

        // Servers depending on App Group shared container
        await client.register(server: MessageFilterServer())

        logger.info("All 10 MCP servers registered successfully")
    }
}
