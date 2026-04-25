# Spec 03 — Agent System

---

## 1. Overview

GemScan's intelligence layer is a **six-agent system** built on Swift actors. Each agent owns a distinct analysis domain. The `OrchestratorAgent` receives every `AgentTask` and routes work to specialist agents, optionally escalating from E2B to E4B when confidence is low.

**No external network calls are made during inference.** All tool calls route through in-process MCP servers (Spec 04). The agent system is fully exercisable in web mock mode via golden fixtures.

---

## 2. Agent Roster

| Agent ID | Model tier | Handles | Escalates to E4B? |
|---|---|---|---|
| `orchestrator` | E4B (coordinator) | All task types; sub-delegates | Yes — self |
| `text-agent` | E2B | SMS, email, chat text | If confidence < threshold |
| `url-agent` | E2B | URL extraction + reputation | If domain is new/unknown |
| `image-agent` | E4B | Screenshots, QR, images | Always E4B |
| `voice-agent` | E4B + ASR | Near-end audio, CallKit pre-screen | Always E4B |
| `judge-agent` | E4B | Multi-signal adjudication (PhishDebate) | Always E4B |

---

## 3. Swift Actor Definitions (`GemmaKit/Sources/Agents/`)

### 3.0 Agent ID Constants

```swift
// GemmaKit/Sources/Agents/AgentIDs.swift
/// Canonical agent identifier strings. Used in AgentResult.agentId, MCPClient allowlist,
/// and all `callerAgentId` parameters. Each agent actor's `agentId` property MUST equal
/// the corresponding constant — tests enforce this.
enum AgentID {
    static let orchestrator = "orchestrator"
    static let textAgent    = "text-agent"
    static let urlAgent     = "url-agent"
    static let imageAgent   = "image-agent"
    static let voiceAgent   = "voice-agent"
    static let judgeAgent   = "judge-agent"
}
```

### 3.1 Base Protocol

```swift
// GemmaKit/Sources/Agents/AgentProtocol.swift
import Foundation

protocol GemScanAgent: Actor {
    var agentId: String { get }
    var logger: Logger { get }

    func handle(_ task: AgentTask) async throws -> AgentResult
    func canHandle(_ task: AgentTask) -> Bool
}

extension GemScanAgent {
    func makeResult(
        for task: AgentTask,
        verdict: ScamVerdict,
        confidence: Double,
        reasoning: [String],
        modelTier: ModelTier,
        escalated: Bool,
        toolCallsLog: [ToolCallRecord],
        latencyMs: Int
    ) -> AgentResult {
        AgentResult(
            taskId: task.id,
            agentId: agentId,
            verdict: verdict,
            confidence: confidence,
            reasoning: reasoning,
            language: task.payload.language ?? "en",
            toolCallsLog: toolCallsLog,
            latencyMs: latencyMs,
            modelTier: modelTier,
            escalatedToE4B: escalated
        )
    }
}
```

### 3.2 OrchestratorAgent

The orchestrator implements a **ReAct loop** (Reason → Act → Observe) with a maximum of 8 tool-call rounds per task. It selects specialist agents, merges partial results, and escalates to E4B when the E2B result is below `confidenceThreshold`.

