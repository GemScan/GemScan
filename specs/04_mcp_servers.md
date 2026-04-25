# Spec 04 — MCP Servers

---

## 1. Overview

GemScan runs **10 MCP servers in-process** over an in-memory pipe — no network I/O during inference. Each server exposes one or more `Tool` implementations that the LLM may call during a ReAct loop. Servers are implemented as Swift actors conforming to the `MCPServer` protocol. The web mock returns fixture data for all tools.

All tool inputs are **non-sensitive by design**: no raw message content, no contact names, no audio transcripts. The model receives tool *outputs*, not raw personal data — this is the MCP privacy boundary.

---

## 2. MCP Architecture

```
 ┌─────────────────────────────────────────────────────────┐
 │                    Agent (Swift actor)                   │
 │   textAgent.handle() → inference.generate() →          │
 │   parses tool calls → MCPClient.call()                  │
 └─────────────────────────────┬───────────────────────────┘
                               │ in-memory pipe (no network)
                               ▼
 ┌─────────────────────────────────────────────────────────┐
 │                    MCPClient (actor)                     │
 │   routes by serverName → MCPServer.execute(tool, input) │
 └─────────────────────────────┬───────────────────────────┘
                               │
        ┌──────────────────────┴──────────────────────┐
        ▼                                             ▼
 [scam_patterns]  [sqlite_vec]  [contacts]  … (10 servers total)
```

### MCPClient

```swift
// GemmaKit/Sources/MCP/MCPClient.swift
import Foundation
import os

actor MCPClient {
    static let shared = MCPClient()

    private let logger = Logger(subsystem: "com.gemscan", category: "MCPClient")
    private var registry: [String: any MCPServer] = [:]

    // MARK: - Access Control

    /// Defines which tools each agent is permitted to call.
    /// Enforcement happens in `call()` — any unlisted combination is rejected.
    private static let allowlist: [String: Set<String>] = [
        AgentID.textAgent:    ["scam_patterns/match_patterns", "scam_patterns/get_pattern_detail",
                               "sqlite_vec/semantic_search", "contacts/is_known_sender",
                               "url_reputation/check_url", "phone_reputation/check",
                               "message_filter/check_sender_history"],
        AgentID.urlAgent:     ["sqlite_vec/semantic_search", "url_reputation/check_url",
                               "whois/lookup"],
        AgentID.imageAgent:   ["sqlite_vec/semantic_search", "url_reputation/check_url",
                               "reverse_image/extract_text_urls", "reverse_image/compute_phash"],
        AgentID.voiceAgent:   ["sqlite_vec/semantic_search", "phone_reputation/check"],
        AgentID.judgeAgent:   ["scam_patterns/match_patterns", "scam_patterns/get_pattern_detail",
                               "sqlite_vec/semantic_search"],
        AgentID.orchestrator: ["sqlite_vec/store_embedding", "contacts/is_known_sender",
                               "message_filter/check_sender_history",
                               "clipboard_watcher/get_clipboard_signals",
                               "screen_time/get_session_context"],
    ]

    func register(server: any MCPServer) {
        registry[server.name] = server
        logger.info("Registered MCP server: \(server.name)")
    }

    /// Call a tool on a named server.
    /// - Parameters:
    ///   - server: Server name (e.g. `"url_reputation"`)
    ///   - tool:   Tool name (e.g. `"check_url"`)
    ///   - input:  Key-value string dict. All values are strings; numeric/bool values are
    ///             encoded as strings and parsed by the server (e.g. `"top_k": "5"`).
    ///   - callerAgentId: The `AgentID` constant of the calling agent. Used for access control.
    func call(
        server serverName: String,
        tool toolName: String,
        input: [String: String],
        callerAgentId: String
    ) async throws -> MCPToolResult {
        // Access control check
        let key = "\(serverName)/\(toolName)"
        guard let allowed = MCPClient.allowlist[callerAgentId], allowed.contains(key) else {
            logger.error("Access denied: \(callerAgentId) → \(key)")
            throw MCPError.accessDenied(agent: callerAgentId, tool: key)
        }

        guard let server = registry[serverName] else {
            throw GemScanError.mcpToolFailed(server: serverName, tool: toolName, underlying: MCPError.unknownServer)
        }
        let start = Date()
        do {
            let output = try await server.execute(tool: toolName, input: input)
            let durationMs = Int(-start.timeIntervalSinceNow * 1000)
            logger.info("MCP \(serverName)/\(toolName) completed in \(durationMs)ms")
            return MCPToolResult(
                output: output,
                record: ToolCallRecord(
                    serverName: serverName,
                    toolName: toolName,
                    inputSummary: summariseInput(input),
                    durationMs: durationMs,
                    success: true
                )
            )
        } catch {
            let durationMs = Int(-start.timeIntervalSinceNow * 1000)
            logger.error("MCP \(serverName)/\(toolName) failed in \(durationMs)ms: \(error)")
            return MCPToolResult(
                output: ["error": error.localizedDescription],
                record: ToolCallRecord(
                    serverName: serverName,
                    toolName: toolName,
                    inputSummary: summariseInput(input),
                    durationMs: durationMs,
                    success: false
                )
            )
        }
    }

    /// Convenience overload for tool calls emitted by the LLM in `RawToolCall` form.
    /// The `callerAgentId` must still be provided by the agent so access control is enforced.
    func call(
        tool: RawToolCall,
        callerAgentId: String
    ) async throws -> MCPToolResult {
        try await call(
            server: tool.server,
            tool: tool.tool,
            input: tool.input,
            callerAgentId: callerAgentId
        )
    }

    private func summariseInput(_ input: [String: String]) -> String {
        "{\(input.keys.sorted().joined(separator: ", "))}"
    }
}

enum MCPError: Error {
    case unknownServer
    case unknownTool(String)
    case accessDenied(agent: String, tool: String)
}

protocol MCPServer: Actor {
    var name: String { get }
    var tools: [MCPToolDefinition] { get }
    func execute(tool: String, input: [String: String]) async throws -> [String: String]
}

/// All MCP inputs and outputs use `[String: String]` maps for simplicity across the
/// Capacitor bridge. Type coercion rules:
/// - Numbers are passed as decimal strings (e.g. `"top_k": "5"`, `"risk_score": "0.85"`)
/// - Booleans are passed as `"true"` / `"false"`
/// - Optional absent fields are simply omitted from the input dict
/// Servers must parse numeric and boolean values from strings using `Int()`, `Double()`,
/// or `Bool()` with a documented fallback (e.g. `Int(input["top_k"] ?? "5") ?? 5`).
struct MCPToolDefinition {
    let name: String
    let description: String
    let inputSchema: [String: MCPFieldType]
    let outputSchema: [String: MCPFieldType]
}

enum MCPFieldType: String {
    case string, number, boolean, optional_string
}
```

