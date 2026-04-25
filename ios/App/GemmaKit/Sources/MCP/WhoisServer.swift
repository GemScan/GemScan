import Foundation
import os

/// MCP server that provides cached WHOIS domain registration data.
///
/// Loads ``whois-cache.json`` from the app bundle, containing pre-fetched
/// WHOIS records for commonly encountered domains. Returns registration age,
/// registrar, country, and privacy protection status.
public actor WhoisServer: MCPServer {

    public let name = "whois"
    public let tools = ["lookup"]

    /// Logger for MCP operations.
    private let logger = GemScanLogger.mcp

    /// Cached WHOIS records keyed by domain.
    private var cache: [String: WhoisRecord]?

    public init() {}

    public func handle(toolName: String, input: [String: Any]) async throws -> [String: Any] {
        switch toolName {
        case "lookup":
            return try lookup(input: input)
        default:
            throw makeUnknownToolError(toolName)
        }
    }

    // MARK: - Tools

    /// Looks up WHOIS information for a domain.
    ///
    /// - Parameter input: Dictionary with `domain` key (String).
    /// - Returns: Dictionary with `age_days` (Int), `registrar` (String),
    ///   `country` (String), and `privacy_protected` (Bool).
    private func lookup(input: [String: Any]) throws -> [String: Any] {
        guard let domain = input["domain"] as? String else {
            throw makeInvalidInputError("lookup", detail: "Missing 'domain' string")
        }

        let records = try loadCacheIfNeeded()
        let normalizedDomain = domain.lowercased()

        guard let record = records[normalizedDomain] else {
            logger.info("lookup: domain '\(normalizedDomain)' not in WHOIS cache")
            return [
                "age_days": -1,
                "registrar": "unknown",
                "country": "unknown",
                "privacy_protected": false,
            ]
        }

        let ageDays: Int
        if let createdDate = record.createdDate {
            ageDays = Int(Date().timeIntervalSince(createdDate) / 86400)
        } else {
            ageDays = -1
        }

        logger.info("lookup: domain=\(normalizedDomain) age=\(ageDays)d registrar=\(record.registrar)")
        return [
            "age_days": ageDays,
            "registrar": record.registrar,
            "country": record.country,
            "privacy_protected": record.privacyProtected,
        ]
    }

    // MARK: - Data Model

    /// Internal representation of a cached WHOIS record.
    private struct WhoisRecord: Codable {
        let domain: String
        let registrar: String
        let country: String
        let privacyProtected: Bool
        let createdDateString: String?

        var createdDate: Date? {
            guard let str = createdDateString else { return nil }
            let formatter = ISO8601DateFormatter()
            return formatter.date(from: str)
        }

        private enum CodingKeys: String, CodingKey {
            case domain, registrar, country
            case privacyProtected = "privacy_protected"
            case createdDateString = "created_date"
        }
    }

    // MARK: - Helpers

    /// Loads the WHOIS cache from the bundle JSON on first access.
    private func loadCacheIfNeeded() throws -> [String: WhoisRecord] {
        if let cached = cache {
            return cached
        }

        guard let url = Bundle.main.url(forResource: "whois-cache", withExtension: "json") else {
            logger.warning("whois-cache.json not found in bundle; using empty cache")
            let empty: [String: WhoisRecord] = [:]
            cache = empty
            return empty
        }

        let data = try Data(contentsOf: url)
        let records = try JSONDecoder().decode([WhoisRecord].self, from: data)
        var dict: [String: WhoisRecord] = [:]
        for record in records {
            dict[record.domain.lowercased()] = record
        }
        cache = dict
        logger.info("Loaded \(dict.count) WHOIS cache entries")
        return dict
    }

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