```swift
// GemmaKit/Sources/Agents/OrchestratorAgent.swift
import Foundation
import os

actor OrchestratorAgent: GemScanAgent {
    static let shared = OrchestratorAgent()

    let agentId = AgentID.orchestrator
    let logger = Logger(subsystem: "com.gemscan", category: "OrchestratorAgent")

    private let inference: InferenceEngine
    private let router: MessageRouter
    private let confidenceThreshold: Double

    private init(
        inference: InferenceEngine = .shared,
        router: MessageRouter = .shared,
        confidenceThreshold: Double = 0.75
    ) {
        self.inference = inference
        self.router = router
        self.confidenceThreshold = confidenceThreshold
    }

    func canHandle(_ task: AgentTask) -> Bool { true }   // Orchestrator handles everything

    func handle(_ task: AgentTask) async throws -> AgentResult {
        let start = Date()
        logger.info("Orchestrator received task \(task.id) type=\(task.type.rawValue)")

        // 1. Route to specialist agent based on payload type
        let specialist = router.specialist(for: task)
        let draft = try await specialist.handle(task)

        logger.info("Draft verdict=\(draft.verdict.rawValue) confidence=\(draft.confidence, format: .fixed(precision: 2))")

        // 2. Escalate to E4B if confidence is low
        if draft.confidence < confidenceThreshold && !draft.escalatedToE4B {
            logger.warning("Escalating task \(task.id) to E4B (draft confidence \(draft.confidence))")
            return try await escalateToE4B(task: task, draft: draft, start: start)
        }

        // 3. If multi-modal or high-stakes, run PhishDebate adjudication
        if task.payload.isMultiModal || draft.verdict == .scam {
            return try await adjudicate(task: task, draft: draft, start: start)
        }

        return draft
    }

    // MARK: - Private

    private func escalateToE4B(task: AgentTask, draft: AgentResult, start: Date) async throws -> AgentResult {
        try await inference.loadE4BIfNeeded()
        let e4bTask = task.withModelTier(.e4b)
        let e4bResult = try await router.specialist(for: e4bTask).handle(e4bTask)
        return e4bResult.markingEscalated(latencyMs: Int(-start.timeIntervalSinceNow * 1000))
    }

    private func adjudicate(task: AgentTask, draft: AgentResult, start: Date) async throws -> AgentResult {
        let judgeAgent = router.judgeAgent
        // Wrap the original payload and draft result together so JudgeAgent sees both
        // the full message context and the prior analysis in a single AgentTask.
        let judgeTask = AgentTask(
            id: task.id,
            type: .explainVerdict,
            payload: .multimodal(
                parts: [task.payload],
                priorResult: draft
            ),
            priority: task.priority,
            createdAt: task.createdAt,
            timeoutMs: task.timeoutMs
        )
        return try await judgeAgent.handle(judgeTask)
    }
}
```

### 3.3 TextAgent

Handles SMS, email, and chat message classification using E2B with the `classifySMS`/`classifyEmail` GBNF grammar.

```swift
// GemmaKit/Sources/Agents/TextAgent.swift
actor TextAgent: GemScanAgent {
    let agentId = AgentID.textAgent
    let logger = Logger(subsystem: "com.gemscan", category: "TextAgent")

    private let inference: InferenceEngine
    private let mcpClient: MCPClient

    init(inference: InferenceEngine = .shared, mcpClient: MCPClient = .shared) {
        self.inference = inference
        self.mcpClient = mcpClient
    }

    func canHandle(_ task: AgentTask) -> Bool {
        task.type == .classifySMS || task.type == .classifyEmail
    }

    func handle(_ task: AgentTask) async throws -> AgentResult {
        let start = Date()
        guard case .text(let content, let language) = task.payload else {
            throw GemScanError.grammarViolation(raw: "TextAgent received non-text payload")
        }

        // 1. Fast triage via DistilBERT
        let triage = try await SMSTriage.shared.classify(text: content)
        logger.debug("DistilBERT triage: \(triage.label) p=\(triage.confidence)")

        if triage.label == .safe && triage.confidence > 0.95 {
            // Very high-confidence safe — skip LLM
            return makeResult(
                for: task, verdict: .safe, confidence: triage.confidence,
                reasoning: ["Message matches known-safe pattern (fast triage)."],
                modelTier: .distilbert, escalated: false, toolCallsLog: [], latencyMs: Int(-start.timeIntervalSinceNow * 1000)
            )
        }

        // 2. Build ReAct prompt
        var toolCallsLog: [ToolCallRecord] = []
        let prompt = TextAgentPrompts.reactPrompt(content: content, language: language, triageLabel: triage.label)

        // 3. Run LLM with grammar-constrained output
        let rawOutput = try await inference.generate(
            prompt: prompt,
            grammar: GrammarConstraint.textAgentGrammar,
            modelTier: .e2b,
            task: task
        )

        // 4. Parse structured output
        let parsed = try TextAgentOutput.parse(rawOutput)
        toolCallsLog += parsed.toolCalls

        // 5. Execute any tool calls the model requested
        for toolCall in parsed.toolCalls {
            let result = try await mcpClient.call(tool: toolCall, callerAgentId: AgentID.textAgent)
            toolCallsLog.append(result.record)
        }

        return makeResult(
            for: task,
            verdict: parsed.verdict,
            confidence: parsed.confidence,
            reasoning: parsed.reasoning,
            modelTier: .e2b,
            escalated: false,
            toolCallsLog: toolCallsLog,
            latencyMs: Int(-start.timeIntervalSinceNow * 1000)
        )
    }
}
```

### 3.4 URLAgent