---

## 3. Server Implementations

### 3.1 `scam_patterns` — Local Rule Database

Stores community-contributed scam patterns (regex + heuristics). Read-only during inference. Updated via OTA signed bundles.

```swift
// GemmaKit/Sources/MCP/ScamPatternsServer.swift
actor ScamPatternsServer: MCPServer {
    let name = "scam_patterns"

    let tools: [MCPToolDefinition] = [
        MCPToolDefinition(
            name: "match_patterns",
            description: "Check text against local scam pattern database. Returns matched pattern IDs and risk level.",
            inputSchema: ["text_hash": .string, "language": .optional_string],
            outputSchema: ["matched_patterns": .string, "risk_level": .string, "pattern_count": .number]
        ),
        MCPToolDefinition(
            name: "get_pattern_detail",
            description: "Retrieve human-readable explanation for a pattern ID.",
            inputSchema: ["pattern_id": .string],
            outputSchema: ["category": .string, "description": .string, "first_seen": .string]
        ),
    ]

    private var patterns: [ScamPattern] = []   // Loaded from bundled JSON at init

    func execute(tool: String, input: [String: String]) async throws -> [String: String] {
        switch tool {
        case "match_patterns":
            // Input is a SHA-256 hash of the text — never the text itself
            let hash = input["text_hash"] ?? ""
            let language = input["language"] ?? "en"
            let matches = matchPatterns(hash: hash, language: language)
            return [
                "matched_patterns": matches.map(\.id).joined(separator: ","),
                "risk_level": riskLevel(matches).rawValue,
                "pattern_count": "\(matches.count)"
            ]
        case "get_pattern_detail":
            let patternId = input["pattern_id"] ?? ""
            guard let pattern = patterns.first(where: { $0.id == patternId }) else {
                return ["category": "unknown", "description": "Pattern not found", "first_seen": ""]
            }
            return ["category": pattern.category, "description": pattern.description, "first_seen": pattern.firstSeen]
        default:
            throw MCPError.unknownTool(tool)
        }
    }

    private func matchPatterns(hash: String, language: String) -> [ScamPattern] {
        // Regex patterns operate on hash for privacy; full-text patterns applied inside InferenceEngine
        patterns.filter { $0.matchesHash(hash, language: language) }
    }
}
```

