import Foundation
import os

// MARK: - ScamPattern

/// A single scam detection pattern loaded from ScamPatterns.json.
struct ScamPattern: Codable, Sendable {
    /// Unique pattern identifier.
    let id: String
    /// Human-readable pattern name.
    let name: String
    /// Regular expression string for matching.
    let regex: String
    /// Risk level: "low", "medium", "high", or "critical".
    let riskLevel: String
    /// Brief description of what this pattern detects.
    let description: String

    private enum CodingKeys: String, CodingKey {
        case id, name, regex, riskLevel = "risk_level", description
    }
}

// MARK: - ScamPatternsServer

/// MCP server that matches text against a bundled library of scam patterns.
///
/// Loads ``ScamPatterns.json`` from the app bundle on first use and caches
/// compiled regular expressions for efficient repeated matching.
public actor ScamPatternsServer: MCPServer {

    public let name = "scam_patterns"
    public let tools = ["match_patterns", "get_pattern_detail"]

    /// Logger for MCP operations.
    private let logger = GemScanLogger.mcp

    /// Cached patterns loaded from the bundle.
    private var patterns: [ScamPattern]?

    /// Compiled regex cache keyed by pattern id.
    private var compiledRegexes: [String: NSRegularExpression] = [:]

    public init() {}

    public func handle(toolName: String, input: [String: Any]) async throws -> [String: Any] {
        switch toolName {
        case "match_patterns":
            return try matchPatterns(input: input)
        case "get_pattern_detail":
            return try getPatternDetail(input: input)
        default:
            throw makeUnknownToolError(toolName)
        }
    }

    // MARK: - Tools

    /// Matches a text hash against all loaded scam patterns.
    ///
    /// - Parameter input: Dictionary with `text_hash` key (String).
    /// - Returns: Dictionary with `patternIds` array of matching pattern identifiers.
    private func matchPatterns(input: [String: Any]) throws -> [String: Any] {
        guard let textHash = input["text_hash"] as? String else {
            throw makeInvalidInputError("match_patterns", detail: "Missing 'text_hash' string")
        }

        let allPatterns = try loadPatternsIfNeeded()
        var matchedIds: [String] = []

        for pattern in allPatterns {
            let regex = try compiledRegex(for: pattern)
            let range = NSRange(textHash.startIndex..., in: textHash)
            if regex.firstMatch(in: textHash, range: range) != nil {
                matchedIds.append(pattern.id)
            }
        }

        logger.info("match_patterns: \(matchedIds.count) pattern(s) matched")
        return ["patternIds": matchedIds]
    }

    /// Returns the full detail of a scam pattern by identifier.
    ///
    /// - Parameter input: Dictionary with `id` key (String).
    /// - Returns: Dictionary with pattern fields or empty if not found.
    private func getPatternDetail(input: [String: Any]) throws -> [String: Any] {
        guard let patternId = input["id"] as? String else {
            throw makeInvalidInputError("get_pattern_detail", detail: "Missing 'id' string")
        }

        let allPatterns = try loadPatternsIfNeeded()

        guard let pattern = allPatterns.first(where: { $0.id == patternId }) else {
            logger.warning("get_pattern_detail: pattern '\(patternId)' not found")
            return [:]
        }

        return [
            "id": pattern.id,
            "name": pattern.name,
            "regex": pattern.regex,
            "risk_level": pattern.riskLevel,
            "description": pattern.description,
        ]
    }

    // MARK: - Helpers

    /// Loads patterns from the bundle JSON on first access.
    private func loadPatternsIfNeeded() throws -> [ScamPattern] {
        if let cached = patterns {
            return cached
        }

        guard let url = Bundle.main.url(forResource: "ScamPatterns", withExtension: "json") else {
            logger.error("ScamPatterns.json not found in bundle")
            throw makeLoadError("ScamPatterns.json not found in bundle")
        }

        let data = try Data(contentsOf: url)
        let decoded = try JSONDecoder().decode([ScamPattern].self, from: data)
        patterns = decoded
        logger.info("Loaded \(decoded.count) scam patterns from bundle")
        return decoded
    }

    /// Returns a compiled regex for the given pattern, caching the result.
    private func compiledRegex(for pattern: ScamPattern) throws -> NSRegularExpression {
        if let cached = compiledRegexes[pattern.id] {
            return cached
        }
        let regex = try NSRegularExpression(pattern: pattern.regex, options: [.caseInsensitive])
        compiledRegexes[pattern.id] = regex
        return regex
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

    private func makeLoadError(_ detail: String) -> GemScanError {
        let err = NSError(domain: "com.gemscan.mcp", code: 500,
                          userInfo: [NSLocalizedDescriptionKey: detail])
        return .mcpToolFailed(server: name, tool: "match_patterns", underlying: err)
    }
}