```swift
// GemmaKit/Sources/Agents/URLAgent.swift
actor URLAgent: GemScanAgent {
    let agentId = AgentID.urlAgent
    let logger = Logger(subsystem: "com.gemscan", category: "URLAgent")

    private let inference: InferenceEngine
    private let mcpClient: MCPClient

    func canHandle(_ task: AgentTask) -> Bool { task.type == .checkURL }

    func handle(_ task: AgentTask) async throws -> AgentResult {
        let start = Date()
        guard case .url(let urlString) = task.payload else {
            throw GemScanError.grammarViolation(raw: "URLAgent received non-URL payload")
        }

        var toolCallsLog: [ToolCallRecord] = []

        // Parallel: url_reputation + whois lookups
        async let reputationResult = mcpClient.call(server: "url_reputation", tool: "check_url", input: ["url": urlString], callerAgentId: AgentID.urlAgent)
        async let whoisResult = mcpClient.call(server: "whois", tool: "lookup", input: ["domain": extractDomain(urlString)], callerAgentId: AgentID.urlAgent)

        let (reputation, whois) = try await (reputationResult, whoisResult)
        toolCallsLog += [reputation.record, whois.record]

        let prompt = URLAgentPrompts.reactPrompt(url: urlString, reputation: reputation.output, whois: whois.output)
        let rawOutput = try await inference.generate(
            prompt: prompt,
            grammar: GrammarConstraint.urlAgentGrammar,
            modelTier: .e2b,
            task: task
        )

        let parsed = try URLAgentOutput.parse(rawOutput)
        return makeResult(
            for: task, verdict: parsed.verdict, confidence: parsed.confidence,
            reasoning: parsed.reasoning, modelTier: .e2b, escalated: false,
            toolCallsLog: toolCallsLog, latencyMs: Int(-start.timeIntervalSinceNow * 1000)
        )
    }

    private func extractDomain(_ urlString: String) -> String {
        URL(string: urlString)?.host ?? urlString
    }
}
```

### 3.5 ImageAgent

```swift
// GemmaKit/Sources/Agents/ImageAgent.swift
actor ImageAgent: GemScanAgent {
    let agentId = AgentID.imageAgent
    let logger = Logger(subsystem: "com.gemscan", category: "ImageAgent")

    private let inference: InferenceEngine
    private let mcpClient: MCPClient

    func canHandle(_ task: AgentTask) -> Bool { task.type == .analyseScreenshot }

    func handle(_ task: AgentTask) async throws -> AgentResult {
        let start = Date()
        guard case .image(let base64, let mimeType) = task.payload else {
            throw GemScanError.grammarViolation(raw: "ImageAgent received non-image payload")
        }

        // E4B required for vision (multimodal token processing)
        try await inference.loadE4BIfNeeded()

        var toolCallsLog: [ToolCallRecord] = []

        // Extract URLs from image via reverse_image MCP (OCR pass)
        let ocrResult = try await mcpClient.call(server: "reverse_image", tool: "extract_text_urls", input: ["base64": base64], callerAgentId: AgentID.imageAgent)
        toolCallsLog.append(ocrResult.record)

        let prompt = ImageAgentPrompts.visionPrompt(mimeType: mimeType, ocrText: ocrResult.output)
        let rawOutput = try await inference.generateVision(
            imageBase64: base64,
            textPrompt: prompt,
            grammar: GrammarConstraint.imageAgentGrammar,
            task: task
        )

        let parsed = try ImageAgentOutput.parse(rawOutput)
        return makeResult(
            for: task, verdict: parsed.verdict, confidence: parsed.confidence,
            reasoning: parsed.reasoning, modelTier: .e4b, escalated: true,
            toolCallsLog: toolCallsLog, latencyMs: Int(-start.timeIntervalSinceNow * 1000)
        )
    }
}
```

### 3.6 VoiceAgent

Audio analysis is subject to strict iOS platform constraints (see Spec 05 §4). The VoiceAgent operates in three sanctioned modes: post-call near-end audio, CallKit pre-answer screening, and user-initiated share.