**Tool access:** Available to `text-agent` and `judge-agent` only.

---

### 3.2 `sqlite_vec` — On-Device Vector Search

Semantic similarity search over a local SQLite database with the `sqlite-vec` extension. Stores embeddings of known scam messages (community-contributed, privacy-preserving — no raw text stored, only embeddings + metadata).

```swift
// GemmaKit/Sources/MCP/SqliteVecServer.swift
actor SqliteVecServer: MCPServer {
    let name = "sqlite_vec"

    let tools: [MCPToolDefinition] = [
        MCPToolDefinition(
            name: "semantic_search",
            description: "Find semantically similar known scam messages. Input: a 128-dimensional float embedding as a JSON array string (generated by TextEmbedder.shared.embed() in GemmaKit). Returns top-k matches with similarity scores.",
            inputSchema: ["embedding_json": .string, "top_k": .optional_string],
            outputSchema: ["matches": .string, "top_similarity": .number]
        ),
        MCPToolDefinition(
            name: "store_embedding",
            description: "Store a new embedding (called after user confirms a scam report). Writes only embedding + verdict — no raw text.",
            inputSchema: ["embedding_json": .string, "verdict": .string, "language": .optional_string],
            outputSchema: ["stored": .boolean, "db_size": .number]
        ),
    ]

    private var db: OpaquePointer?   // sqlite3 handle

    func execute(tool: String, input: [String: String]) async throws -> [String: String] {
        switch tool {
        case "semantic_search":
            let embeddingJson = input["embedding_json"] ?? "[]"
            let topK = Int(input["top_k"] ?? "5") ?? 5
            let results = try searchSimilar(embeddingJson: embeddingJson, topK: topK)
            return ["matches": results.json, "top_similarity": "\(results.topSimilarity)"]
        case "store_embedding":
            let embeddingJson = input["embedding_json"] ?? "[]"
            let verdict = input["verdict"] ?? "suspicious"
            let language = input["language"] ?? "en"
            let size = try storeEmbedding(embeddingJson: embeddingJson, verdict: verdict, language: language)
            return ["stored": "true", "db_size": "\(size)"]
        default:
            throw MCPError.unknownTool(tool)
        }
    }
}
```

> **Note:** Callers must generate embeddings using `TextEmbedder.shared.embed(text:)` (see Spec 02 §8) before calling this tool. The server stores a 128-dimensional vector internally; embeddings generated by a different method or dimension will produce meaningless similarity scores.

**Tool access:** Available to all agents.

---

### 3.3 `contacts` — Address Book Cross-Reference

Read-only access to the device address book. Returns a boolean + metadata (no name, no phone number). Requires `Contacts` permission.

