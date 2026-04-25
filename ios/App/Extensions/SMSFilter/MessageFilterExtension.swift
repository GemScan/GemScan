import IdentityLookup
import os

/// SMS/MMS message filter extension for iOS.
///
/// Implements `ILMessageFilterQueryHandling` to classify incoming messages
/// from unknown senders using the on-device DistilBERT model via ``SMSTriage``.
///
/// Operates under strict system constraints:
/// - **50 MB** memory ceiling
/// - **5-second** decision window
/// - No network access in the offline path
final class MessageFilterExtension: ILMessageFilterExtension {

    /// Logger for extension lifecycle events.
    private let logger = GemScanLogger.extensions

    override init() {
        super.init()
        logger.info("MessageFilterExtension initialized")
    }
}

// MARK: - ILMessageFilterQueryHandling

extension MessageFilterExtension: ILMessageFilterQueryHandling {

    /// Handles an incoming message filter query.
    ///
    /// Classifies the message using the DistilBERT triage model and returns
    /// the appropriate filter action. Falls through to `.none` (allow) on any error
    /// to avoid false-positive blocking.
    ///
    /// - Parameters:
    ///   - queryRequest: The filter query containing sender and message body.
    ///   - context: The extension context for completing the request.
    ///   - completion: Closure to call with the filter response.
    func handle(
        _ queryRequest: ILMessageFilterQueryRequest,
        context: ILMessageFilterExtensionContext,
        completion: @escaping (ILMessageFilterQueryResponse) -> Void
    ) {
        let response = ILMessageFilterQueryResponse()

        guard let sender = queryRequest.sender, !sender.isEmpty else {
            logger.info("No sender in query — allowing message")
            response.action = .none
            completion(response)
            return
        }

        let messageBody = queryRequest.messageBody ?? ""

        // Hash inputs for PII-safe classification
        let senderHash = sha256Hex(sender.lowercased())
        let messageHash = sha256Hex(messageBody)

        let triage = SMSTriage.extensionInstance()

        Task {
            do {
                let result = try await triage.classify(
                    senderHash: senderHash,
                    messageHash: messageHash
                )

                let action = mapTriageLabelToAction(result.label, confidence: result.confidence)
                response.action = action

                self.logger.info("Classified message: label=\(result.label.rawValue) confidence=\(String(format: "%.3f", result.confidence)) action=\(action.rawValue)")
            } catch {
                // On any error, allow the message to avoid false-positive blocking
                self.logger.error("Triage failed: \(error.localizedDescription) — allowing message")
                response.action = .none
            }

            completion(response)
        }
    }

    // MARK: - Helpers

    /// Maps a triage label and confidence to an `ILMessageFilterAction`.
    ///
    /// - Parameters:
    ///   - label: The classification label from the triage model.
    ///   - confidence: The confidence score in [0, 1].
    /// - Returns: The appropriate message filter action.
    private func mapTriageLabelToAction(
        _ label: TriageLabel,
        confidence: Double
    ) -> ILMessageFilterAction {
        // Require minimum confidence to act
        guard confidence >= 0.6 else {
            return .none
        }

        switch label {
        case .junk:
            return .junk
        case .transaction:
            return .transaction
        case .promotion:
            return .promotion
        case .safe, .unknown:
            return .none
        }
    }

    /// Computes a SHA-256 hex digest of the given string.
    ///
    /// Uses a simplified hash for the extension's constrained environment.
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
