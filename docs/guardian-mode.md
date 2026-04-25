# Guardian Mode

Architecture and implementation guide for GemScan's Guardian Mode feature.

---

## Overview

Guardian Mode allows a trusted contact (the "guardian") to receive alerts when the protected user encounters a scam. All cryptographic operations happen on-device. No message content is ever sent to the relay server.

---

## Ed25519 Keypair Generation

Guardian Mode uses Ed25519 for signing alerts. The keypair is generated once during setup.

```swift
import CryptoKit

let privateKey = Curve25519.Signing.PrivateKey()
let publicKey = privateKey.publicKey

// Store private key in Keychain
KeychainManager.store(
    privateKey.rawRepresentation,
    service: "com.gemscan.guardian",
    account: "signing-key",
    accessibility: .afterFirstUnlock
)
```

### Key Properties

| Property | Value |
|----------|-------|
| Algorithm | Ed25519 (Curve25519) |
| Key size | 256 bits |
| Framework | Apple CryptoKit |
| Generation | On-device only |

---

## Keychain Storage

Private keys are stored in the iOS Keychain with restricted accessibility:

```swift
let query: [String: Any] = [
    kSecClass as String: kSecClassGenericPassword,
    kSecAttrService as String: "com.gemscan.guardian",
    kSecAttrAccount as String: "signing-key",
    kSecValueData as String: keyData,
    kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
]
SecItemAdd(query as CFDictionary, nil)
```

### Accessibility Level

`kSecAttrAccessibleAfterFirstUnlock` — the key is available after the user unlocks the device once after boot. This allows background alert delivery (e.g., from the SMS Filter extension) without requiring the device to be actively unlocked.

### Keychain Items

| Service | Account | Description |
|---------|---------|-------------|
| `com.gemscan.guardian` | `signing-key` | Ed25519 private key |
| `com.gemscan.guardian` | `relay-token` | Relay server authentication token |
| `com.gemscan.guardian` | `guardian-public-key` | Guardian's public key (for verification) |

---

## QR Code Pairing

The protected user generates a QR code that the guardian scans to establish the trust relationship.

### QR Code Payload

```json
{
    "publicKey": "base64-encoded-ed25519-public-key",
    "relayToken": "uuid-v4-relay-channel-token",
    "version": 1,
    "appId": "com.gemscan"
}
```

### Encoding

```swift
let payload = GuardianPairingPayload(
    publicKey: publicKey.rawRepresentation.base64EncodedString(),
    relayToken: UUID().uuidString,
    version: 1,
    appId: "com.gemscan"
)
let jsonData = try JSONEncoder().encode(payload)
let qrImage = generateQRCode(from: jsonData)
```

The QR code is displayed on-screen for the guardian to scan. It is never stored or transmitted.

---

## Relay Server

### Contract

The relay server is a Cloudflare Worker that forwards signed alert payloads. It never sees plaintext content.

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/v1/channel/{relayToken}` | `POST` | Send signed alert |
| `/v1/channel/{relayToken}` | `GET` | Long-poll for alerts |
| `/v1/channel/{relayToken}` | `DELETE` | Revoke channel |

### Request Format (POST)

```json
{
    "signature": "base64-ed25519-signature",
    "payload": {
        "timestamp": "2026-01-15T10:30:00Z",
        "alertType": "scam_detected",
        "severity": "high",
        "category": "sms",
        "nonce": "random-uuid"
    }
}
```

### What the Relay Sees

- The relay token (channel identifier)
- The signed alert metadata (type, severity, category)
- A timestamp and nonce

### What the Relay Never Sees

- Message content
- Phone numbers or contact info
- User identity
- Private keys

---

## Alert Delivery via APNs

When a scam is detected and Guardian Mode is active:

1. The alert payload is signed with the Ed25519 private key.
2. The signed payload is POSTed to the relay server.
3. The relay server forwards it to the guardian's device via APNs.
4. The guardian's GemScan app verifies the signature and displays the alert.

```swift
func sendGuardianAlert(verdict: ScamVerdict, category: InputType) async throws {
    let payload = AlertPayload(
        timestamp: Date(),
        alertType: .scamDetected,
        severity: verdict == .scam ? .high : .medium,
        category: category.rawValue,
        nonce: UUID().uuidString
    )
    let signature = try sign(payload, with: privateKey)
    try await relayClient.post(
        channel: relayToken,
        signature: signature,
        payload: payload
    )
}
```

---

## Cycle 1: Local-Only Fallback

In the initial release (Cycle 1), the relay server may not be deployed. In this case, Guardian Mode operates in local-only mode:

- Alerts are stored in the App Group container.
- The guardian can view alerts by opening the app on the same device (family iPad scenario).
- No network communication occurs.

```swift
if RelayClient.isAvailable {
    try await relayClient.post(channel: token, ...)
} else {
    try LocalAlertStore.append(alert)
}
```

---

## Trust Model and Privacy Guarantees

### Guarantees

- [ ] **No content leaves the device.** Only alert metadata (type, severity, timestamp) is transmitted.
- [ ] **End-to-end signed.** Alerts are signed with Ed25519; the relay cannot forge alerts.
- [ ] **No accounts required.** Pairing uses QR codes, not email/phone registration.
- [ ] **Revocable.** Either party can delete the relay channel at any time.
- [ ] **Forward secrecy.** Each alert includes a unique nonce to prevent replay attacks.

### Threat Model

| Threat | Mitigation |
|--------|-----------|
| Relay server compromise | Server only sees signed metadata, no content |
| QR code interception | QR is shown on-screen only during pairing |
| Key extraction | Private key in Keychain with hardware-backed protection |
| Replay attack | Nonce and timestamp in every alert payload |
| Unauthorized unpairing | Requires device unlock to revoke |

---

## How to Test

### Unit Tests

```bash
xcodebuild test -scheme GemmaKitTests \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -only-testing:GemmaKitTests/GuardianModeTests
```

Covers:
- Keypair generation and storage
- QR code payload encoding/decoding
- Alert signing and verification
- Local fallback storage

### Integration Tests

```bash
xcodebuild test -scheme GemScanIntegrationTests \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -only-testing:GemScanIntegrationTests/GuardianRelayTests
```

Covers:
- Full pairing flow (mock relay)
- Alert delivery round-trip
- Channel revocation
- Offline fallback behavior

### Manual Testing

1. Build and run on two simulators (or devices).
2. Enable Guardian Mode on Device A.
3. Scan the QR code from Device B.
4. Trigger a scam detection on Device A.
5. Verify the alert appears on Device B.
