import Foundation
import CallKit
import os

// MARK: - GemmaPlugin CallKit Integration

/// Extension providing CallKit pre-answer screening for incoming calls.
///
/// Uses the phone reputation MCP server to check incoming call numbers
/// against the reputation database before the user answers.
extension GemmaPlugin {

    /// Configures CallKit call identification and blocking.
    ///
    /// Registers a `CXCallDirectoryProvider` reload request so the system
    /// picks up the latest blocked/identified numbers from the extension.
    static func configureCallKit() {
        let logger = GemScanLogger.plugin

        CXCallDirectoryManager.sharedInstance.getEnabledStatusForExtension(
            withIdentifier: "com.gemscan.CallDirectoryExtension"
        ) { status, error in
            if let error = error {
                logger.error("CallKit directory status check failed: \(error.localizedDescription)")
                return
            }

            switch status {
            case .enabled:
                logger.info("CallKit directory extension is enabled")
                reloadCallDirectory()
            case .disabled:
                logger.warning("CallKit directory extension is disabled — user must enable in Settings")
            case .unknown:
                logger.info("CallKit directory extension status is unknown")
            @unknown default:
                logger.warning("CallKit directory extension returned unexpected status")
            }
        }
    }

    /// Requests the system to reload the call directory extension data.
    private static func reloadCallDirectory() {
        let logger = GemScanLogger.plugin

        CXCallDirectoryManager.sharedInstance.reloadExtension(
            withIdentifier: "com.gemscan.CallDirectoryExtension"
        ) { error in
            if let error = error {
                logger.error("CallKit directory reload failed: \(error.localizedDescription)")
            } else {
                logger.info("CallKit directory reloaded successfully")
            }
        }
    }

    /// Performs a pre-answer reputation check for an incoming phone number.
    ///
    /// - Parameters:
    ///   - phoneNumber: The E.164-formatted phone number string.
    ///   - client: The MCP client to use for the reputation lookup.
    /// - Returns: A risk score in [0, 1] or nil if the check could not be performed.
    static func preAnswerScreening(
        phoneNumber: String,
        client: MCPClient
    ) async -> Double? {
        let logger = GemScanLogger.plugin

        do {
            let result = try await client.call(
                agentId: AgentID.orchestrator,
                server: "phone_reputation",
                tool: "check",
                input: ["transcript_excerpt": phoneNumber]
            )

            if let riskScore = result["max_risk_score"] as? Double {
                logger.info("Pre-answer screening: risk=\(String(format: "%.2f", riskScore))")
                return riskScore
            }
        } catch {
            logger.error("Pre-answer screening failed: \(error.localizedDescription)")
        }

        return nil
    }
}
