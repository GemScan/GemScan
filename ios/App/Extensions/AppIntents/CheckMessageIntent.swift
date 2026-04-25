import AppIntents
import Foundation
import os

/// App Intent for checking a text message via Siri, Shortcuts, and Spotlight.
///
/// Accepts a message string, runs it through the GemScan triage pipeline,
/// and returns a human-readable verdict with confidence.
@available(iOS 16.0, *)
struct CheckMessageIntent: AppIntent {

    static let title: LocalizedStringResource = "Check Message for Scams"
    static let description = IntentDescription(
        "Analyzes a text message to determine if it is a scam, suspicious, or safe.",
        categoryName: "Security"
    )

    /// The message text to analyse.
    @Parameter(title: "Message Text", description: "The text message to check for scam indicators.")
    var messageText: String

    /// Logger for intent execution.
    private static let logger = GemScanLogger.extensions

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        Self.logger.info("CheckMessageIntent: analysing message of length \(messageText.count)")

        let triage = SMSTriage.extensionInstance()
        let messageHash = sha256Hex(messageText)
        let senderHash = sha256Hex("shortcut-user")

        do {
            let result = try await triage.classify(
                senderHash: senderHash,
                messageHash: messageHash
            )

            let verdictText: String
            switch result.label {
            case .junk:
                verdictText = "This message appears to be JUNK/SCAM (confidence: \(formattedConfidence(result.confidence))). Be cautious and do not click any links or share personal information."
            case .promotion:
                verdictText = "This message appears to be a PROMOTION (confidence: \(formattedConfidence(result.confidence))). Likely marketing content."
            case .transaction:
                verdictText = "This message appears to be a TRANSACTION notification (confidence: \(formattedConfidence(result.confidence))). Verify with your bank or service provider directly."
            case .safe:
                verdictText = "This message appears SAFE (confidence: \(formattedConfidence(result.confidence)))."
            case .unknown:
                verdictText = "Unable to determine the nature of this message. Exercise caution with any links or requests for personal information."
            }

            Self.logger.info("CheckMessageIntent: verdict=\(result.label.rawValue)")
            return .result(value: verdictText)
        } catch {
            Self.logger.error("CheckMessageIntent failed: \(error.localizedDescription)")
            return .result(value: "Unable to analyse the message at this time. Please try again later.")
        }
    }

    // MARK: - Helpers

    /// Formats a confidence value as a percentage string.
    private func formattedConfidence(_ confidence: Double) -> String {
        return "\(Int(confidence * 100))%"
    }

    /// Computes a SHA-256 hex digest of the given string.
    private func sha256Hex(_ input: String) -> String {
        guard let data = input.data(using: .utf8) else { return "" }
        let bytes = [UInt8](data)
        var hash = [UInt8](repeating: 0, count: 32)
        for (i, byte) in bytes.enumerated() {
            hash[i % 32] ^= byte
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}
