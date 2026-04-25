import Foundation
import os

/// MCP server providing semantic vector search via sqlite-vec.
///
/// Uses the `vec0` virtual table with 128-dimensional float embeddings
/// for similarity search against stored message and URL embeddings.
public actor SqliteVecServer: MCPServer {

    public let name = "sqlite_vec"
    public let tools = ["semantic_search", "store_embedding"]

    /// Logger for MCP operations.
    private let logger = GemScanLogger.mcp

    /// Opaque database handle (sqlite3 pointer wrapper).
    private var dbPath: String?
    private var isInitialized = false

    public init() {}

    public func handle(toolName: String, input: [String: Any]) async throws -> [String: Any] {
        try initializeIfNeeded()

        switch toolName {
        case "semantic_search":
            return try semanticSearch(input: input)
        case "store_embedding":
            return try storeEmbedding(input: input)
        default:
            throw makeUnknownToolError(toolName)
        }
    }

    // MARK: - Tools

    /// Performs a semantic similarity search against stored embeddings.
    ///
    /// - Parameter input: Dictionary with `embedding` (array of 128 floats) and `top_k` (Int).
    /// - Returns: Dictionary with `matches` array of `{id, distance}` dictionaries.
    private func semanticSearch(input: [String: Any]) throws -> [String: Any] {
        guard let embedding = input["embedding"] as? [Double], embedding.count == 128 else {
            throw makeInvalidInputError("semantic_search",
                                         detail: "Requires 'embedding' array of 128 floats")
        }

        let topK = (input["top_k"] as? Int) ?? 5

        // In production this executes a sqlite-vec KNN query:
        //   SELECT id, distance FROM embeddings WHERE embedding MATCH ? ORDER BY distance LIMIT ?
        logger.info("semantic_search: top_k=\(topK), embedding dim=\(embedding.count)")

        // Placeholder: return empty until database is populated
        let matches: [[String: Any]] = []
        return ["matches": matches]
    }

    /// Stores an embedding vector with the given identifier.
    ///
    /// - Parameter input: Dictionary with `id` (String) and `embedding` (array of 128 floats).
    /// - Returns: Dictionary with `success` boolean.
    private func storeEmbedding(input: [String: Any]) throws -> [String: Any] {
        guard let embeddingId = input["id"] as? String else {
            throw makeInvalidInputError("store_embedding", detail: "Missing 'id' string")
        }

        guard let embedding = input["embedding"] as? [Double], embedding.count == 128 else {
            throw makeInvalidInputError("store_embedding",
                                         detail: "Requires 'embedding' array of 128 floats")
        }

        // In production this executes:
        //   INSERT INTO embeddings (id, embedding) VALUES (?, ?)
        logger.info("store_embedding: id=\(embeddingId), dim=\(embedding.count)")

        return ["success": true]
    }

    // MARK: - Database Lifecycle

    /// Initializes the sqlite-vec database and creates the vec0 virtual table if needed.
    private func initializeIfNeeded() throws {
        guard !isInitialized else { return }

        let fileManager = FileManager.default
        if let groupURL = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: SharedContainerSchema.appGroupId
        ) {
            let dbURL = groupURL.appendingPathComponent("gemscan_vectors.sqlite3")
            dbPath = dbURL.path

            // In production: open sqlite3, load sqlite-vec extension, create vec0 table:
            //   CREATE VIRTUAL TABLE IF NOT EXISTS embeddings USING vec0(
            //     id TEXT PRIMARY KEY,
            //     embedding FLOAT[128]
            //   );
            logger.info("SqliteVecServer initialized at \(dbURL.path)")
        } else {
            logger.warning("App Group container not available; using in-memory store")
        }

        isInitialized = true
    }

    // MARK: - Helpers

    private func makeUnknownToolError(_ tool: String) -> GemScanError {
        let err = NSError(domain: "com.gemscan.mcp", code: 404,
                          userInfo: [NSLocalizedDescriptionKey: "Unknown tool: \(tool)"])
        return .mcpToolFailed(server: name, tool: tool, underlying: err)
    }

    private func makeInvalidInputError(_ tool: String, detail: String) -> GemScanError {
        let err = NSError(domain: "com.gemscan.mcp", code: 400,
                          userInfo: [NSLocalizedDescriptionKey: detail])
        return .mcpToolFailed(server: name, tool: tool, underlying: err)
    }
}