```swift
// GemmaKit/Sources/MCP/ContactsServer.swift
import Contacts
import CryptoKit

actor ContactsServer: MCPServer {
    let name = "contacts"

    let tools: [MCPToolDefinition] = [
        MCPToolDefinition(
            name: "is_known_sender",
            description: "Check if a sender identifier (phone or email hash) is in the user's contacts. Returns boolean — no contact details exposed.",
            inputSchema: ["sender_hash": .string],
            outputSchema: ["is_known": .boolean, "contact_count": .number]
        ),
    ]

    func execute(tool: String, input: [String: String]) async throws -> [String: String] {
        guard tool == "is_known_sender" else { throw MCPError.unknownTool(tool) }

        let hash = input["sender_hash"] ?? ""
        guard CNContactStore.authorizationStatus(for: .contacts) == .authorized else {
            return ["is_known": "false", "contact_count": "0"]
        }

        let store = CNContactStore()
        let request = CNContactFetchRequest(keysToFetch: [CNContactPhoneNumbersKey as CNKeyDescriptor, CNContactEmailAddressesKey as CNKeyDescriptor])
        var isKnown = false
        var count = 0

        try store.enumerateContacts(with: request) { contact, _ in
            count += 1
            // Compare hash of phone/email — never expose raw contact data
            let phoneHashes = contact.phoneNumbers.map { sha256($0.value.stringValue) }
            let emailHashes = contact.emailAddresses.map { sha256($0.value as String) }
            if phoneHashes.contains(hash) || emailHashes.contains(hash) {
                isKnown = true
            }
        }

        return ["is_known": "\(isKnown)", "contact_count": "\(count)"]
    }

    private func sha256(_ input: String) -> String {
        let digest = SHA256.hash(data: Data(input.utf8))
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
}
```

> **Permission:** `ContactsServer` requires `NSContactsUsageDescription` in `Info.plist`. Permission is requested once during first-launch onboarding by calling `CNContactStore().requestAccess(for: .contacts)`. If the user denies permission, all calls to `is_known_sender` return `{ "is_known": "false", "contact_count": "0" }` silently — the degraded result is used as-is and no alert is shown.

**Tool access:** Available to `text-agent` and `orchestrator` only.

---

### 3.4 `url_reputation` — Local + Blocklist URL Scoring

Combines a bundled blocklist (updated via OTA) with heuristic URL scoring (domain age, TLD risk, path entropy).

```swift
// GemmaKit/Sources/MCP/URLReputationServer.swift
actor URLReputationServer: MCPServer {
    let name = "url_reputation"

    let tools: [MCPToolDefinition] = [
        MCPToolDefinition(
            name: "check_url",
            description: "Score a URL's reputation. Returns risk score (0.0–1.0), blocklist match, and heuristic signals.",
            inputSchema: ["url": .string],
            outputSchema: ["risk_score": .number, "blocklisted": .boolean, "signals": .string]
        ),
    ]

    private var blocklist: Set<String> = []    // Bloom filter of known-bad domains
    private var safelistDomains: Set<String> = []

    func execute(tool: String, input: [String: String]) async throws -> [String: String] {
        guard tool == "check_url" else { throw MCPError.unknownTool(tool) }

        let urlString = input["url"] ?? ""
        guard let url = URL(string: urlString), let host = url.host else {
            return ["risk_score": "0.5", "blocklisted": "false", "signals": "invalid_url"]
        }

        let blocklisted = blocklist.contains(host.lowercased())
        let safelisted = safelistDomains.contains(host.lowercased())
        let heuristicScore = computeHeuristicScore(url: url)

        let riskScore: Double
        if blocklisted { riskScore = 0.95 }
        else if safelisted { riskScore = 0.05 }
        else { riskScore = heuristicScore }

        let signals = buildSignals(url: url, blocklisted: blocklisted, heuristicScore: heuristicScore)

        return [
            "risk_score": String(format: "%.2f", riskScore),
            "blocklisted": "\(blocklisted)",
            "signals": signals
        ]
    }

    private func computeHeuristicScore(url: URL) -> Double {
        var score = 0.0
        let host = url.host?.lowercased() ?? ""

        // TLD risk
        let highRiskTLDs = [".xyz", ".top", ".click", ".loan", ".work", ".gq", ".tk", ".ml"]
        if highRiskTLDs.contains(where: { host.hasSuffix($0) }) { score += 0.3 }

        // Path entropy (random-looking paths suggest phishing)
        if let path = url.path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) {
            let entropy = shannonEntropy(path)
            if entropy > 4.5 { score += 0.2 }
        }

        // IP address instead of domain
        if isIPAddress(host) { score += 0.4 }

        // Subdomain depth > 3
        let subdomainDepth = host.components(separatedBy: ".").count
        if subdomainDepth > 4 { score += 0.1 }

        return min(score, 0.9)
    }
}
```

**Tool access:** Available to `url-agent`, `text-agent`, `image-agent`.

---

### 3.5 `whois` — Domain Registration Lookup

On-device whois client using a bundled parsed cache. Falls back to a hardened DNS lookup (no external HTTP).