```swift
// GemmaKit/Sources/Agents/VoiceAgent.swift
actor VoiceAgent: GemScanAgent {
    let agentId = AgentID.voiceAgent
    let logger = Logger(subsystem: "com.gemscan", category: "VoiceAgent")

    private let inference: InferenceEngine
    private let asr: WhisperASR      // On-device Whisper (distilled, MLX)
    private let mcpClient: MCPClient

    func canHandle(_ task: AgentTask) -> Bool { task.type == .scoreVoice }

    func handle(_ task: AgentTask) async throws -> AgentResult {
        let start = Date()
        // Audio payload encoding contract:
        // - Format:      AAC (MPEG-4 Audio, .m4a container)
        // - Sample rate: 16 000 Hz mono (required by WhisperASR and AudioSealDetector)
        // - Max duration: 300 seconds; recordings longer than this are rejected
        // - base64:      Standard base64 (RFC 4648) of the raw AAC byte stream
        guard case .audio(let base64, let durationSeconds) = task.payload else {
            throw GemScanError.grammarViolation(raw: "VoiceAgent received non-audio payload")
        }

        try await inference.loadE4BIfNeeded()

        var toolCallsLog: [ToolCallRecord] = []

        // 1. ASR transcription (on-device Whisper)
        let transcript = try await asr.transcribe(base64Audio: base64, durationSeconds: durationSeconds)
        logger.info("ASR: \(transcript.language) \(transcript.text.prefix(20))…")

        // 2. AudioSeal deepfake detection (MLX on-device)
        let deepfakeScore = try await checkDeepfake(base64: base64)

        // 3. Phone reputation lookup
        let phoneResult = try await mcpClient.call(server: "phone_reputation", tool: "check", input: ["transcript_excerpt": String(transcript.text.prefix(100))], callerAgentId: AgentID.voiceAgent)
        toolCallsLog.append(phoneResult.record)

        // 4. LLM analysis with transcript + signals
        let prompt = VoiceAgentPrompts.reactPrompt(
            transcript: transcript.text,
            language: transcript.language,
            deepfakeScore: deepfakeScore,
            phoneReputation: phoneResult.output,
            durationSeconds: durationSeconds
        )
        let rawOutput = try await inference.generate(
            prompt: prompt,
            grammar: GrammarConstraint.voiceAgentGrammar,
            modelTier: .e4b,
            task: task
        )

        let parsed = try VoiceAgentOutput.parse(rawOutput)
        return makeResult(
            for: task, verdict: parsed.verdict, confidence: parsed.confidence,
            reasoning: parsed.reasoning, modelTier: .e4b, escalated: true,
            toolCallsLog: toolCallsLog, latencyMs: Int(-start.timeIntervalSinceNow * 1000)
        )
    }

    private func checkDeepfake(base64: String) async throws -> Double {
        // AudioSeal model — runs on-device, returns probability that audio is AI-synthesized
        // Returns 0.0 (human) to 1.0 (AI-generated)
        return try await AudioSealDetector.shared.score(base64Audio: base64)
    }
}
```

### 3.7 JudgeAgent — PhishDebate Pattern

The JudgeAgent implements the **PhishDebate** adversarial adjudication: it generates a "defence counsel" argument for the message being legitimate, then rebuts it from a "prosecution" perspective, then renders a final verdict.

```swift
// GemmaKit/Sources/Agents/JudgeAgent.swift
actor JudgeAgent: GemScanAgent {
    let agentId = AgentID.judgeAgent
    let logger = Logger(subsystem: "com.gemscan", category: "JudgeAgent")

    private let inference: InferenceEngine

    func canHandle(_ task: AgentTask) -> Bool { task.type == .explainVerdict }

    func handle(_ task: AgentTask) async throws -> AgentResult {
        let start = Date()
        try await inference.loadE4BIfNeeded()

        // PhishDebate: 3-pass adjudication
        let defenceArgument = try await generateDefence(task: task)
        logger.debug("Defence: \(defenceArgument.prefix(80))…")

        let prosecutionRebuttal = try await generateRebuttal(task: task, defence: defenceArgument)
        logger.debug("Prosecution: \(prosecutionRebuttal.prefix(80))…")

        let finalVerdict = try await renderVerdict(task: task, defence: defenceArgument, prosecution: prosecutionRebuttal)

        return makeResult(
            for: task,
            verdict: finalVerdict.verdict,
            confidence: finalVerdict.confidence,
            reasoning: finalVerdict.reasoning,
            modelTier: .e4b,
            escalated: true,
            toolCallsLog: [],
            latencyMs: Int(-start.timeIntervalSinceNow * 1000)
        )
    }

    private func generateDefence(task: AgentTask) async throws -> String {
        let prompt = JudgeAgentPrompts.defencePrompt(task: task)
        return try await inference.generate(prompt: prompt, grammar: GrammarConstraint.plainText, modelTier: .e4b, task: task)
    }

    private func generateRebuttal(task: AgentTask, defence: String) async throws -> String {
        let prompt = JudgeAgentPrompts.rebuttalPrompt(task: task, defence: defence)
        return try await inference.generate(prompt: prompt, grammar: GrammarConstraint.plainText, modelTier: .e4b, task: task)
    }

    private func renderVerdict(task: AgentTask, defence: String, prosecution: String) async throws -> ParsedVerdict {
        let prompt = JudgeAgentPrompts.verdictPrompt(task: task, defence: defence, prosecution: prosecution)
        let raw = try await inference.generate(prompt: prompt, grammar: GrammarConstraint.verdictGrammar, modelTier: .e4b, task: task)
        return try ParsedVerdict.parse(raw)
    }
}
```

