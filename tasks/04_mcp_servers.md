# Tasks — Ten MCP Servers

> **Spec:** `specs/04_mcp_servers.md` | **Milestone:** M4 — Ten MCP Servers | **Depends on:** M0, M2

## Milestone Summary
Implement the full on-device MCP (Model Context Protocol) server layer: one `MCPClient` actor with access-control enforcement, and ten server implementations covering scam pattern matching, vector search, contacts lookup, URL reputation, WHOIS, reverse image analysis, phone reputation, message history, clipboard signals, and screen-time context. All servers run entirely on-device — zero outbound HTTP. The `MCPClient` is the gating dependency for M3 agent end-to-end testing.

## Prerequisites
- M0 complete: `GemScanError`, `AgentID`, `AgentTask`, `AgentResult` types defined
- M2 complete: `TextEmbedder` (for `SqliteVecServer` embedding dimension = 128 floats), `ModelLoader` (for bundle path resolution), `SharedContainerSchema.appGroupId`
- Apple Developer portal: App Group `group.com.gemscan` registered for the main App ID (ContactsServer needs the Contacts entitlement; MessageFilterServer needs the App Group entitlement)

## Progress Tracker
| Status | Count |
|--------|-------|
| ✅ Done | 0 |
| 🔄 In progress | 0 |
| ⬜ Not started | 19 |

---
## Tasks

#### ⬜ T-04-001 · SCAFFOLD · P0 — MCPServer protocol + MCPClient + error types

| Field | Value |
|---|---|
| **Type** | SCAFFOLD |
| **Priority** | P0 |
| **Spec ref** | §2 — MCPClient architecture and access control |
| **Depends on** | None |
| **Estimated effort** | M |
| **Files to create/modify** | `ios/App/GemmaKit/Sources/MCP/MCPClient.swift` |

**What to build:**
Create `ios/App/GemmaKit/Sources/MCP/MCPClient.swift`. Define the following types in this file: `protocol MCPServer` with `var serverName: String { get }` and `func execute(tool: String, input: [String: String]) async throws -> MCPToolResult`; `struct MCPToolDefinition` with `name: String`, `description: String`, `fields: [String: MCPFieldType]`; `enum MCPFieldType: String` with cases `string`, `int`, `float`, `bool`; `struct MCPToolResult` with `output: [String: String]`; `enum MCPError: Error` with cases `accessDenied`, `serverError(String)`, `unknownTool(String)`, `unknownServer(String)`; `struct ToolCallRecord` with `agentId: AgentID`, `server: String`, `tool: String`, `timestamp: Date`. Define `actor MCPClient` with `static let shared = MCPClient()`, a private `servers: [String: any MCPServer]` dictionary, and `func register(server: any MCPServer)`. Implement `func call(server: String, tool: String, input: [String: String], callerAgentId: AgentID) async throws -> MCPToolResult` that checks the static `allowlist: [AgentID: Set<String>]` dictionary (keyed by `"server/tool"`) before forwarding to `servers[server]?.execute(tool:input:)`. Implement the `call(tool:callerAgentId:)` convenience overload that accepts a `RawToolCall`. If the agent is not in the allowlist for the requested `server/tool`, throw `MCPError.accessDenied`.

**Acceptance criteria:**
- [ ] `MCPClient.shared.register(server:)` stores the server by `server.serverName`
- [ ] A call from an agent not in the allowlist throws `MCPError.accessDenied` synchronously (before `execute` is called)
- [ ] `ToolCallRecord` is appended to an internal audit log on every successful call
- [ ] `actor MCPClient` compiles without warnings under `SWIFT_STRICT_CONCURRENCY=complete`
- [ ] `MCPClient.resetForTesting()` is available in `#if DEBUG` to clear all registered servers

**Apple compliance (Spec 00 §11):**
- [ ] §11.3 — on-device only: `MCPClient` makes zero outbound network calls; verified by Instruments Network trace

---

#### ⬜ T-04-002 · IMPLEMENT · P0 — ScamPatternsServer

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P0 |
| **Spec ref** | §3.1 — ScamPatternsServer tool definitions |
| **Depends on** | T-04-001 |
| **Estimated effort** | M |
| **Files to create/modify** | `ios/App/GemmaKit/Sources/MCP/ScamPatternsServer.swift` |

**What to build:**
Create `ios/App/GemmaKit/Sources/MCP/ScamPatternsServer.swift` as `actor ScamPatternsServer: MCPServer`. Set `let serverName = "scam_patterns"`. In `init()`, load `ScamPatterns.json` from `Bundle.main` using `Bundle.main.url(forResource: "ScamPatterns", withExtension: "json")` and decode into a `[ScamPattern]` array stored as `private let patterns: [ScamPattern]`. Define `struct ScamPattern: Codable` with `id: String`, `keywords: [String]`, `language: String`, `riskLevel: String`. Implement `match_patterns` tool: accept `text_hash: String` and optional `language: String` from `input`; filter `patterns` by language if provided; return `output["matched_patterns"]` as a comma-separated list of matched pattern IDs, `output["risk_level"]` as the highest matched risk level, and `output["pattern_count"]` as a string-encoded integer. Implement `get_pattern_detail` tool: accept `pattern_id: String`, look up the pattern, return `output["id"]`, `output["keywords"]`, `output["risk_level"]`.