```swift
// GemmaKit/Sources/MCP/WhoisServer.swift
actor WhoisServer: MCPServer {
    let name = "whois"

    let tools: [MCPToolDefinition] = [
        MCPToolDefinition(
            name: "lookup",
            description: "Get domain registration metadata: age in days, registrar, country. Newly-registered domains (<30 days) are high risk.",
            inputSchema: ["domain": .string],
            outputSchema: ["age_days": .number, "registrar": .string, "country": .string, "privacy_protected": .boolean]
        ),
    ]

    private var cache: [String: WhoisRecord] = [:]    // Populated from bundled dataset + runtime cache

    func execute(tool: String, input: [String: String]) async throws -> [String: String] {
        guard tool == "lookup" else { throw MCPError.unknownTool(tool) }

        let domain = input["domain"]?.lowercased() ?? ""
        if let cached = cache[domain] {
            return cached.toDict()
        }

        // Unknown domain — return conservative defaults
        return ["age_days": "-1", "registrar": "unknown", "country": "unknown", "privacy_protected": "true"]
    }
}
```

**Tool access:** Available to `url-agent`.

---

### 3.6 `reverse_image` — Screenshot OCR + Image Hash

Extracts text and URLs from images using the on-device Vision framework. Returns a perceptual hash for known-scam image matching.

```swift
// GemmaKit/Sources/MCP/ReverseImageServer.swift
import Vision

actor ReverseImageServer: MCPServer {
    let name = "reverse_image"

    let tools: [MCPToolDefinition] = [
        MCPToolDefinition(
            name: "extract_text_urls",
            description: "OCR an image and return extracted text summary and URLs found. No raw text returned — only URL list and text length.",
            inputSchema: ["base64": .string],
            outputSchema: ["url_count": .number, "urls": .string, "text_length": .number, "has_qr": .boolean]
        ),
        MCPToolDefinition(
            name: "compute_phash",
            description: "Compute perceptual hash of image for known-scam-image matching.",
            inputSchema: ["base64": .string],
            outputSchema: ["phash": .string]
        ),
    ]

    func execute(tool: String, input: [String: String]) async throws -> [String: String] {
        let base64 = input["base64"] ?? ""
        guard let imageData = Data(base64Encoded: base64),
              let cgImage = UIImage(data: imageData)?.cgImage else {
            throw GemScanError.grammarViolation(raw: "Invalid base64 image data")
        }

        switch tool {
        case "extract_text_urls":
            return try await extractTextAndURLs(cgImage: cgImage)
        case "compute_phash":
            let hash = computePHash(cgImage: cgImage)
            return ["phash": hash]
        default:
            throw MCPError.unknownTool(tool)
        }
    }

    private func extractTextAndURLs(cgImage: CGImage) async throws -> [String: String] {
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error { continuation.resume(throwing: error); return }
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: ["url_count": "0", "urls": "", "text_length": "0", "has_qr": "false"])
                    return
                }

                let allText = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: " ")
                let urls = extractURLs(from: allText)
                let hasQR = observations.isEmpty ? false : checkForQRCodes(cgImage: cgImage)

                continuation.resume(returning: [
                    "url_count": "\(urls.count)",
                    "urls": urls.prefix(10).joined(separator: ","),
                    "text_length": "\(allText.count)",
                    "has_qr": "\(hasQR)"
                ])
            }
            request.recognitionLevel = .accurate
            try? VNImageRequestHandler(cgImage: cgImage).perform([request])
        }
    }

    private func extractURLs(from text: String) -> [String] {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let matches = detector?.matches(in: text, range: NSRange(text.startIndex..., in: text)) ?? []
        return matches.compactMap { $0.url?.absoluteString }
    }
}
```

**Tool access:** Available to `image-agent`.

---

### 3.7 `phone_reputation` — Phone Number Scoring

Cross-references phone numbers against a local crowd-sourced database of known scam numbers. No network call — data is bundled and updated via signed OTA bundles.

