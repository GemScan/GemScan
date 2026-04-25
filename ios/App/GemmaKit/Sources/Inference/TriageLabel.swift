import Foundation

/// Classification label assigned during the triage pass.
public enum TriageLabel: String, Codable, Sendable {
    case safe
    case junk
    case transaction
    case promotion
    case unknown
}

/// The result of a triage classification for a single message.
public struct TriageResult: Codable, Sendable {
    /// SHA-256 hash of the sender address (PII-safe).
    public let senderHash: String
    /// The triage classification label.
    public let label: TriageLabel
    /// Confidence score in the range [0, 1].
    public let confidence: Double
    /// Timestamp of classification in milliseconds since epoch.
    public let timestampMs: Int64

    private enum CodingKeys: String, CodingKey {
        case senderHash
        case label
        case confidence
        case timestampMs
    }

    public init(
        senderHash: String,
        label: TriageLabel,
        confidence: Double,
        timestampMs: Int64 = Int64(Date().timeIntervalSince1970 * 1000)
    ) {
        self.senderHash = senderHash
        self.label = label
        self.confidence = confidence
        self.timestampMs = timestampMs
    }
}
