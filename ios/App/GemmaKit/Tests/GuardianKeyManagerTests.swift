import XCTest
import CryptoKit
@testable import GemmaKit

/// Tests for Ed25519 key generation, signing, and verification
/// used by the Guardian Mode key exchange protocol.
final class GuardianKeyManagerTests: XCTestCase {

    // MARK: - Key Generation

    func testGenerateKeyPair_ProducesValidKeys() {
        let privateKey = Curve25519.Signing.PrivateKey()
        let publicKey = privateKey.publicKey

        // Ed25519 private key raw representation is 32 bytes
        XCTAssertEqual(privateKey.rawRepresentation.count, 32)

        // Ed25519 public key raw representation is 32 bytes
        XCTAssertEqual(publicKey.rawRepresentation.count, 32)
    }

    func testGenerateKeyPair_ProducesUniqueKeys() {
        let key1 = Curve25519.Signing.PrivateKey()
        let key2 = Curve25519.Signing.PrivateKey()

        // Two independently generated keys should differ
        XCTAssertNotEqual(key1.rawRepresentation, key2.rawRepresentation)
        XCTAssertNotEqual(key1.publicKey.rawRepresentation, key2.publicKey.rawRepresentation)
    }

    // MARK: - Signing

    func testSign_ProducesValidSignature() throws {
        let privateKey = Curve25519.Signing.PrivateKey()
        let message = "Guardian mode activation request".data(using: .utf8)!

        let signature = try privateKey.signature(for: message)

        // Ed25519 signature is 64 bytes
        XCTAssertEqual(signature.count, 64)
    }

    func testSign_DifferentMessages_ProduceDifferentSignatures() throws {
        let privateKey = Curve25519.Signing.PrivateKey()

        let message1 = "Message 1".data(using: .utf8)!
        let message2 = "Message 2".data(using: .utf8)!

        let sig1 = try privateKey.signature(for: message1)
        let sig2 = try privateKey.signature(for: message2)

        XCTAssertNotEqual(sig1, sig2)
    }

    func testSign_SameMessage_SameKey_ProducesConsistentResult() throws {
        let privateKey = Curve25519.Signing.PrivateKey()
        let message = "Consistent message".data(using: .utf8)!

        // Ed25519 is deterministic - same key + same message = same signature
        let sig1 = try privateKey.signature(for: message)
        let sig2 = try privateKey.signature(for: message)

        XCTAssertEqual(sig1, sig2)
    }

    // MARK: - Verification

    func testVerify_ValidSignature_ReturnsTrue() throws {
        let privateKey = Curve25519.Signing.PrivateKey()
        let publicKey = privateKey.publicKey
        let message = "Guardian invite code: ABC123".data(using: .utf8)!

        let signature = try privateKey.signature(for: message)
        let isValid = publicKey.isValidSignature(signature, for: message)

        XCTAssertTrue(isValid)
    }

    func testVerify_TamperedMessage_ReturnsFalse() throws {
        let privateKey = Curve25519.Signing.PrivateKey()
        let publicKey = privateKey.publicKey

        let originalMessage = "Original message".data(using: .utf8)!
        let tamperedMessage = "Tampered message".data(using: .utf8)!

        let signature = try privateKey.signature(for: originalMessage)
        let isValid = publicKey.isValidSignature(signature, for: tamperedMessage)

        XCTAssertFalse(isValid)
    }

    func testVerify_WrongPublicKey_ReturnsFalse() throws {
        let signingKey = Curve25519.Signing.PrivateKey()
        let wrongKey = Curve25519.Signing.PrivateKey()

        let message = "Secret message".data(using: .utf8)!
        let signature = try signingKey.signature(for: message)

        let isValid = wrongKey.publicKey.isValidSignature(signature, for: message)

        XCTAssertFalse(isValid)
    }

    func testVerify_CorruptedSignature_ReturnsFalse() throws {
        let privateKey = Curve25519.Signing.PrivateKey()
        let publicKey = privateKey.publicKey
        let message = "Message to sign".data(using: .utf8)!

        var signature = try privateKey.signature(for: message)

        // Corrupt one byte of the signature
        var bytes = [UInt8](signature)
        bytes[0] ^= 0xFF
        let corrupted = Data(bytes)

        let isValid = publicKey.isValidSignature(corrupted, for: message)

        XCTAssertFalse(isValid)
    }