```swift
// GemmaKit/Sources/MCP/PhoneReputationServer.swift
import CryptoKit

actor PhoneReputationServer: MCPServer {
    let name = "phone_reputation"

    let tools: [MCPToolDefinition] = [
        MCPToolDefinition(
            name: "check",
            description: "Check if a transcript excerpt contains a known scam phone number. Returns risk score and report count.",
            inputSchema: ["transcript_excerpt": .string],
            outputSchema: ["found_numbers": .number, "max_risk_score": .number, "report_count": .number]
        ),
    ]

    private var knownScamNumbers: [String: PhoneRecord] = [:]  // Phone hash → record

    func execute(tool: String, input: [String: String]) async throws -> [String: String] {
        guard tool == "check" else { throw MCPError.unknownTool(tool) }

        // Extract and hash phone numbers from transcript excerpt — no raw numbers stored
        let excerpt = input["transcript_excerpt"] ?? ""
        let phoneNumbers = extractPhoneNumbers(from: excerpt)
        let hashes = phoneNumbers.map { sha256($0) }

        let matches = hashes.compactMap { knownScamNumbers[$0] }
        let maxRisk = matches.map(\.riskScore).max() ?? 0.0
        let totalReports = matches.map(\.reportCount).reduce(0, +)

        return [
            "found_numbers": "\(matches.count)",
            "max_risk_score": String(format: "%.2f", maxRisk),
            "report_count": "\(totalReports)"
        ]
    }

    /// Extract E.164 phone number strings from free text using NSDataDetector.
    /// Returns digits-only strings (no `+` prefix, no formatting) for consistent hashing.
    private func extractPhoneNumbers(from text: String) -> [String] {
        guard let detector = try? NSDataDetector(
            types: NSTextCheckingResult.CheckingType.phoneNumber.rawValue
        ) else { return [] }
        let matches = detector.matches(in: text, range: NSRange(text.startIndex..., in: text))
        return matches.compactMap { result in
            guard let phoneNumber = result.phoneNumber else { return nil }
            // Strip all non-digit characters to normalise to digits-only E.164 integer form
            return phoneNumber.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        }.filter { !$0.isEmpty }
    }

    private func sha256(_ input: String) -> String {
        let digest = SHA256.hash(data: Data(input.utf8))
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
}
```

**Tool access:** Available to `voice-agent`, `text-agent`.

---

### 3.8 `message_filter` — iOS Message Filter Extension Bridge

Provides a read-only bridge to the SMS Filter extension's classification history and allow-lists. Used to check if a sender was previously allowed by the user.

```swift
// GemmaKit/Sources/MCP/MessageFilterServer.swift
actor MessageFilterServer: MCPServer {
    let name = "message_filter"

    let tools: [MCPToolDefinition] = [
        MCPToolDefinition(
            name: "check_sender_history",
            description: "Check classification history for a sender hash. Returns previous verdict and user action (if any).",
            inputSchema: ["sender_hash": .string],
            outputSchema: ["previous_verdict": .string, "user_allowed": .boolean, "scan_count": .number]
        ),
    ]

    private let sharedDefaults: UserDefaults?   // App Group shared defaults

    init() {
        sharedDefaults = UserDefaults(suiteName: SharedContainerSchema.appGroupId)
    }

    func execute(tool: String, input: [String: String]) async throws -> [String: String] {
        guard tool == "check_sender_history" else { throw MCPError.unknownTool(tool) }

        let senderHash = input["sender_hash"] ?? ""
        let key = "filter_history_\(senderHash)"

        guard let record = sharedDefaults?.dictionary(forKey: key) else {
            return ["previous_verdict": "unknown", "user_allowed": "false", "scan_count": "0"]
        }

        return [
            "previous_verdict": record["verdict"] as? String ?? "unknown",
            "user_allowed": "\(record["user_allowed"] as? Bool ?? false)",
            "scan_count": "\(record["scan_count"] as? Int ?? 0)"
        ]
    }
}
```

**Tool access:** Available to `text-agent`, `orchestrator`.

---

### 3.9 `clipboard_watcher` — Clipboard Scam Detection

Monitors clipboard content (with user permission) for URLs and suspicious patterns. Triggered by the app coming to foreground.