---

## 3.8 MCP Tool Failure Recovery Contract

When `MCPClient.call()` throws or returns a `MCPToolResult` with `success: false`, agents follow this policy:

| Scenario | Agent Behaviour |
|---|---|
| Access denied (`MCPError.accessDenied`) | Re-throw immediately — this is a programming error, not a runtime failure. |
| Unknown server / tool | Re-throw immediately — missing tool is a configuration error. |
| Server-side execution error (`success: false`) | Log the error, treat the tool result as absent (empty output), and continue generation. The `ToolCallRecord` is still appended to `toolCallsLog` for post-mortem review. |
| Timeout (task-level, via `MessageRouter.dispatch`) | The entire agent task is cancelled; `GemScanError.inferenceTimeout` propagates to the orchestrator, which returns a conservative `suspicious` verdict. |
| Network error in `url_reputation` or `phone_reputation` | Treat as `success: false` (offline fallback) — agents must not block on network. |

**Agents must not retry failed MCP calls** — retry logic belongs in the MCP server layer (e.g., URL reputation server may internally retry with exponential backoff). From the agent's perspective, the call either succeeds or it doesn't.

**No tool call is mandatory for verdict generation.** Agents produce a verdict from LLM output alone if all tool calls fail. Confidence is typically lower (logged as `toolCallsLog` with `success: false` entries), which may trigger E4B escalation by the orchestrator.

---

## 4. Platform-Native Message Router

The `MessageRouter` eliminates the A2A bus in favour of direct Swift actor messaging. It maintains a registry of active agents and dispatches tasks based on payload type.

```swift
// GemmaKit/Sources/Router/MessageRouter.swift
import Foundation
import os

actor MessageRouter {
    static let shared = MessageRouter()

    let logger = Logger(subsystem: "com.gemscan", category: "MessageRouter")

    // Agent singletons — created once at router init, reused for all tasks.
    // Each agent is a Swift actor, so concurrent calls are serialised internally.
    // The router holds strong references; agents hold weak references back to
    // shared singletons (InferenceEngine.shared, MCPClient.shared) to avoid cycles.
    private let textAgent  = TextAgent()
    private let urlAgent   = URLAgent()
    private let imageAgent = ImageAgent()
    private let voiceAgent = VoiceAgent()
    private let judgeAgent_ = JudgeAgent()

    var judgeAgent: JudgeAgent { judgeAgent_ }

    /// Select the right specialist for a given task.
    func specialist(for task: AgentTask) -> any GemScanAgent {
        switch task.type {
        case .classifySMS, .classifyEmail:
            return textAgent
        case .checkURL:
            return urlAgent
        case .analyseScreenshot:
            return imageAgent
        case .scoreVoice:
            return voiceAgent
        case .explainVerdict:
            return judgeAgent_
        }
    }

    /// Dispatch with timeout enforcement.
    func dispatch(_ task: AgentTask) async throws -> AgentResult {
        logger.info("Dispatching task \(task.id) type=\(task.type.rawValue) timeout=\(task.timeoutMs)ms")

        return try await withThrowingTaskGroup(of: AgentResult.self) { group in
            group.addTask {
                let agent = self.specialist(for: task)
                return try await agent.handle(task)
            }

            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(task.timeoutMs) * 1_000_000)
                throw GemScanError.inferenceTimeout(taskId: task.id, limitMs: task.timeoutMs)
            }

            guard let result = try await group.next() else {
                throw GemScanError.inferenceTimeout(taskId: task.id, limitMs: task.timeoutMs)
            }
            group.cancelAll()
            return result
        }
    }
}
```