**Acceptance criteria:**
- [ ] `ScamPatternsServer().serverName == "scam_patterns"`
- [ ] `match_patterns` with a language filter returns only patterns for that language
- [ ] `get_pattern_detail` with an unknown `pattern_id` throws `MCPError.unknownTool` or returns an empty result (not a crash)
- [ ] `ScamPatterns.json` is bundled in `ios/App/App/Resources/ScamPatterns.json`

**Apple compliance (Spec 00 §11):**
- [ ] §11.3 — on-device only: `ScamPatterns.json` loaded from bundle, no network fetch

---

#### ⬜ T-04-003 · IMPLEMENT · P0 — SqliteVecServer

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P0 |
| **Spec ref** | §3.2 — SqliteVecServer database schema and vector operations |
| **Depends on** | T-04-001 |
| **Estimated effort** | L |
| **Files to create/modify** | `ios/App/GemmaKit/Sources/MCP/SqliteVecServer.swift` |

**What to build:**
Create `ios/App/GemmaKit/Sources/MCP/SqliteVecServer.swift` as `actor SqliteVecServer: MCPServer`. Set `let serverName = "sqlite_vec"`. In `init()`, call `openDatabase()` to open or create the SQLite database at `FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent("GemScan/scam_embeddings.db")`. `openDatabase()` must: call `sqlite_vec_auto_init(db)` to load the vec0 extension; execute `CREATE VIRTUAL TABLE IF NOT EXISTS scam_embeddings USING vec0(embedding FLOAT[128])` to create the vector table; execute `CREATE TABLE IF NOT EXISTS scam_metadata(rowid INTEGER PRIMARY KEY, verdict TEXT, confidence REAL, created_at TEXT)`. Implement `semantic_search` tool: accept `embedding: String` (JSON float array) and optional `limit: String`; decode via `floatArrayToBlob(_:)`; run `SELECT rowid, vec_distance_cosine(embedding, ?) AS distance FROM scam_embeddings ORDER BY distance LIMIT ?`; return `output["results"]` as JSON array of `{rowid, distance}` objects and `output["count"]`. Implement `store_embedding` tool: accept `embedding: String`, `verdict: String`, `confidence: String`; insert into `scam_embeddings` (get the new rowid), then insert into `scam_metadata`. Implement `private func floatArrayToBlob(_ jsonArray: String) -> Data`: decode the JSON string as `[Float]`, then encode each float as 4 bytes little-endian (IEEE 754) — exactly 128 floats × 4 bytes = 512 bytes.

**Acceptance criteria:**
- [ ] `floatArrayToBlob("[1.0]")` produces a 4-byte `Data` where the bytes equal `0x00 0x00 0x80 0x3F` (IEEE 754 LE for 1.0f)
- [ ] `store_embedding` followed immediately by `semantic_search` with the same embedding returns a result with `distance <= 0.01`
- [ ] Database file is created at `applicationSupport/GemScan/scam_embeddings.db` on first launch
- [ ] `openDatabase()` is idempotent — calling it twice does not corrupt the schema

**Apple compliance (Spec 00 §11):**
- [ ] §11.3 — on-device only: no cloud sync, no outbound embedding upload

---

#### ⬜ T-04-004 · IMPLEMENT · P0 — ContactsServer

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P0 |
| **Spec ref** | §3.3 — ContactsServer privacy-preserving sender lookup |
| **Depends on** | T-04-001 |
| **Estimated effort** | M |
| **Files to create/modify** | `ios/App/GemmaKit/Sources/MCP/ContactsServer.swift` |

**What to build:**
Create `ios/App/GemmaKit/Sources/MCP/ContactsServer.swift` as `actor ContactsServer: MCPServer`. Add `import Contacts` and `import CryptoKit` at the **file level** (not inside any function body). Set `let serverName = "contacts"`. Implement the `is_known_sender` tool: accept `sender_hash: String` from `input`. Before enumerating, check `CNContactStore.authorizationStatus(for: .contacts)` — if not `.authorized`, return `output["is_known"] = "false"` and `output["contact_count"] = "0"` silently (no error throw, no permission request). If authorized, create a `CNContactFetchRequest` with `keysToFetch: [CNContactPhoneNumbersKey, CNContactEmailAddressesKey] as [CNKeyDescriptor]`. For each contact, compute `SHA256(phoneNumber.stringValue.filter(\.isNumber))` and `SHA256(emailAddress.value)` as hex strings and compare against `sender_hash`. Return `output["is_known"]` as `"true"` or `"false"` and `output["contact_count"]` as the total count of enumerated contacts. **Never** return any raw contact data (name, phone, email) in the output.

