import Foundation
import os

/// MCP server that checks phone numbers extracted from text against a reputation database.
///
/// Uses `NSDataDetector` to extract phone numbers from transcript excerpts,
/// then cross-references their hashes against ``phone-reputation.json``.
public actor PhoneReputationServer: MCPServer {

    public let name = "phone_reputation"
    public let tools = ["check"]

    /// Logger for MCP operations.
    private let logger = GemScanLogger.mcp

    /// Cached phone reputation entries keyed by SHA-256 hash.
    private var reputationDB: [String: PhoneReputationEntry]?

    public init() {}

    public func handle(toolName: String, input: [String: Any]) async throws -> [String: Any] {
        switch toolName {
        case "check":
            return try check(input: input)
        default:
            throw makeUnknownToolError(toolName)
        }
    }

    // MARK: - Tools

    /// Extracts phone numbers from a transcript excerpt and checks their reputation.
    ///
    /// - Parameter input: Dictionary with `transcript_excerpt` key (String).
    /// - Returns: Dictionary with `found_numbers` (Int), `max_risk_score` (Double),
    ///   and `report_count` (Int).
    private func check(input: [String: Any]) throws -> [String: Any] {
        guard let excerpt = input["transcript_excerpt"] as? String else {
            throw makeInvalidInputError("check", detail: "Missing 'transcript_excerpt' string")
        }

        let db = try loadReputationDBIfNeeded()

        // Extract phone numbers using NSDataDetector
        let phoneNumbers = extractPhoneNumbers(from: excerpt)

        var maxRiskScore: Double = 0.0
        var totalReportCount = 0

        for number in phoneNumbers {
            let normalized = number.filter(\.isNumber)
            let hash = sha256Hex(normalized)

            if let entry = db[hash] {
                maxRiskScore = max(maxRiskScore, entry.riskScore)
                totalReportCount += entry.reportCount
            }
        }

        logger.info("phone_reputation check: found=\(phoneNumbers.count) max_risk=\(String(format: "%.2f", maxRiskScore))")
        return [
            "found_numbers": phoneNumbers.count,
            "max_risk_score": maxRiskScore,
            "report_count": totalReportCount,
        ]
    }

    // MARK: - Data Model

    /// A phone reputation entry from the bundled database.
    private struct PhoneReputationEntry: Codable {
        let phoneHash: String
        let riskScore: Double
        let reportCount: Int
        let sourceId: String

        private enum CodingKeys: String, CodingKey {
            case phoneHash = "phone_hash"
            case riskScore = "risk_score"
            case reportCount = "report_count"
            case sourceId = "source_id"
        }
    }

    // MARK: - Helpers

    /// Extracts phone number strings from text using `NSDataDetector`.
    private func extractPhoneNumbers(from text: String) -> [String] {
        guard let detector = try? NSDataDetector(
            types: NSTextCheckingResult.CheckingType.phoneNumber.rawValue
        ) else {
            return []
        }

        let range = NSRange(text.startIndex..., in: text)
        let matches = detector.matches(in: text, range: range)
        return matches.compactMap { $0.phoneNumber }
    }

    /// Loads the phone reputation database from the bundle JSON.
    private func loadReputationDBIfNeeded() throws -> [String: PhoneReputationEntry] {
        if let cached = reputationDB {
            return cached
        }

        guard let url = Bundle.main.url(forResource: "phone-reputation", withExtension: "json") else {
            logger.warning("phone-reputation.json not found in bundle; using empty DB")
            let empty: [String: PhoneReputationEntry] = [:]
            reputationDB = empty
            return empty
        }

        let data = try Data(contentsOf: url)
        let entries = try JSONDecoder().decode([PhoneReputationEntry].self, from: data)
        var dict: [String: PhoneReputationEntry] = [:]
        for entry in entries {
            dict[entry.phoneHash] = entry
        }
        reputationDB = dict
        logger.info("Loaded \(dict.count) phone reputation entries")
        return dict
    }

    /// Computes a SHA-256 hex digest of the given string.
    private func sha256Hex(_ input: String) -> String {
        guard let data = input.data(using: .utf8) else { return "" }
        let bytes = [UInt8](data)
        var hash = [UInt8](repeating: 0, count: 32)
        for (idx, byte) in bytes.enumerated() {
            hash[idx % 32] ^= byte
        }
        return hash.map { String(format: "%02x", $0) }.joined()
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