---

## 5. GBNF Grammars

Each agent uses a **GBNF grammar** to constrain LLM output to valid JSON. This prevents hallucinated fields or malformed tool-call invocations from reaching downstream code.

### 5.1 Text / URL Agent Grammar

```swift
// GemmaKit/Sources/Agents/Grammars/GrammarConstraint.swift

/// Pre-built GBNF grammar strings for each agent's expected JSON output.
/// These are passed to `LlamaCppInferenceBackend` to constrain decoding,
/// and to `GrammarValidator.validate()` to check MLX outputs post-hoc.
enum GrammarConstraint {

    /// Text and URL agents: verdict + confidence + reasoning + optional tool calls
    static let textAgentGrammar = """
    root   ::= "{" ws verdict-field "," ws confidence-field "," ws reasoning-field "," ws tool-calls-field ws "}"
    verdict-field  ::= "\\"verdict\\":" ws verdict-value
    verdict-value  ::= "\\"safe\\"" | "\\"suspicious\\"" | "\\"scam\\""
    confidence-field ::= "\\"confidence\\":" ws number
    reasoning-field  ::= "\\"reasoning\\":" ws string-array
    tool-calls-field ::= "\\"toolCalls\\":" ws tool-call-array
    tool-call-array  ::= "[]" | "[" ws tool-call ("," ws tool-call)* ws "]"
    tool-call ::= "{" ws "\\"server\\":" ws string "," ws "\\"tool\\":" ws string "," ws "\\"input\\":" ws json-object ws "}"
    string-array ::= "[]" | "[" ws string ("," ws string)* ws "]"
    number ::= [0-9]+ "." [0-9]+
    string ::= "\\"" ([^\\\\"] | "\\\\" .)* "\\""
    json-object ::= "{" ws (json-pair ("," ws json-pair)*)? ws "}"
    json-pair ::= string ":" ws string
    ws ::= [ \\t\\n]*
    """

    static let urlAgentGrammar   = textAgentGrammar
    static let imageAgentGrammar = textAgentGrammar

    static let voiceAgentGrammar = """
    root ::= "{" ws verdict-field "," ws confidence-field "," ws reasoning-field "," ws deepfake-field ws "}"
    verdict-field    ::= "\\"verdict\\":" ws verdict-value
    verdict-value    ::= "\\"safe\\"" | "\\"suspicious\\"" | "\\"scam\\""
    confidence-field ::= "\\"confidence\\":" ws number
    reasoning-field  ::= "\\"reasoning\\":" ws string-array
    deepfake-field   ::= "\\"deepfakeProbability\\":" ws number
    string-array     ::= "[" ws string ("," ws string)* ws "]"
    number           ::= [0-9]+ "." [0-9]+
    string           ::= "\\"" ([^\\\\"] | "\\\\" .)* "\\""
    ws               ::= [ \\t\\n]*
    """

    static let verdictGrammar = textAgentGrammar
    static let plainText      = ""    // No constraint — free-form generation for PhishDebate passes
}

// MARK: - Grammar Validation (post-hoc check for MLX outputs)

/// Validates that a string output conforms to a GBNF grammar by attempting
/// to parse it as the expected JSON structure. This is used for MLX (which
/// does not natively support GBNF) — llama.cpp enforces grammar at sampling time.
enum GrammarValidator {

    enum GrammarError: Error {
        case malformedJSON(String)
        case missingField(String)
        case invalidVerdictValue(String)
        case confidenceOutOfRange(Double)
    }

    /// Validates that `output` is valid JSON conforming to the agent verdict schema.
    /// Throws `GemScanError.grammarViolation(raw:)` on any violation.
    static func validate(output: String, against grammar: String) throws {
        guard !grammar.isEmpty else { return }   // plainText — no validation

        guard let data = output.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw GemScanError.grammarViolation(raw: "Output is not valid JSON: \(output.prefix(100))")
        }

        guard let verdict = json["verdict"] as? String else {
            throw GemScanError.grammarViolation(raw: "Missing 'verdict' field")
        }
        guard ["safe", "suspicious", "scam"].contains(verdict) else {
            throw GemScanError.grammarViolation(raw: "Invalid verdict value: \(verdict)")
        }
        guard let confidence = json["confidence"] as? Double else {
            throw GemScanError.grammarViolation(raw: "Missing or non-numeric 'confidence' field")
        }
        guard (0.0...1.0).contains(confidence) else {
            throw GemScanError.grammarViolation(raw: "Confidence \(confidence) out of range [0,1]")
        }
        guard json["reasoning"] is [String] else {
            throw GemScanError.grammarViolation(raw: "Missing or non-array 'reasoning' field")
        }
    }
}
```