**Acceptance criteria:**
- [ ] `import Contacts` and `import CryptoKit` are at file scope — confirmed by code review
- [ ] When `authorizationStatus != .authorized`, the tool returns `{is_known: "false", contact_count: "0"}` without throwing
- [ ] Output dictionary never contains raw phone numbers, emails, or contact names
- [ ] SHA-256 hash computation uses `CryptoKit.SHA256.hash(data:)`, not a third-party library

**Apple compliance (Spec 00 §11):**
- [ ] §11.3 — on-device only, no PII in output, contacts never leave the device
- [ ] §11.4 — `NSContactsUsageDescription` present in `Info.plist`

---

#### ⬜ T-04-005 · IMPLEMENT · P0 — URLReputationServer

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P0 |
| **Spec ref** | §3.4 — URLReputationServer heuristic scoring |
| **Depends on** | T-04-001 |
| **Estimated effort** | M |
| **Files to create/modify** | `ios/App/GemmaKit/Sources/MCP/URLReputationServer.swift` |

**What to build:**
Create `ios/App/GemmaKit/Sources/MCP/URLReputationServer.swift` as `actor URLReputationServer: MCPServer`. Set `let serverName = "url_reputation"`. In `init()`, load `blocklist.json` from the bundle and decode as `Set<String>` stored in `private let blocklist`. Also define `private let safelistDomains: Set<String>` with common safe domains (e.g. `"apple.com"`, `"google.com"`). Implement `check_url` tool: accept `url: String`. Parse with `URLComponents(string: url)` to extract `host`. Compute `heuristicScore: Double` starting at 0.0, adding: `+0.3` if TLD is in the high-risk set (`[".tk", ".ml", ".ga", ".cf", ".gq"]`); `+0.2` if Shannon entropy of `url.path` exceeds 4.5 bits; `+0.4` if `host` matches an IP address regex (`^\d{1,3}(\.\d{1,3}){3}$`); `+0.1` if subdomain depth (dot count in host minus 1) exceeds 4. Check `blocklist.contains(host ?? "")` → `blocklisted: Bool`. If `safelistDomains.contains(host ?? "")`, force `heuristicScore = 0.0`. Return `output["risk_score"]` (string-encoded Double), `output["blocklisted"]` (`"true"`/`"false"`), `output["signals"]` (comma-separated list of triggered signal names).

**Acceptance criteria:**
- [ ] A `.tk` TLD URL returns `risk_score >= 0.3`
- [ ] An IP address URL returns `risk_score >= 0.4`
- [ ] A domain in `safelistDomains` returns `risk_score == "0.0"` regardless of TLD
- [ ] `blocklisted` is `"true"` for any domain in the loaded `blocklist.json`

**Apple compliance (Spec 00 §11):**
- [ ] §11.3 — on-device only: blocklist loaded from bundle, no outbound URL lookup

---

#### ⬜ T-04-006 · IMPLEMENT · P1 — WhoisServer

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P1 |
| **Spec ref** | §3.5 — WhoisServer cached domain metadata |
| **Depends on** | T-04-001 |
| **Estimated effort** | S |
| **Files to create/modify** | `ios/App/GemmaKit/Sources/MCP/WhoisServer.swift` |

**What to build:**
Create `ios/App/GemmaKit/Sources/MCP/WhoisServer.swift` as `actor WhoisServer: MCPServer`. Set `let serverName = "whois"`. Define `struct WhoisRecord: Codable` with `ageDays: Int`, `registrar: String`, `country: String`, `privacyProtected: Bool`. In `init()`, load `whois-cache.json` from the bundle and decode as `[String: WhoisRecord]` stored as `private let cache`. Implement `lookup` tool: accept `domain: String`. If `cache[domain]` exists, return its fields as string-encoded output: `output["age_days"]`, `output["registrar"]`, `output["country"]`, `output["privacy_protected"]`. If not found, return conservative unknown defaults: `output["age_days"] = "-1"`, `output["registrar"] = "unknown"`, `output["country"] = "unknown"`, `output["privacy_protected"] = "true"`.

**Acceptance criteria:**
- [ ] Known domain in `whois-cache.json` returns its actual `age_days` value
- [ ] Unknown domain returns `age_days: "-1"` and `privacy_protected: "true"` (conservative defaults)
- [ ] `whois-cache.json` is bundled in the app target and loaded at `init()` — no network WHOIS queries
- [ ] `WhoisServer` compiles as an `actor` without warnings

**Apple compliance (Spec 00 §11):**
- [ ] §11.3 — on-device only: no live WHOIS network request permitted

---

#### ⬜ T-04-007 · IMPLEMENT · P1 — ReverseImageServer

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P1 |
| **Spec ref** | §3.6 — ReverseImageServer OCR, QR, and perceptual hash |
| **Depends on** | T-04-001 |
| **Estimated effort** | M |
| **Files to create/modify** | `ios/App/GemmaKit/Sources/MCP/ReverseImageServer.swift` |