    // MARK: - Key Serialization

    func testPublicKey_RoundTrips() throws {
        let privateKey = Curve25519.Signing.PrivateKey()
        let originalPublic = privateKey.publicKey

        // Serialize
        let rawBytes = originalPublic.rawRepresentation

        // Deserialize
        let restoredPublic = try Curve25519.Signing.PublicKey(rawRepresentation: rawBytes)

        XCTAssertEqual(originalPublic.rawRepresentation, restoredPublic.rawRepresentation)
    }

    func testPrivateKey_RoundTrips() throws {
        let original = Curve25519.Signing.PrivateKey()

        // Serialize
        let rawBytes = original.rawRepresentation

        // Deserialize
        let restored = try Curve25519.Signing.PrivateKey(rawRepresentation: rawBytes)

        // Verify the restored key produces the same public key
        XCTAssertEqual(original.publicKey.rawRepresentation, restored.publicKey.rawRepresentation)

        // Verify the restored key produces valid signatures
        let message = "Test round-trip".data(using: .utf8)!
        let signature = try restored.signature(for: message)
        let isValid = original.publicKey.isValidSignature(signature, for: message)
        XCTAssertTrue(isValid)
    }

    func testPublicKey_HexEncoding() {
        let privateKey = Curve25519.Signing.PrivateKey()
        let publicKey = privateKey.publicKey

        // Hex-encode the public key (used for sharing in Guardian invite)
        let hex = publicKey.rawRepresentation.map { String(format: "%02x", $0) }.joined()

        XCTAssertEqual(hex.count, 64) // 32 bytes = 64 hex chars
        XCTAssertTrue(hex.allSatisfy { $0.isHexDigit })
    }

    // MARK: - Guardian Invite Flow

    func testGuardianInviteFlow_EndToEnd() throws {
        // Simulate the Guardian Mode key exchange:
        // 1. User A generates a key pair
        // 2. User A shares their public key with User B
        // 3. User B signs an acceptance message
        // 4. User A verifies the acceptance

        // Step 1: User A (ward) generates keys
        let wardPrivateKey = Curve25519.Signing.PrivateKey()
        let wardPublicKey = wardPrivateKey.publicKey

        // Step 2: User B (guardian) generates keys
        let guardianPrivateKey = Curve25519.Signing.PrivateKey()
        let guardianPublicKey = guardianPrivateKey.publicKey

        // Step 3: Ward creates an invite message signed with their key
        let invitePayload = "invite:\(guardianPublicKey.rawRepresentation.base64EncodedString())".data(using: .utf8)!
        let inviteSignature = try wardPrivateKey.signature(for: invitePayload)

        // Step 4: Guardian verifies the invite
        let inviteValid = wardPublicKey.isValidSignature(inviteSignature, for: invitePayload)
        XCTAssertTrue(inviteValid)

        // Step 5: Guardian signs an acceptance
        let acceptPayload = "accept:\(wardPublicKey.rawRepresentation.base64EncodedString())".data(using: .utf8)!
        let acceptSignature = try guardianPrivateKey.signature(for: acceptPayload)

        // Step 6: Ward verifies the acceptance
        let acceptValid = guardianPublicKey.isValidSignature(acceptSignature, for: acceptPayload)
        XCTAssertTrue(acceptValid)
    }

    // MARK: - Empty/Edge Cases

    func testSign_EmptyData() throws {
        let privateKey = Curve25519.Signing.PrivateKey()
        let message = Data()

        // Ed25519 can sign empty data
        let signature = try privateKey.signature(for: message)
        XCTAssertEqual(signature.count, 64)

        let isValid = privateKey.publicKey.isValidSignature(signature, for: message)
        XCTAssertTrue(isValid)
    }

    func testSign_LargeData() throws {
        let privateKey = Curve25519.Signing.PrivateKey()

        // 1 MB of random data
        var largeData = Data(count: 1_000_000)
        _ = largeData.withUnsafeMutableBytes { buffer in
            SecRandomCopyBytes(kSecRandomDefault, buffer.count, buffer.baseAddress!)
        }

        let signature = try privateKey.signature(for: largeData)
        let isValid = privateKey.publicKey.isValidSignature(signature, for: largeData)
        XCTAssertTrue(isValid)
    }
}