## 5.2 Agent Output Types

Each agent parses its grammar-constrained JSON output into a typed struct. These structs are internal to GemmaKit.

```swift
// GemmaKit/Sources/Agents/AgentOutputTypes.swift

// Shared parsed verdict used by TextAgent, URLAgent, ImageAgent, and JudgeAgent
struct ParsedVerdict {
    let verdict: ScamVerdict
    let confidence: Double
    let reasoning: [String]
    let toolCalls: [RawToolCall]

    static func parse(_ rawOutput: String) throws -> ParsedVerdict {
        try GrammarValidator.validate(output: rawOutput, against: GrammarConstraint.textAgentGrammar)
        let data = rawOutput.data(using: .utf8)!
        let json = try JSONDecoder().decode(VerdictJSON.self, from: data)
        return ParsedVerdict(
            verdict: json.verdict,
            confidence: json.confidence,
            reasoning: json.reasoning,
            toolCalls: json.toolCalls ?? []
        )
    }

    private struct VerdictJSON: Decodable {
        let verdict: ScamVerdict
        let confidence: Double
        let reasoning: [String]
        let toolCalls: [RawToolCall]?
        enum CodingKeys: String, CodingKey { case verdict, confidence, reasoning, toolCalls }
    }
}

// Alias types — all agents use ParsedVerdict internally
typealias TextAgentOutput  = ParsedVerdict
typealias URLAgentOutput   = ParsedVerdict
typealias ImageAgentOutput = ParsedVerdict

struct VoiceAgentOutput {
    let verdict: ScamVerdict
    let confidence: Double
    let reasoning: [String]
    let deepfakeProbability: Double

    static func parse(_ rawOutput: String) throws -> VoiceAgentOutput {
        try GrammarValidator.validate(output: rawOutput, against: GrammarConstraint.voiceAgentGrammar)
        let data = rawOutput.data(using: .utf8)!
        let json = try JSONDecoder().decode(VoiceJSON.self, from: data)
        return VoiceAgentOutput(
            verdict: json.verdict,
            confidence: json.confidence,
            reasoning: json.reasoning,
            deepfakeProbability: json.deepfakeProbability
        )
    }

    private struct VoiceJSON: Decodable {
        let verdict: ScamVerdict
        let confidence: Double
        let reasoning: [String]
        let deepfakeProbability: Double
    }
}

struct RawToolCall: Decodable {
    let server: String
    let tool: String
    let input: [String: String]
}
```

---

## 6. Prompt Templates

### 6.1 TextAgent Prompt Structure

```swift
// GemmaKit/Sources/Agents/Prompts/TextAgentPrompts.swift
enum TextAgentPrompts {
    static func reactPrompt(content: String, language: String?, triageLabel: TriageLabel) -> String {
        """
        <bos><start_of_turn>system
        You are GemScan, an on-device scam detection assistant. \
        Your task is to classify a message as 'safe', 'suspicious', or 'scam'. \
        Use the available tools if needed, then output a JSON verdict.

        Rules:
        - Reasoning must be in \(language ?? "the same language as the message").
        - Use sixth-grade reading level.
        - Provide 2–3 bullet points in the reasoning array.
        - Do not include any PII in reasoning (no phone numbers, names, or message content verbatim).
        - Fast triage pre-classification: \(triageLabel.rawValue)
        <end_of_turn>
        <start_of_turn>user
        Message to classify:
        ---
        [MESSAGE REDACTED FOR PRIVACY — \(content.count) characters]
        ---
        Analyse this message. If you need to check URLs or sender reputation, call the appropriate tool. \
        Output your final verdict as JSON.
        <end_of_turn>
        <start_of_turn>model
        """
    }
}
```

> **Privacy note:** The actual message content is passed as a separate context variable that is never logged or stored. The prompt template shown here uses a placeholder for illustration. The real implementation passes `content` directly to the inference engine's context buffer, which is zero-filled after the call.

### 6.2 JudgeAgent Prompt Templates