```swift
// GemmaKit/Sources/MCP/ClipboardWatcherServer.swift
import UIKit

actor ClipboardWatcherServer: MCPServer {
    let name = "clipboard_watcher"

    let tools: [MCPToolDefinition] = [
        MCPToolDefinition(
            name: "get_clipboard_signals",
            description: "Get risk signals from current clipboard content without exposing raw content. Returns URL count, has_phone, text_length.",
            inputSchema: [:],
            outputSchema: ["url_count": .number, "has_phone": .boolean, "text_length": .number, "risk_signals": .string]
        ),
    ]

    func execute(tool: String, input: [String: String]) async throws -> [String: String] {
        guard tool == "get_clipboard_signals" else { throw MCPError.unknownTool(tool) }

        guard UIPasteboard.general.hasStrings,
              let content = UIPasteboard.general.string else {
            return ["url_count": "0", "has_phone": "false", "text_length": "0", "risk_signals": "empty"]
        }

        let urlDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let phoneDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.phoneNumber.rawValue)

        let urlCount = urlDetector?.numberOfMatches(in: content, range: NSRange(content.startIndex..., in: content)) ?? 0
        let hasPhone = (phoneDetector?.numberOfMatches(in: content, range: NSRange(content.startIndex..., in: content)) ?? 0) > 0

        return [
            "url_count": "\(urlCount)",
            "has_phone": "\(hasPhone)",
            "text_length": "\(content.count)",
            "risk_signals": urlCount > 2 ? "many_urls" : hasPhone ? "phone_present" : "none"
        ]
    }
}
```

**Tool access:** Available to `orchestrator` only (called on app foreground, not during inference).

---

### 3.10 `screen_time` — Screen Time API Bridge

Reads Screen Time / Digital Wellbeing metrics (with permission) to provide context about app usage patterns. Used to detect if the user is under social engineering pressure (e.g., scammer insisting on immediate response).

```swift
// GemmaKit/Sources/MCP/ScreenTimeServer.swift
import ManagedSettings

actor ScreenTimeServer: MCPServer {
    let name = "screen_time"

    let tools: [MCPToolDefinition] = [
        MCPToolDefinition(
            name: "get_session_context",
            description: "Get anonymised session context: session duration, time of day, recent notification count. No app names or content exposed.",
            inputSchema: [:],
            outputSchema: ["session_duration_min": .number, "time_of_day": .string, "notification_pressure": .string]
        ),
    ]

    func execute(tool: String, input: [String: String]) async throws -> [String: String] {
        guard tool == "get_session_context" else { throw MCPError.unknownTool(tool) }

        let hour = Calendar.current.component(.hour, from: Date())
        let timeOfDay: String
        switch hour {
        case 0..<6:   timeOfDay = "late_night"
        case 6..<12:  timeOfDay = "morning"
        case 12..<18: timeOfDay = "afternoon"
        default:      timeOfDay = "evening"
        }

        // Session duration via ProcessInfo (no Screen Time API needed)
        let sessionDuration = Int(ProcessInfo.processInfo.systemUptime / 60)

        return [
            "session_duration_min": "\(min(sessionDuration, 999))",
            "time_of_day": timeOfDay,
            // TODO (post-hackathon): read actual notification count via Family Controls entitlement
            // (ManagedSettingsStore + AuthorizationCenter). Requires .familyControls capability in
            // entitlements and user consent. Until then, "unknown" is the safe fallback — agents
            // must treat "unknown" as a neutral signal (neither high nor low pressure).
            "notification_pressure": "unknown"
        ]
    }
}
```

**Tool access:** Available to `orchestrator` only.

---

## 4. Server Registration

All servers are registered at app startup in `AppDelegate` / the Capacitor plugin initialiser.

```swift
// ios/App/Plugins/GemmaPlugin.swift (continued from Spec 01)
extension GemmaPlugin {

    /// Called from `GemmaPlugin.load()` — the Capacitor lifecycle hook that fires
    /// immediately after the plugin is instantiated (before any JS calls).
    /// All servers must be registered before the first `analyse()` call.
    override public func load() {
        setupMCP()
        Task { try? await InferenceEngine.shared.warmUpE2B() }
    }

    func setupMCP() {
        let client = MCPClient.shared
        Task {
            await client.register(server: ScamPatternsServer())
            await client.register(server: SqliteVecServer())
            await client.register(server: ContactsServer())
            await client.register(server: URLReputationServer())
            await client.register(server: WhoisServer())
            await client.register(server: ReverseImageServer())
            await client.register(server: PhoneReputationServer())
            await client.register(server: MessageFilterServer())
            await client.register(server: ClipboardWatcherServer())
            await client.register(server: ScreenTimeServer())
            GemScanLogger.plugin.info("All 10 MCP servers registered")
        }
    }
}
```

