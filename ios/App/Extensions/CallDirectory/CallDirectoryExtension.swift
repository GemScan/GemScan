import CallKit
import os

/// Call Directory extension for blocking and identifying scam phone numbers.
///
/// Provides the system with a pre-built list of known scam phone numbers
/// (as `Int64` E.164 values) for call blocking and caller identification.
/// Data is read from the shared App Group container.
final class CallDirectoryExtension: CXCallDirectoryProvider {

    /// Logger for extension lifecycle events.
    private let logger = GemScanLogger.extensions

    override func beginRequest(with context: CXCallDirectoryExtensionContext) {
        context.delegate = self

        // Check if this is an incremental load
        if context.isIncremental {
            logger.info("CallDirectory: performing incremental load")
            addOrRemoveIncrementalBlockingPhoneNumbers(to: context)
            addOrRemoveIncrementalIdentificationPhoneNumbers(to: context)
        } else {
            logger.info("CallDirectory: performing full load")
            addAllBlockingPhoneNumbers(to: context)
            addAllIdentificationPhoneNumbers(to: context)
        }

        context.completeRequest()
    }

    // MARK: - Blocking

    /// Adds all known scam phone numbers for blocking.
    ///
    /// Numbers must be added in strictly ascending order (E.164 Int64 format).
    private func addAllBlockingPhoneNumbers(to context: CXCallDirectoryExtensionContext) {
        let numbers = loadBlockedNumbers()

        for number in numbers.sorted() {
            context.addBlockingEntry(withNextSequentialPhoneNumber: number)
        }

        logger.info("CallDirectory: added \(numbers.count) blocking entries")
    }

    /// Adds or removes incremental blocking entries since the last load.
    private func addOrRemoveIncrementalBlockingPhoneNumbers(to context: CXCallDirectoryExtensionContext) {
        let numbers = loadIncrementalBlockedNumbers()

        for number in numbers.sorted() {
            context.addBlockingEntry(withNextSequentialPhoneNumber: number)
        }

        logger.info("CallDirectory: incremental blocking update — \(numbers.count) entries")
    }

    // MARK: - Identification

    /// Adds all known scam phone numbers with identification labels.
    ///
    /// Numbers must be added in strictly ascending order (E.164 Int64 format).
    private func addAllIdentificationPhoneNumbers(to context: CXCallDirectoryExtensionContext) {
        let entries = loadIdentificationEntries()

        for entry in entries.sorted(by: { $0.phoneNumber < $1.phoneNumber }) {
            context.addIdentificationEntry(
                withNextSequentialPhoneNumber: entry.phoneNumber,
                label: entry.label
            )
        }

        logger.info("CallDirectory: added \(entries.count) identification entries")
    }

    /// Adds or removes incremental identification entries since the last load.
    private func addOrRemoveIncrementalIdentificationPhoneNumbers(to context: CXCallDirectoryExtensionContext) {
        let entries = loadIncrementalIdentificationEntries()

        for entry in entries.sorted(by: { $0.phoneNumber < $1.phoneNumber }) {
            context.addIdentificationEntry(
                withNextSequentialPhoneNumber: entry.phoneNumber,
                label: entry.label
            )
        }

        logger.info("CallDirectory: incremental identification update — \(entries.count) entries")
    }

    // MARK: - Data Loading

    /// An identification entry pairing a phone number with a display label.
    private struct IdentificationEntry {
        let phoneNumber: CXCallDirectoryPhoneNumber
        let label: String
    }

    /// Loads blocked phone numbers from the shared App Group container.
    private func loadBlockedNumbers() -> [CXCallDirectoryPhoneNumber] {
        guard let defaults = UserDefaults(suiteName: SharedContainerSchema.appGroupId) else {
            logger.warning("CallDirectory: App Group defaults not available")
            return []
        }

        guard let stored = defaults.array(forKey: "gemscan.blockedPhoneNumbers") as? [Int64] else {
            return []
        }

        return stored.map { CXCallDirectoryPhoneNumber($0) }
    }

    /// Loads incremental blocked number updates from the shared container.
    private func loadIncrementalBlockedNumbers() -> [CXCallDirectoryPhoneNumber] {
        guard let defaults = UserDefaults(suiteName: SharedContainerSchema.appGroupId) else {
            return []
        }

        guard let stored = defaults.array(forKey: "gemscan.incrementalBlockedNumbers") as? [Int64] else {
            return []
        }

        // Clear incremental list after reading
        defaults.removeObject(forKey: "gemscan.incrementalBlockedNumbers")

        return stored.map { CXCallDirectoryPhoneNumber($0) }
    }

    /// Loads identification entries from the shared container.
    private func loadIdentificationEntries() -> [IdentificationEntry] {
        guard let defaults = UserDefaults(suiteName: SharedContainerSchema.appGroupId),
              let data = defaults.data(forKey: "gemscan.identificationEntries") else {
            return []
        }

        guard let decoded = try? JSONDecoder().decode([[String: String]].self, from: data) else {
            logger.warning("CallDirectory: failed to decode identification entries")
            return []
        }

        return decoded.compactMap { dict in
            guard let numberStr = dict["phone_number"],
                  let number = Int64(numberStr),
                  let label = dict["label"] else {
                return nil
            }
            return IdentificationEntry(
                phoneNumber: CXCallDirectoryPhoneNumber(number),
                label: label
            )
        }
    }

    /// Loads incremental identification entry updates.
    private func loadIncrementalIdentificationEntries() -> [IdentificationEntry] {
        guard let defaults = UserDefaults(suiteName: SharedContainerSchema.appGroupId),
              let data = defaults.data(forKey: "gemscan.incrementalIdentificationEntries") else {
            return []
        }

        defaults.removeObject(forKey: "gemscan.incrementalIdentificationEntries")

        guard let decoded = try? JSONDecoder().decode([[String: String]].self, from: data) else {
            return []
        }

        return decoded.compactMap { dict in
            guard let numberStr = dict["phone_number"],
                  let number = Int64(numberStr),
                  let label = dict["label"] else {
                return nil
            }
            return IdentificationEntry(
                phoneNumber: CXCallDirectoryPhoneNumber(number),
                label: label
            )
        }
    }
}

// MARK: - CXCallDirectoryExtensionContextDelegate

extension CallDirectoryExtension: CXCallDirectoryExtensionContextDelegate {

    func requestFailed(for extensionContext: CXCallDirectoryExtensionContext, withError error: Error) {
        logger.error("CallDirectory request failed: \(error.localizedDescription)")
    }
}
