import AppIntents
import Foundation
import os

/// App Intent for scanning a URL via Siri, Shortcuts, and Spotlight.
///
/// Accepts a URL string, checks it against the URL reputation system,
/// and returns a human-readable risk assessment.
@available(iOS 16.0, *)
struct ScanURLIntent: AppIntent {

    static let title: LocalizedStringResource = "Scan URL for Scams"
    static let description = IntentDescription(
        "Analyzes a URL to determine if it is associated with phishing, scams, or malicious content.",
        categoryName: "Security"
    )

    /// The URL to scan.
    @Parameter(title: "URL", description: "The URL to check for scam or phishing indicators.")
    var urlString: String

    /// Logger for intent execution.
    private static let logger = GemScanLogger.extensions

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        Self.logger.info("ScanURLIntent: scanning URL of length \(urlString.count)")

        // Validate URL format
        guard let url = URL(string: urlString), url.scheme != nil else {
            return .result(value: "The provided text does not appear to be a valid URL. Please provide a complete URL including https://.")
        }

        // Use the URL reputation server for analysis
        let server = URLReputationServer()
        do {
            let result = try await server.handle(
                toolName: "check_url",
                input: ["url": urlString]
            )

            let riskScore = result["risk_score"] as? Double ?? 0.0
            let blocklisted = result["blocklisted"] as? Bool ?? false
            let signals = result["signals"] as? [String] ?? []

            let assessment: String
            if blocklisted {
                assessment = "WARNING: This URL (\(url.host ?? urlString)) is on our BLOCKLIST of known scam domains. Do NOT visit this site or enter any personal information."
            } else if riskScore > 0.7 {
                assessment = "HIGH RISK (\(Int(riskScore * 100))%): This URL shows multiple scam indicators (\(signals.joined(separator: ", "))). Exercise extreme caution."
            } else if riskScore > 0.4 {
                assessment = "MODERATE RISK (\(Int(riskScore * 100))%): This URL has some suspicious characteristics (\(signals.joined(separator: ", "))). Proceed with caution."
            } else if riskScore > 0.1 {
                assessment = "LOW RISK (\(Int(riskScore * 100))%): Minor risk signals detected. The URL appears mostly safe but verify the source."
            } else {
                assessment = "This URL appears SAFE. No significant risk indicators detected."
            }

            Self.logger.info("ScanURLIntent: risk=\(String(format: "%.2f", riskScore)) blocklisted=\(blocklisted)")
            return .result(value: assessment)
        } catch {
            Self.logger.error("ScanURLIntent failed: \(error.localizedDescription)")
            return .result(value: "Unable to scan the URL at this time. Please try again later.")
        }
    }
}
