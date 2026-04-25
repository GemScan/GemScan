import Foundation
import os

/// MCP server that scores URL risk based on structural signals and a bundled blocklist.
///
/// Analyses TLD risk, path entropy, IP address usage, subdomain depth,
/// and blocklist membership to produce a composite risk score.
public actor URLReputationServer: MCPServer {

    public let name = "url_reputation"
    public let tools = ["check_url"]

    /// Logger for MCP operations.
    private let logger = GemScanLogger.mcp

    /// Loaded blocklist domains (lowercased).
    private var blocklist: Set<String>?

    /// TLD risk multipliers (higher = riskier).
    private let tldRiskScores: [String: Double] = [
        "xyz": 0.7, "top": 0.7, "click": 0.8, "buzz": 0.7,
        "tk": 0.9, "ml": 0.8, "ga": 0.8, "cf": 0.8, "gq": 0.8,
        "info": 0.5, "biz": 0.5, "work": 0.6, "live": 0.6,
        "support": 0.6, "loan": 0.7, "win": 0.7,
    ]

    public init() {}

    public func handle(toolName: String, input: [String: Any]) async throws -> [String: Any] {
        switch toolName {
        case "check_url":
            return try checkURL(input: input)
        default:
            throw makeUnknownToolError(toolName)
        }
    }

    // MARK: - Tools

    /// Checks a URL against structural heuristics and the blocklist.
    ///
    /// - Parameter input: Dictionary with `url` key (String).
    /// - Returns: Dictionary with `risk_score` (Double 0-1), `blocklisted` (Bool),
    ///   and `signals` (array of detected risk signal strings).
    private func checkURL(input: [String: Any]) throws -> [String: Any] {
        guard let urlString = input["url"] as? String else {
            throw makeInvalidInputError("check_url", detail: "Missing 'url' string")
        }

        let loadedBlocklist = try loadBlocklistIfNeeded()

        var signals: [String] = []
        var riskScore: Double = 0.0

        // Parse URL components
        guard let components = URLComponents(string: urlString),
              let host = components.host?.lowercased() else {
            signals.append("invalid_url_format")
            return ["risk_score": 0.9, "blocklisted": false, "signals": signals]
        }

        // Blocklist check
        let blocklisted = loadedBlocklist.contains(host)
        if blocklisted {
            signals.append("blocklisted_domain")
            riskScore += 0.5
        }

        // TLD risk scoring
        let tld = host.components(separatedBy: ".").last ?? ""
        if let tldScore = tldRiskScores[tld] {
            signals.append("risky_tld_\(tld)")
            riskScore += tldScore * 0.3
        }

        // IP address detection
        let ipPattern = #"^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$"#
        if host.range(of: ipPattern, options: .regularExpression) != nil {
            signals.append("ip_address_host")
            riskScore += 0.3
        }

        // Subdomain depth
        let subdomainCount = host.components(separatedBy: ".").count - 2
        if subdomainCount > 2 {
            signals.append("deep_subdomains_\(subdomainCount)")
            riskScore += Double(subdomainCount) * 0.05
        }

        // Path entropy (long random-looking paths are suspicious)
        if let path = components.path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
           path.count > 60 {
            let entropy = computePathEntropy(path)
            if entropy > 3.5 {
                signals.append("high_path_entropy")
                riskScore += 0.15
            }
        }

        // Clamp to [0, 1]
        riskScore = min(1.0, max(0.0, riskScore))

        logger.info("check_url: host=\(host) risk=\(String(format: "%.2f", riskScore)) signals=\(signals.count)")
        return [
            "risk_score": riskScore,
            "blocklisted": blocklisted,
            "signals": signals,
        ]
    }

    // MARK: - Helpers

    /// Loads the blocklist from the bundle JSON on first access.
    private func loadBlocklistIfNeeded() throws -> Set<String> {
        if let cached = blocklist {
            return cached
        }

        guard let url = Bundle.main.url(forResource: "blocklist", withExtension: "json") else {
            logger.warning("blocklist.json not found in bundle; using empty blocklist")
            let empty = Set<String>()
            blocklist = empty
            return empty
        }

        let data = try Data(contentsOf: url)
        let domains = try JSONDecoder().decode([String].self, from: data)
        let set = Set(domains.map { $0.lowercased() })
        blocklist = set
        logger.info("Loaded \(set.count) blocklist domains")
        return set
    }

    /// Computes a simple Shannon entropy estimate for a URL path.
    private func computePathEntropy(_ path: String) -> Double {
        var freq: [Character: Int] = [:]
        for char in path {
            freq[char, default: 0] += 1
        }
        let total = Double(path.count)
        var entropy = 0.0
        for (_, count) in freq {
            let prob = Double(count) / total
            if prob > 0 {
                entropy -= prob * log2(prob)
            }
        }
        return entropy
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