---

## 5. Tool Access Control Matrix

| Tool | text-agent | url-agent | image-agent | voice-agent | judge-agent | orchestrator |
|---|---|---|---|---|---|---|
| `scam_patterns/match_patterns` | ✓ | — | — | — | ✓ | — |
| `scam_patterns/get_pattern_detail` | ✓ | — | — | — | ✓ | — |
| `sqlite_vec/semantic_search` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `sqlite_vec/store_embedding` | — | — | — | — | — | ✓ (post-confirm) |
| `contacts/is_known_sender` | ✓ | — | — | — | — | ✓ |
| `url_reputation/check_url` | ✓ | ✓ | ✓ | — | — | — |
| `whois/lookup` | — | ✓ | — | — | — | — |
| `reverse_image/extract_text_urls` | — | — | ✓ | — | — | — |
| `reverse_image/compute_phash` | — | — | ✓ | — | — | — |
| `phone_reputation/check` | ✓ | — | — | ✓ | — | — |
| `message_filter/check_sender_history` | ✓ | — | — | — | — | ✓ |
| `clipboard_watcher/get_clipboard_signals` | — | — | — | — | — | ✓ |
| `screen_time/get_session_context` | — | — | — | — | — | ✓ |

Access control is enforced at `MCPClient.call()` by checking the calling agent's `agentId` against a static allowlist.

---

## 6. Web Mock (TypeScript)

```typescript
// src/lib/mcp/mock-client.ts
import { logger } from '../logger'

type ToolInput = Record<string, string>
type ToolOutput = Record<string, string>

const mockResponses: Record<string, ToolOutput> = {
  'scam_patterns/match_patterns': { matched_patterns: '', risk_level: 'low', pattern_count: '0' },
  'sqlite_vec/semantic_search': { matches: '[]', top_similarity: '0.12' },
  'contacts/is_known_sender': { is_known: 'false', contact_count: '150' },
  'url_reputation/check_url': { risk_score: '0.15', blocklisted: 'false', signals: 'none' },
  'whois/lookup': { age_days: '1825', registrar: 'Namecheap', country: 'US', privacy_protected: 'false' },
  'reverse_image/extract_text_urls': { url_count: '0', urls: '', text_length: '0', has_qr: 'false' },
  'phone_reputation/check': { found_numbers: '0', max_risk_score: '0.00', report_count: '0' },
  'message_filter/check_sender_history': { previous_verdict: 'unknown', user_allowed: 'false', scan_count: '0' },
  'clipboard_watcher/get_clipboard_signals': { url_count: '0', has_phone: 'false', text_length: '0', risk_signals: 'none' },
  'screen_time/get_session_context': { session_duration_min: '5', time_of_day: 'morning', notification_pressure: 'low' },
}

export async function mockMCPCall(server: string, tool: string, input: ToolInput): Promise<ToolOutput> {
  const key = `${server}/${tool}`
  logger.info(`[MOCK] MCP ${key}`, { inputKeys: Object.keys(input) })
  await sleep(10 + Math.random() * 40)  // Simulate 10–50 ms
  return mockResponses[key] ?? { error: 'unknown_tool' }
}

const sleep = (ms: number) => new Promise(r => setTimeout(r, ms))
```

---

## 7. MCP Server Testing Checklist

- [ ] Each server's `execute()` returns valid output for all defined tools
- [ ] `MCPClient.call()` logs `ToolCallRecord` with `success: false` on server errors
- [ ] `contacts/is_known_sender` never exposes raw phone/email — only boolean (XCTest)
- [ ] `url_reputation/check_url` scores known-bad TLDs above 0.3
- [ ] `reverse_image/extract_text_urls` extracts at least one URL from a test phishing screenshot
- [ ] Tool access control: `url-agent` cannot call `contacts` (XCTest: expect rejection)
- [ ] All servers initialise without crash when permission is denied (graceful degradation)
- [ ] Web mock returns responses within 50 ms for all tools (Vitest)
