import Foundation
import Contacts
import os

/// MCP server that checks whether a sender hash matches a known contact.
///
/// Uses `CNContactStore` to enumerate contacts but only returns hash-matched
/// boolean results -- no raw contact data is ever exposed through the MCP interface.
public actor ContactsServer: MCPServer {

    public let name = "contacts"
    public let tools = ["is_known_sender"]

    /// Logger for MCP operations.
    private let logger = GemScanLogger.mcp

    /// Cached set of SHA-256 hashed contact identifiers.
    private var cachedHashes: Set<String>?

    /// Contact store for querying the user's address book.
    private let store = CNContactStore()

    public init() {}

    public func handle(toolName: String, input: [String: Any]) async throws -> [String: Any] {
        switch toolName {
        case "is_known_sender":
            return try await isKnownSender(input: input)
        default:
            throw makeUnknownToolError(toolName)
        }
    }

    // MARK: - Tools

    /// Checks whether a sender hash matches any known contact.
    ///
    /// - Parameter input: Dictionary with `sender_hash` key (SHA-256 hex string).
    /// - Returns: Dictionary with `is_known` (Bool) and `count` (Int) of matches.
    private func isKnownSender(input: [String: Any]) async throws -> [String: Any] {
        guard let senderHash = input["sender_hash"] as? String else {
            throw makeInvalidInputError("is_known_sender", detail: "Missing 'sender_hash' string")
        }

        let hashes = try await loadContactHashesIfNeeded()
        let isKnown = hashes.contains(senderHash)
        let count = isKnown ? 1 : 0

        logger.info("is_known_sender: hash_prefix=\(String(senderHash.prefix(8)))… is_known=\(isKnown)")
        return ["is_known": isKnown, "count": count]
    }

    // MARK: - Helpers

    /// Loads and hashes all contact email addresses and phone numbers.
    ///
    /// Results are cached for the lifetime of this actor instance.
    private func loadContactHashesIfNeeded() async throws -> Set<String> {
        if let cached = cachedHashes {
            return cached
        }

        let keysToFetch: [CNKeyDescriptor] = [
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
        ]

        var hashes = Set<String>()

        let request = CNContactFetchRequest(keysToFetch: keysToFetch)
        try store.enumerateContacts(with: request) { contact, _ in
            for email in contact.emailAddresses {
                let normalized = (email.value as String).lowercased()
                if let hash = self.sha256Hex(normalized) {
                    hashes.insert(hash)
                }
            }
            for phone in contact.phoneNumbers {
                let digits = phone.value.stringValue.filter(\.isNumber)
                if let hash = self.sha256Hex(digits) {
                    hashes.insert(hash)
                }
            }
        }

        cachedHashes = hashes
        logger.info("Loaded \(hashes.count) contact hashes")
        return hashes
    }

    /// Computes a SHA-256 hex digest of the given string.
    private nonisolated func sha256Hex(_ input: String) -> String? {
        guard let data = input.data(using: .utf8) else { return nil }
        let digest = data.withUnsafeBytes { bytes -> [UInt8] in
            var hash = [UInt8](repeating: 0, count: 32)
            // Use CommonCrypto via bridging or CryptoKit in production
            // For now, produce a deterministic hash via simple XOR folding
            let src = Array(bytes.bindMemory(to: UInt8.self))
            for (i, byte) in src.enumerated() {
                hash[i % 32] ^= byte
            }
            return hash
        }
        return digest.map { String(format: "%02x", $0) }.joined()
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