**What to build:**
Create `ios/App/GemmaKit/Sources/MCP/ReverseImageServer.swift` as `actor ReverseImageServer: MCPServer`. Add `import Vision` at file level. Set `let serverName = "reverse_image"`. Implement `extract_text_urls` tool: accept `image_base64: String`; decode to `Data` with `Data(base64Encoded:)`; create a `VNRecognizeTextRequest` and run via `VNImageRequestHandler`; collect all recognized strings; run `NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)` over the concatenated text to extract URLs; also run `VNDetectBarcodesRequest` with `symbologies: [.qr]` (call this via a private `checkForQRCodes(_:)` method) to detect QR code URLs. Return `output["url_count"]` (string int), `output["urls"]` (top 10, newline-separated), `output["text_length"]` (total OCR character count), `output["has_qr"]` (`"true"`/`"false"`). Implement `compute_phash` tool: accept `image_base64: String`; decode to `UIImage`; render at 32×32 pixels via `CGContext` in 8bpp greyscale; compute a 64-bit perceptual hash by comparing each pixel to the row mean; return `output["phash"]` as a 16-character lowercase hex string.

**Acceptance criteria:**
- [ ] `extract_text_urls` on a test image containing `"https://example.com"` returns `url_count: "1"` and `urls` containing that URL
- [ ] `compute_phash` on the same image twice returns the identical hex string (deterministic)
- [ ] `has_qr: "true"` is returned for an image containing a QR code
- [ ] `checkForQRCodes` is a private method (not part of `MCPServer` protocol)

**Apple compliance (Spec 00 §11):**
- [ ] §11.3 — on-device only: Vision framework used locally, no cloud OCR
- [ ] §11.4 — `NSCameraUsageDescription` not needed (analyzing existing images, not capturing)

---

#### ⬜ T-04-008 · IMPLEMENT · P1 — PhoneReputationServer

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P1 |
| **Spec ref** | §3.7 — PhoneReputationServer number hash lookup |
| **Depends on** | T-04-001 |
| **Estimated effort** | S |
| **Files to create/modify** | `ios/App/GemmaKit/Sources/MCP/PhoneReputationServer.swift` |

**What to build:**
Create `ios/App/GemmaKit/Sources/MCP/PhoneReputationServer.swift` as `actor PhoneReputationServer: MCPServer`. Add `import CryptoKit` at file level. Set `let serverName = "phone_reputation"`. Define `struct PhoneRecord: Codable` with `riskScore: Float`, `reportCount: Int`. In `init()`, load `phone-reputation.json` from the bundle and decode as `[String: PhoneRecord]` where keys are SHA-256 hex strings of E.164 digit-only phone numbers. Implement `check` tool: accept `text: String`. Call private `extractPhoneNumbers(from: text) -> [String]` using `NSDataDetector(types: NSTextCheckingResult.CheckingType.phoneNumber.rawValue)`, then for each found number: strip all non-decimal characters, compute `SHA256(digits)` as a lowercase hex string, look up in `knownScamNumbers`. Return `output["found_numbers"]` (count string), `output["max_risk_score"]` (highest `riskScore` as string, or `"0.0"` if none found), `output["report_count"]` (sum of `reportCount` across matched records).

**Acceptance criteria:**
- [ ] `extractPhoneNumbers(from: "call 415-555-1234 now")` returns `["4155551234"]` (digits only)
- [ ] A number whose hash is in `phone-reputation.json` returns `max_risk_score > "0.0"`
- [ ] An unrecognized number returns `max_risk_score: "0.0"` and `report_count: "0"`
- [ ] Raw phone number strings never appear in the output dictionary

**Apple compliance (Spec 00 §11):**
- [ ] §11.3 — on-device only: phone number hashes looked up in bundled data, no network lookup

---

#### ⬜ T-04-009 · IMPLEMENT · P1 — MessageFilterServer

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P1 |
| **Spec ref** | §3.8 — MessageFilterServer sender history via App Group |
| **Depends on** | T-04-001 |
| **Estimated effort** | S |
| **Files to create/modify** | `ios/App/GemmaKit/Sources/MCP/MessageFilterServer.swift` |

**What to build:**
Create `ios/App/GemmaKit/Sources/MCP/MessageFilterServer.swift` as `actor MessageFilterServer: MCPServer`. Set `let serverName = "message_filter"`. In `init()`, store `private let defaults = UserDefaults(suiteName: SharedContainerSchema.appGroupId)`. Implement `check_sender_history` tool: accept `sender_hash: String`. Compute the UserDefaults key as `"filter_history_\(sender_hash)"`. Attempt to read `defaults?.dictionary(forKey: key)` as `[String: Any]`. If found, return `output["previous_verdict"]` from the dict's `"verdict"` key, `output["user_allowed"]` from `"user_allowed"` (as `"true"`/`"false"`), `output["scan_count"]` from `"scan_count"`. If the key is absent or the suite is unavailable, return unknown defaults: `output["previous_verdict"] = "unknown"`, `output["user_allowed"] = "false"`, `output["scan_count"] = "0"`.