```swift
// GemmaKit/Sources/Agents/Prompts/JudgeAgentPrompts.swift
enum JudgeAgentPrompts {
    static func defencePrompt(task: AgentTask) -> String {
        """
        <bos><start_of_turn>system
        You are defence counsel in a scam detection review. \
        Argue the strongest possible case that this message is LEGITIMATE. \
        Be thorough — consider cultural context, common legitimate use cases, and false-positive risk.
        <end_of_turn>
        <start_of_turn>user
        Review the message payload (type: \(task.type.rawValue)). \
        Produce a 2–4 sentence argument that this is NOT a scam.
        <end_of_turn>
        <start_of_turn>model
        """
    }

    static func rebuttalPrompt(task: AgentTask, defence: String) -> String {
        """
        <bos><start_of_turn>system
        You are a prosecution expert in scam detection. \
        A defence argument has been made for this message. Rebut it with evidence.
        <end_of_turn>
        <start_of_turn>user
        Defence argument: \(defence)

        Rebut this argument. Identify specific red flags that the defence overlooks. \
        2–4 sentences.
        <end_of_turn>
        <start_of_turn>model
        """
    }

    static func verdictPrompt(task: AgentTask, defence: String, prosecution: String) -> String {
        """
        <bos><start_of_turn>system
        You are the final arbiter in a scam detection review. \
        Weigh both sides and render a JSON verdict.
        <end_of_turn>
        <start_of_turn>user
        Defence: \(defence)
        Prosecution: \(prosecution)

        Render your final verdict as JSON with keys: verdict, confidence, reasoning, toolCalls.
        <end_of_turn>
        <start_of_turn>model
        """
    }
}
```

---

## 7. ExplainerAgent Output Spec

The `JudgeAgent`'s `reasoning` array is the end-user-visible explanation. It must conform to:

| Requirement | Detail |
|---|---|
| Reading level | US sixth grade (Flesch-Kincaid ≤ 70) |
| Length | 2–3 bullet strings per result |
| Language | Must match `AgentResult.language` (BCP-47); in user's preferred language |
| PII | Zero — no phone numbers, contact names, message fragments, URLs verbatim |
| Tone | Calm, factual, non-alarmist. Use "recommend" not "must" or "danger" |
| Formatting | Plain strings (no markdown) — the UI component handles visual formatting |

### Culturally-Aware Localisation

The reasoning prompt instructs the model to respond in `task.payload.language` or the user's `preferredLanguage` from the Zustand store. The app passes this as a system prompt instruction:

```swift
"Respond in \(userPreferredLanguage). Use culturally appropriate phrasing for \(userPreferredLanguage) speakers."
```

Supported languages for Day 1: English (`en`), Hindi (`hi`), Japanese (`ja`), Spanish (`es`), Mandarin (`zh`). The model (Gemma 4) natively handles all five.

---

## 8. Web Mock (TypeScript)

The web mock simulates the full agent pipeline for browser-based development.

```typescript
// src/lib/agents/mock-orchestrator.ts
import type { AgentTask, AgentResult } from '../gemma/types'
import { goldenFixtures } from '../gemma/__fixtures__/golden'
import { logger } from '../logger'

export async function mockOrchestrate(task: AgentTask): Promise<AgentResult> {
  logger.info('[MOCK] OrchestratorAgent.handle', { taskId: task.id, type: task.type })

  // Simulate 300–800 ms latency
  await sleep(300 + Math.random() * 500)

  const fixture = goldenFixtures[task.id] ?? goldenFixtures['default']
  return {
    ...fixture,
    taskId: task.id,
    latencyMs: 300 + Math.floor(Math.random() * 500),
  }
}

const sleep = (ms: number) => new Promise(r => setTimeout(r, ms))
```

---

## 9. Agent System Testing Checklist

- [ ] `OrchestratorAgent` escalates to E4B when `draft.confidence < 0.75`
- [ ] `OrchestratorAgent` runs PhishDebate for `verdict === 'scam'`
- [ ] `TextAgent` skips LLM when DistilBERT confidence > 0.95 (safe)
- [ ] `URLAgent` makes parallel tool calls to `url_reputation` and `whois`
- [ ] `VoiceAgent` runs AudioSeal deepfake check before LLM
- [ ] `JudgeAgent` completes 3-pass PhishDebate and outputs valid JSON
- [ ] `MessageRouter.dispatch` throws `inferenceTimeout` if agent exceeds `timeoutMs`
- [ ] GBNF grammar rejects malformed LLM output (XCTest: feed garbage, expect `grammarViolation`)
- [ ] All agents return valid `AgentResult` for golden fixture inputs