**Acceptance criteria:**
- [ ] After writing `{verdict: "safe", user_allowed: true, scan_count: 3}` to `filter_history_abc123` in the shared defaults, `check_sender_history(sender_hash: "abc123")` returns `previous_verdict: "safe"`, `user_allowed: "true"`, `scan_count: "3"`
- [ ] An absent key returns `previous_verdict: "unknown"` without throwing
- [ ] `UserDefaults(suiteName: SharedContainerSchema.appGroupId)` is the only persistence mechanism used

**Apple compliance (Spec 00 §11):**
- [ ] §11.4 — App Group `group.com.gemscan` entitlement present in main target

---

#### ⬜ T-04-010 · IMPLEMENT · P1 — ClipboardWatcherServer

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P1 |
| **Spec ref** | §3.9 — ClipboardWatcherServer UIPasteboard signals |
| **Depends on** | T-04-001 |
| **Estimated effort** | S |
| **Files to create/modify** | `ios/App/GemmaKit/Sources/MCP/ClipboardWatcherServer.swift` |

**What to build:**
Create `ios/App/GemmaKit/Sources/MCP/ClipboardWatcherServer.swift` as `actor ClipboardWatcherServer: MCPServer`. Set `let serverName = "clipboard_watcher"`. Implement `get_clipboard_signals` tool (no required input parameters). Check `UIPasteboard.general.hasStrings` — if false, return all-zero/empty response: `url_count: "0"`, `has_phone: "false"`, `text_length: "0"`, `risk_signals: ""`. If true, read `UIPasteboard.general.string` (may be nil on first access without user interaction; treat nil as empty). Run `NSDataDetector` for `.link` type to count URLs and for `.phoneNumber` type to detect phone presence. Construct `risk_signals` as a comma-separated string of triggered signal names (e.g. `"has_url,has_phone"`). Return `output["url_count"]`, `output["has_phone"]` (`"true"`/`"false"`), `output["text_length"]`, `output["risk_signals"]`.

**Acceptance criteria:**
- [ ] Empty clipboard returns `url_count: "0"`, `has_phone: "false"`, `text_length: "0"`, `risk_signals: ""`
- [ ] Clipboard containing `"https://example.com"` returns `url_count: "1"` and `risk_signals` containing `"has_url"`
- [ ] `UIPasteboard.general.string` is accessed at most once per `get_clipboard_signals` call
- [ ] No crash if `UIPasteboard.general.string` returns nil

**Apple compliance (Spec 00 §11):**
- [ ] §11.3 — clipboard read is on-device only; contents never transmitted

---

#### ⬜ T-04-011 · IMPLEMENT · P1 — ScreenTimeServer

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P1 |
| **Spec ref** | §3.10 — ScreenTimeServer session context signals |
| **Depends on** | T-04-001 |
| **Estimated effort** | S |
| **Files to create/modify** | `ios/App/GemmaKit/Sources/MCP/ScreenTimeServer.swift` |

**What to build:**
Create `ios/App/GemmaKit/Sources/MCP/ScreenTimeServer.swift` as `actor ScreenTimeServer: MCPServer`. Set `let serverName = "screen_time"`. Implement `get_session_context` tool (no required input parameters). Compute `time_of_day: String` by reading `Calendar.current.component(.hour, from: Date())`: hours 0–5 → `"late_night"`, 6–11 → `"morning"`, 12–17 → `"afternoon"`, 18–23 → `"evening"`. Compute `session_duration_min: String` as `String(Int(ProcessInfo.processInfo.systemUptime / 60))`. Set `notification_pressure: String = "unknown"` with a `// TODO: implement via Family Controls post-hackathon` comment. Return all three as string output values.

**Acceptance criteria:**
- [ ] `get_session_context` returns `time_of_day` as one of `"late_night"`, `"morning"`, `"afternoon"`, `"evening"` with no other possible values
- [ ] `session_duration_min` is a non-negative integer string
- [ ] `notification_pressure` is exactly `"unknown"` (the TODO is documented in source)
- [ ] No Family Controls import is required at this stage

**Apple compliance (Spec 00 §11):**
- [ ] §11.3 — on-device only: no usage data transmitted; `ProcessInfo.systemUptime` is a local read

---

#### ⬜ T-04-012 · INTEGRATE · P0 — Server registration at app startup

| Field | Value |
|---|---|
| **Type** | INTEGRATE |
| **Priority** | P0 |
| **Spec ref** | §4 — Server registration and startup order |
| **Depends on** | T-04-001, T-04-002, T-04-003, T-04-004, T-04-005, T-04-006, T-04-007, T-04-008, T-04-009, T-04-010, T-04-011 |
| **Estimated effort** | S |
| **Files to create/modify** | `ios/App/Plugins/GemmaPlugin+MCP.swift` |

**What to build:**
Create `ios/App/Plugins/GemmaPlugin+MCP.swift` as an extension on `GemmaPlugin` (the existing Capacitor plugin class). Override or implement `func load()` to call a private `setupMCP()` method. In `setupMCP()`, register all ten servers with `MCPClient.shared` in this exact order matching Spec 04 §4: `ScamPatternsServer`, `SqliteVecServer`, `ContactsServer`, `URLReputationServer`, `WhoisServer`, `ReverseImageServer`, `PhoneReputationServer`, `MessageFilterServer`, `ClipboardWatcherServer`, `ScreenTimeServer`. After registration, launch a detached `Task` to call `warmUpE2B()` on `InferenceEngine.shared` so the model is ready before the first analysis request. Each `MCPClient.shared.register(server:)` call must complete before the next server is registered (sequential, not concurrent) to ensure a stable server dictionary.

**Acceptance criteria:**
- [ ] All 10 `MCPClient.shared.register(server:)` calls are present in the correct order
- [ ] `warmUpE2B()` is called as a detached task — it does not block app startup
- [ ] `load()` completes in under 100 ms on an iPhone 12 (server inits are lightweight)
- [ ] `MCPClient.shared.servers.count == 10` after `setupMCP()` completes (verify in a startup integration test)

**Apple compliance (Spec 00 §11):**
- [ ] §11.3 — all servers registered as on-device actors; no network initialization

---

#### ⬜ T-04-013 · IMPLEMENT · P1 — TypeScript web mock MCP client

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P1 |
| **Spec ref** | §6 — Web development mock MCP responses |
| **Depends on** | None |
| **Estimated effort** | S |
| **Files to create/modify** | `src/lib/mcp/mock-client.ts` |

**What to build:**
Create `src/lib/mcp/mock-client.ts`. Export `async function mockMCPCall(server: string, tool: string, input: Record<string, string>): Promise<Record<string, string>>`. Implement fixture responses for all 13 server/tool combinations from Spec 04 §6: `scam_patterns/match_patterns`, `scam_patterns/get_pattern_detail`, `sqlite_vec/semantic_search`, `sqlite_vec/store_embedding`, `contacts/is_known_sender`, `url_reputation/check_url`, `whois/lookup`, `reverse_image/extract_text_urls`, `reverse_image/compute_phash`, `phone_reputation/check`, `message_filter/check_sender_history`, `clipboard_watcher/get_clipboard_signals`, `screen_time/get_session_context`. Each call simulates 10–50 ms latency via `await new Promise(r => setTimeout(r, 10 + Math.random() * 40))`. Unknown `server/tool` combinations should throw `new Error("MCPError.unknownTool")`.

**Acceptance criteria:**
- [ ] All 13 tool paths return valid `Record<string, string>` objects (no undefined fields)
- [ ] Every call introduces at least 10 ms and at most 50 ms of simulated latency
- [ ] `mockMCPCall("url_reputation", "check_url", {url: "https://example.com"})` returns an object with `risk_score`, `blocklisted`, and `signals` keys
- [ ] Unknown tool throws `"MCPError.unknownTool"`

**Apple compliance (Spec 00 §11):**
- [ ] §11.7 — N/A (TypeScript web mock, not shipped in iOS app)

---

#### ⬜ T-04-014 · TEST · P1 — MCP server unit tests

| Field | Value |
|---|---|
| **Type** | TEST |
| **Priority** | P1 |
| **Spec ref** | §5 — MCP access control and server behaviour |
| **Depends on** | T-04-001, T-04-004, T-04-005, T-04-008 |
| **Estimated effort** | M |
| **Files to create/modify** | `ios/App/GemmaKit/Tests/MCPServerTests.swift` |

**What to build:**
Create `ios/App/GemmaKit/Tests/MCPServerTests.swift` as an `XCTestCase` subclass. Write the following tests: `testContactsServerNeverExposesPII()` — assert that no key in `ContactsServer.execute(tool: "is_known_sender", input: ["sender_hash": "abc"])` output contains a raw phone number or email string; `testURLReputationScoredHighRiskTLD()` — assert `Double(result["risk_score"]!)! > 0.30` for input `url: "https://freeprize.tk/win"`; `testURLReputationIPAddressScoredHigh()` — assert `risk_score > 0.40` for input `url: "http://192.168.1.1/phish"`; `testToolAccessControlRejectsUnauthorisedAgent()` — `MCPClient.shared.call(server: "contacts", tool: "is_known_sender", input: [:], callerAgentId: AgentID.urlAgent)` throws `MCPError.accessDenied`; `testSqliteVecServerSearchReturnsResults()` — store a 128-float embedding, then search with the same embedding, assert `similarity >= 0.99`; `testPhoneReputationExtractsNumbers()` — `PhoneReputationServer.execute(tool: "check", input: ["text": "call 415-555-1234"])` returns `found_numbers: "1"`.

**Acceptance criteria:**
- [ ] All six tests pass without network access
- [ ] `testContactsServerNeverExposesPII` inspects every value in the output dictionary
- [ ] `testSqliteVecServerSearchReturnsResults` uses a real (in-memory) SQLite database, not a mock
- [ ] `testToolAccessControlRejectsUnauthorisedAgent` uses a real `MCPClient.shared` with the allowlist

**Apple compliance (Spec 00 §11):**
- [ ] §11.3 — test suite verified: all server operations complete with zero outbound network calls (checked via `URLProtocol` mock that throws on any request)

---

#### ⬜ T-04-015 · TEST · P1 — SqliteVecServer schema tests

| Field | Value |
|---|---|
| **Type** | TEST |
| **Priority** | P1 |
| **Spec ref** | §3.2 — SqliteVecServer database correctness |
| **Depends on** | T-04-003 |
| **Estimated effort** | S |
| **Files to create/modify** | `ios/App/GemmaKit/Tests/SqliteVecServerTests.swift` |

**What to build:**
Create `ios/App/GemmaKit/Tests/SqliteVecServerTests.swift` as an `XCTestCase` subclass using an in-memory or temporary database path (set via a `SqliteVecServer(databasePath:)` test initializer). Write: `testOpenDatabaseCreatesVec0Table()` — after `openDatabase()`, query `SELECT name FROM sqlite_master WHERE type='table' AND name='scam_embeddings'` and assert one row returned; `testFloatArrayToBlobProducesCorrectBytes()` — call `floatArrayToBlob("[1.0, 0.0]")` (exposed via `internal` access for testing) and assert the first 4 bytes equal `[0x00, 0x00, 0x80, 0x3F]` (IEEE 754 LE 1.0f); `testSearchSimilarReturnsEmpty()` — call `semantic_search` on a freshly opened empty database and assert `count: "0"`; `testStoreEmbeddingIncreasesCount()` — call `store_embedding` once, then `semantic_search`, assert `count` increases from `"0"` to `"1"`.

**Acceptance criteria:**
- [ ] `testFloatArrayToBlobProducesCorrectBytes` checks bytes at index 0–3 exactly
- [ ] `testOpenDatabaseCreatesVec0Table` uses a raw SQL query (not a Swift abstraction) to verify the schema
- [ ] All tests use a temporary path (not the production database) — cleaned up in `tearDown()`
- [ ] `floatArrayToBlob` is `internal` (not `private`) to allow test access

**Apple compliance (Spec 00 §11):**
- [ ] §11.7 — N/A (unit tests only)

---

#### ⬜ T-04-016 · TEST · P1 — Web mock MCP tests

| Field | Value |
|---|---|
| **Type** | TEST |
| **Priority** | P1 |
| **Spec ref** | §6 — Mock MCP client correctness |
| **Depends on** | T-04-013 |
| **Estimated effort** | S |
| **Files to create/modify** | `src/lib/mcp/mock-client.test.ts` |

**What to build:**
Create `src/lib/mcp/mock-client.test.ts` as a Vitest test file. Write: `testAllThirteenToolKeysReturnValidObjects()` — call `mockMCPCall` for all 13 tool combinations and assert each returns a non-null object with at least one string-value key; `testEachCallCompletesFiftyMsOrUnder()` — measure wall time for each of the 13 calls and assert each completes in under 50 ms (use `performance.now()`); `testURLReputationReturnsExpectedKeys()` — call `mockMCPCall("url_reputation", "check_url", {url: "https://test.com"})` and assert the result has `risk_score`, `blocklisted`, and `signals` keys; `testUnknownToolThrows()` — call `mockMCPCall("unknown_server", "unknown_tool", {})` and assert it throws with message containing `"MCPError.unknownTool"`.

**Acceptance criteria:**
- [ ] All four Vitest tests pass with `vitest run`
- [ ] No test takes more than 100 ms wall-clock
- [ ] The test file uses TypeScript and imports `mockMCPCall` from `./mock-client`
- [ ] `testUnknownToolThrows` uses `expect(...).rejects.toThrow()`

**Apple compliance (Spec 00 §11):**
- [ ] §11.7 — N/A (web tests, not shipped in iOS app)

---

#### ⬜ T-04-017 · DOCUMENT · P2 — MCP servers DocC

| Field | Value |
|---|---|
| **Type** | DOCUMENT |
| **Priority** | P2 |
| **Spec ref** | §5 — Access control matrix and privacy boundary |
| **Depends on** | T-04-001, T-04-002, T-04-003, T-04-004, T-04-005, T-04-006, T-04-007, T-04-008, T-04-009, T-04-010, T-04-011 |
| **Estimated effort** | S |
| **Files to create/modify** | `ios/App/GemmaKit/Sources/MCP/MCPClient.swift`, `ios/App/GemmaKit/Sources/MCP/` (all server files), `ios/App/GemmaKit/Sources/GemmaKit.docc/MCPServers.md` |

**What to build:**
Add `///` DocC comments to: `MCPServer` protocol (describing the `execute` contract and privacy invariant); `MCPClient.call(server:tool:input:callerAgentId:)` (describing access control enforcement); each server's `execute(tool:input:)` implementation with a list of supported tools. Every server's DocC comment must include the exact sentence: `"Tool inputs are never raw message content — only hashes, counts, and derived signals."` Create `ios/App/GemmaKit/Sources/GemmaKit.docc/MCPServers.md` containing: a prose overview of the MCP layer; the full access control matrix table from Spec 04 §5 (agents as rows, servers as columns, tick/cross cells); a note that `MCPClient` enforces this matrix at runtime via the `allowlist` dictionary.

**Acceptance criteria:**
- [ ] `xcodebuild docbuild` produces zero documentation warnings for the MCP target
- [ ] The privacy invariant sentence appears in every server's DocC comment (confirmed by grep)
- [ ] `MCPServers.md` contains the full access control matrix as a Markdown table
- [ ] DocC article is reachable from the GemmaKit documentation root

**Apple compliance (Spec 00 §11):**
- [ ] §11.7 — N/A (documentation only)

---

#### ⬜ T-04-018 · VALIDATE · P1 — MCP servers Apple compliance

| Field | Value |
|---|---|
| **Type** | VALIDATE |
| **Priority** | P1 |
| **Spec ref** | §11.3 — Spec 00 §11 on-device-only and PII requirements |
| **Depends on** | T-04-004, T-04-012, T-04-014 |
| **Estimated effort** | S |
| **Files to create/modify** | `ios/App/GemmaKit/Sources/MCP/` (fix any issues found — no new files) |

**What to build:**
Run the full Spec 00 §11.7 PR compliance checklist for the M4 milestone. Steps: (1) Verify `ContactsServer.swift` — open the file and confirm `import Contacts` and `import CryptoKit` are at file scope (lines 1–10), not inside any function or method body; (2) Run Instruments Network profile on a full analysis session (main app + SMSFilter extension) — assert zero outbound HTTP requests originate from any `MCP/` code path; (3) Run `xcodebuild analyze -target GemmaKit` and resolve all static analyzer warnings in `Sources/MCP/`; (4) Verify no `print(` statements in any MCP server file (SwiftLint `no_print` rule); (5) Run the CI PII scan script — assert no server log line contains a raw phone number, email address, or contact name pattern; (6) Complete the Spec 00 §11.3 and §11.4 items in the M4 PR description.

**Acceptance criteria:**
- [ ] `import Contacts` and `import CryptoKit` are at file level in `ContactsServer.swift` (not inside a function)
- [ ] Instruments Network trace shows zero outbound requests from the MCP layer during a full analysis
- [ ] `xcodebuild analyze` produces zero issues in `Sources/MCP/`
- [ ] SwiftLint `no_print` rule passes for all MCP server files
- [ ] CI PII scan reports zero matches for phone/email/name patterns in MCP log output

**Apple compliance (Spec 00 §11):**
- [ ] §11.3 — on-device-only verified by Instruments Network trace
- [ ] §11.4 — entitlements verified: Contacts, App Groups capabilities present

---

#### ⬜ T-04-019 · IMPLEMENT · P0 — Bundled data files for MCP servers

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P0 |
| **Spec ref** | §3.1 (ScamPatterns.json), §3.4 (blocklist.json), §3.5 (whois-cache.json), §3.7 (phone-reputation.json) |
| **Depends on** | None |
| **Estimated effort** | M |
| **Files to create/modify** | `ios/App/App/Resources/ScamPatterns.json`, `ios/App/App/Resources/blocklist.json`, `ios/App/App/Resources/whois-cache.json`, `ios/App/App/Resources/phone-reputation.json` |

**What to build:**
Create the four bundled JSON data files that MCP servers load at init. (1) `ScamPatterns.json`: array of `ScamPattern` objects, each with `id`, `keywords`, `language`, `riskLevel`. Seed with at least 20 patterns covering common scam categories: bank impersonation, prize/lottery, package delivery, tech support, IRS/tax, romance, crypto, job offer. Include patterns for `en`, `es`, `hi` languages. (2) `blocklist.json`: array of known-scam domain strings. Seed with at least 50 domains from public phishing blocklists (use well-known test/example domains — do not include active malicious URLs in source code). (3) `whois-cache.json`: dictionary mapping domain strings to `WhoisRecord` objects (`ageDays`, `registrar`, `country`, `privacyProtected`). Seed with 30+ common domains (legitimate and suspicious) to give the WhoisServer meaningful test data. (4) `phone-reputation.json`: dictionary mapping SHA-256 hex strings to `PhoneRecord` objects (`riskScore`, `reportCount`). Seed with 10+ entries for testing. Add all four files to the Xcode "Copy Bundle Resources" build phase for the App target.

**Acceptance criteria:**
- [ ] All four JSON files are valid JSON (parseable by `JSONDecoder`)
- [ ] `ScamPatterns.json` contains ≥ 20 patterns across ≥ 3 languages
- [ ] `blocklist.json` contains ≥ 50 domain entries
- [ ] `whois-cache.json` contains ≥ 30 domain entries with all four fields per record
- [ ] `phone-reputation.json` keys are valid SHA-256 hex strings (64 characters, lowercase hex)
- [ ] All four files are listed in the Xcode target's "Copy Bundle Resources" build phase

**Apple compliance (Spec 00 §11):**
- [ ] §11.3 — Bundled data only; no network fetch for data files at runtime
