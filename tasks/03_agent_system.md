# Tasks — Six-Agent System

> **Spec:** `specs/03_agent_system.md` | **Milestone:** M3 — Six-Agent System | **Depends on:** M0, M2

## Milestone Summary
Implement the six-agent analysis pipeline — Orchestrator, Text, URL, Image, Voice, and Judge agents — on top of the `InferenceEngine` (M2) and `MCPClient` (M4). Agents communicate via `MessageRouter.shared`, are constrained by GBNF grammars, and follow the ReAct loop pattern (observe → think → act → respond). The Orchestrator manages confidence-based escalation to the larger E4B model. MCPClient must exist before end-to-end testing, but all agents can be scaffolded independently first.

## Prerequisites
- M0 complete: `GemScanError`, `AgentTask`, `AgentResult`, `Verdict`, `TriageResult`, `TriageLabel` types defined
- M2 complete: `InferenceEngine.shared`, `InferenceEngine.shared.isMLXAvailable`, `InferenceEngine.shared.generate(...)`, `InferenceEngine.shared.generateVision(imageBase64:textPrompt:...)`, `SMSTriage.shared.classify(text:)`, `WhisperASR.shared.transcribe(base64Audio:durationSeconds:)`, `AudioSealDetector.shared.score(base64Audio:)`, `ModelLoader` in place
- M4 scaffolded (at minimum): `MCPClient.shared`, `MCPClient.call(server:tool:input:callerAgentId:)`, `MCPError.accessDenied` defined

## Progress Tracker
| Status | Count |
|--------|-------|
| ✅ Done | 0 |
| 🔄 In progress | 0 |
| ⬜ Not started | 18 |

---
## Tasks

#### ⬜ T-03-001 · SCAFFOLD · P0 — AgentID constants + MessageRouter protocol

| Field | Value |
|---|---|
| **Type** | SCAFFOLD |
| **Priority** | P0 |
| **Spec ref** | §2.1 — Agent identifiers and message routing |
| **Depends on** | None |
| **Estimated effort** | S |
| **Files to create/modify** | `ios/App/GemmaKit/Sources/Agents/AgentID.swift`, `ios/App/GemmaKit/Sources/Router/MessageRouter.swift` |

**What to build:**
Create `ios/App/GemmaKit/Sources/Agents/AgentID.swift` defining `enum AgentID: String` with six cases: `.orchestrator = "orchestrator"`, `.textAgent = "text-agent"`, `.urlAgent = "url-agent"`, `.imageAgent = "image-agent"`, `.voiceAgent = "voice-agent"`, `.judgeAgent = "judge-agent"`. Create `ios/App/GemmaKit/Sources/Router/MessageRouter.swift` as `actor MessageRouter` with `static let shared = MessageRouter()` and a single public method `func dispatch(_ task: AgentTask) async throws -> AgentResult`. The `dispatch` method must wrap the inner agent `handle` call with `withTimeout(task.timeoutMs)`, throwing `GemScanError.inferenceTimeout` on expiry. The router selects the target agent by inspecting `task.type` and delegating to the appropriate agent singleton.

**Acceptance criteria:**
- [ ] `AgentID.allCases` contains exactly six values matching the string literals above
- [ ] `MessageRouter.shared.dispatch(task)` compiles and routes to the correct agent based on `task.type`
- [ ] `withTimeout(task.timeoutMs)` wraps every agent call — confirmed by unit test that a 1 ms timeout on a slow mock agent throws `GemScanError.inferenceTimeout`
- [ ] `actor MessageRouter` compiles without warnings under `SWIFT_STRICT_CONCURRENCY=complete`

**Apple compliance (Spec 00 §11):**
- [ ] §11.7 — PR checklist item: actor isolation verified, no sendability violations

---

#### ⬜ T-03-002 · IMPLEMENT · P0 — OrchestratorAgent

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P0 |
| **Spec ref** | §2.2 — OrchestratorAgent routing and escalation |
| **Depends on** | T-03-001 |
| **Estimated effort** | M |
| **Files to create/modify** | `ios/App/GemmaKit/Sources/Agents/OrchestratorAgent.swift` |

**What to build:**
Create `ios/App/GemmaKit/Sources/Agents/OrchestratorAgent.swift` as `actor OrchestratorAgent` with `static let shared = OrchestratorAgent()`. Implement `func handle(_ task: AgentTask) async throws -> AgentResult` that routes `task.type` to the appropriate specialist agent singleton (`TextAgent.shared`, `URLAgent.shared`, `ImageAgent.shared`, `VoiceAgent.shared`, `JudgeAgent.shared`). After receiving the draft `AgentResult`, if `result.confidence < 0.75`, reload the E4B model via `InferenceEngine.shared.loadE4B()` and re-run the same specialist agent — use the second result regardless of confidence. Before dispatching any task of type `analyseScreenshot`, check `InferenceEngine.shared.isMLXAvailable`; if false, throw `GemScanError.grammarViolation` immediately without calling the agent. After any result with `confidence >= 0.75`, call `MCPClient.shared.call(server: "sqlite_vec", tool: "store_embedding", input: embeddingInput, callerAgentId: AgentID.orchestrator)` to persist the embedding for future semantic search.

**Acceptance criteria:**
- [ ] Tasks with `type == .analyseScreenshot` and `isMLXAvailable == false` throw `GemScanError.grammarViolation` without calling `ImageAgent`
- [ ] Draft result with `confidence == 0.74` triggers E4B reload and re-runs the specialist; draft with `confidence == 0.75` does not
- [ ] High-confidence verdicts (`confidence >= 0.75`) result in exactly one `MCPClient.call` with `server: "sqlite_vec"`, `tool: "store_embedding"`, `callerAgentId: AgentID.orchestrator`
- [ ] All routing paths compile under `SWIFT_STRICT_CONCURRENCY=complete`

**Apple compliance (Spec 00 §11):**
- [ ] §11.7 — PR checklist item: no data races confirmed via TSan

---

#### ⬜ T-03-003 · IMPLEMENT · P0 — TextAgent

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P0 |
| **Spec ref** | §2.3 — TextAgent fast-path and slow-path |
| **Depends on** | T-03-001, T-03-008, T-03-009, T-03-011 |
| **Estimated effort** | M |
| **Files to create/modify** | `ios/App/GemmaKit/Sources/Agents/TextAgent.swift` |

**What to build:**
Create `ios/App/GemmaKit/Sources/Agents/TextAgent.swift` as `actor TextAgent` with `static let shared = TextAgent()` and `let agentId = AgentID.textAgent`. Implement `func handle(_ task: AgentTask) async throws -> AgentResult`. Fast-path: call `SMSTriage.shared.classify(text: task.content)` — if `result.label == .safe && result.confidence > 0.90`, return an `AgentResult` immediately without invoking the LLM. Slow-path: build the prompt via `TextAgentPrompts.reactPrompt(content: task.content, language: task.language)`, call `InferenceEngine.shared.generate(prompt:grammar:)` passing `GrammarConstraint.textAgentGrammar`, then parse the output with `ParsedVerdict.parse(from:grammar:)`. Within the ReAct loop, call the following MCP tools (all passing `callerAgentId: AgentID.textAgent`): `scam_patterns/match_patterns`, `sqlite_vec/semantic_search`, `contacts/is_known_sender`, `url_reputation/check_url`, `phone_reputation/check`, `message_filter/check_sender_history`. Note: `TriageResult.senderHash` is `""` on this path by design — no sender context is available in the main app.

**Acceptance criteria:**
- [ ] A message with `label == .safe && confidence == 0.95` from `SMSTriage` exits via fast-path without any `InferenceEngine.generate` call
- [ ] A message with `label == .suspicious` proceeds to slow-path and calls `InferenceEngine.shared.generate`
- [ ] All six MCP tool calls carry `callerAgentId: AgentID.textAgent`
- [ ] `ParsedVerdict.parse` failure propagates as `GemScanError.grammarViolation`

**Apple compliance (Spec 00 §11):**
- [ ] §11.7 — PR checklist: no raw message content sent to any MCP tool (only hashes, counts, derived signals)

---

#### ⬜ T-03-004 · IMPLEMENT · P0 — URLAgent

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P0 |
| **Spec ref** | §2.4 — URLAgent ReAct loop |
| **Depends on** | T-03-001, T-03-008, T-03-009, T-03-011 |
| **Estimated effort** | M |
| **Files to create/modify** | `ios/App/GemmaKit/Sources/Agents/URLAgent.swift` |

**What to build:**
Create `ios/App/GemmaKit/Sources/Agents/URLAgent.swift` as `actor URLAgent` with `static let shared = URLAgent()` and `let agentId = AgentID.urlAgent`. Implement `func handle(_ task: AgentTask) async throws -> AgentResult`. Build the prompt with `URLAgentPrompts.reactPrompt(url: task.content)` and start a streaming `InferenceEngine.shared.generate` call constrained by `GrammarConstraint.urlAgentGrammar`. Parse the streaming output token-by-token: when a line starts with `TOOL_CALL:`, parse the remainder as `{ "tool": "<name>", "server": "<server>", "args": {...} }`, execute the tool via `MCPClient.shared.call(server:tool:input:callerAgentId: AgentID.urlAgent)`, inject the result as `TOOL_RESULT: <json>` into the context, and continue generation. Allowed MCP tools for this agent: `sqlite_vec/semantic_search`, `url_reputation/check_url`, `whois/lookup`. Terminate the loop when `FINAL_VERDICT:` appears on a line; parse what follows as `ParsedVerdict`.

**Acceptance criteria:**
- [ ] `TOOL_CALL:` lines are detected and result in a `MCPClient.call` with the correct server/tool
- [ ] Only `sqlite_vec`, `url_reputation`, and `whois` tools are called — any other tool call is rejected with `MCPError.accessDenied`
- [ ] `FINAL_VERDICT:` terminates the loop and produces a valid `AgentResult`
- [ ] All MCP calls carry `callerAgentId: AgentID.urlAgent`

**Apple compliance (Spec 00 §11):**
- [ ] §11.7 — PR checklist: on-device only, no outbound HTTP in MCP path

---

#### ⬜ T-03-005 · IMPLEMENT · P0 — ImageAgent

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P0 |
| **Spec ref** | §2.5 — ImageAgent vision inference |
| **Depends on** | T-03-001, T-03-008, T-03-009, T-03-011 |
| **Estimated effort** | M |
| **Files to create/modify** | `ios/App/GemmaKit/Sources/Agents/ImageAgent.swift` |

**What to build:**
Create `ios/App/GemmaKit/Sources/Agents/ImageAgent.swift` as `actor ImageAgent` with `static let shared = ImageAgent()` and `let agentId = AgentID.imageAgent`. Implement `func handle(_ task: AgentTask) async throws -> AgentResult`. At entry, check `InferenceEngine.shared.isMLXAvailable`; if false, throw `GemScanError.grammarViolation` immediately. Otherwise, call `InferenceEngine.shared.generateVision(imageBase64: task.imageBase64, textPrompt: ImageAgentPrompts.visionPrompt(base64: task.imageBase64))` constrained by `GrammarConstraint.imageAgentGrammar`. Within the ReAct loop, call MCP tools (all with `callerAgentId: AgentID.imageAgent`): `sqlite_vec/semantic_search`, `url_reputation/check_url`, `reverse_image/extract_text_urls`, `reverse_image/compute_phash`. Parse the final output with `ParsedVerdict.parse(from:grammar:)` and map to `AgentResult`.

**Acceptance criteria:**
- [ ] `isMLXAvailable == false` → throws `GemScanError.grammarViolation` before any inference call
- [ ] `generateVision` is called with the `imageBase64` from `task.imageBase64` and the prompt from `ImageAgentPrompts.visionPrompt`
- [ ] Only the four allowed MCP tools are invoked; all carry `callerAgentId: AgentID.imageAgent`
- [ ] Compiles without warnings under `SWIFT_STRICT_CONCURRENCY=complete`

**Apple compliance (Spec 00 §11):**
- [ ] §11.7 — PR checklist: MLX availability gate verified before vision inference

---

#### ⬜ T-03-006 · IMPLEMENT · P0 — VoiceAgent

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P0 |
| **Spec ref** | §2.6 — VoiceAgent transcription and deepfake detection |
| **Depends on** | T-03-001, T-03-008, T-03-009, T-03-011 |
| **Estimated effort** | M |
| **Files to create/modify** | `ios/App/GemmaKit/Sources/Agents/VoiceAgent.swift` |

**What to build:**
Create `ios/App/GemmaKit/Sources/Agents/VoiceAgent.swift` as `actor VoiceAgent` with `static let shared = VoiceAgent()` and `let agentId = AgentID.voiceAgent`. Implement `func handle(_ task: AgentTask) async throws -> AgentResult`. First, call `WhisperASR.shared.transcribe(base64Audio: task.audioBase64, durationSeconds: task.audioDuration)` to obtain the transcript string. Concurrently (via `async let`), call `AudioSealDetector.shared.score(base64Audio: task.audioBase64)` to obtain `deepfakeScore: Float`. Build the prompt with `VoiceAgentPrompts.analysisPrompt(transcript: transcript, deepfakeScore: deepfakeScore)` — note this uses `analysisPrompt`, not `reactPrompt`. Call `InferenceEngine.shared.generate(prompt:grammar:)` with `GrammarConstraint.voiceAgentGrammar`. Within the loop, call allowed MCP tools (with `callerAgentId: AgentID.voiceAgent`): `sqlite_vec/semantic_search`, `phone_reputation/check`. Parse output with `ParsedVerdict.parse(from:grammar:)`.

**Acceptance criteria:**
- [ ] `WhisperASR.shared.transcribe` and `AudioSealDetector.shared.score` are both called before building the prompt
- [ ] `analysisPrompt(transcript:deepfakeScore:)` is used — not `reactPrompt`
- [ ] Only `sqlite_vec/semantic_search` and `phone_reputation/check` MCP tools are called; both carry `callerAgentId: AgentID.voiceAgent`
- [ ] `async let` is used for concurrent ASR + deepfake scoring

**Apple compliance (Spec 00 §11):**
- [ ] §11.7 — PR checklist: audio data never leaves device; no network calls in ASR path

---

#### ⬜ T-03-007 · IMPLEMENT · P0 — JudgeAgent

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P0 |
| **Spec ref** | §2.7 — JudgeAgent PhishDebate |
| **Depends on** | T-03-001, T-03-008, T-03-009, T-03-011 |
| **Estimated effort** | M |
| **Files to create/modify** | `ios/App/GemmaKit/Sources/Agents/JudgeAgent.swift` |

**What to build:**
Create `ios/App/GemmaKit/Sources/Agents/JudgeAgent.swift` as `actor JudgeAgent` with `static let shared = JudgeAgent()` and `let agentId = AgentID.judgeAgent`. Implement `func handle(_ task: AgentTask) async throws -> AgentResult` using a three-pass PhishDebate: Pass 1 — prompt the model to argue the content is **legitimate** and gather supporting evidence; Pass 2 — prompt the model to argue the content is **suspicious/scam** and gather counter-evidence; Pass 3 — present both arguments and produce a final synthesis verdict constrained by `GrammarConstraint.judgeGrammar`. Each pass may call MCP tools `scam_patterns/match_patterns`, `scam_patterns/get_pattern_detail`, and `sqlite_vec/semantic_search`, all with `callerAgentId: AgentID.judgeAgent`. If any pass throws an error, propagate it to `MessageRouter`, which falls back to a conservative `suspicious` `AgentResult` with `confidence = 0.5`. Parse the final pass output with `ParsedVerdict.parse(from:grammar:)`.

**Acceptance criteria:**
- [ ] Three distinct `InferenceEngine.shared.generate` calls are made (one per pass) in order
- [ ] Pass 1 prompt explicitly instructs "argue legitimate"; Pass 2 prompt explicitly instructs "argue suspicious"
- [ ] An error in Pass 2 propagates up and causes `MessageRouter` to return `suspicious` fallback
- [ ] All MCP calls carry `callerAgentId: AgentID.judgeAgent`

**Apple compliance (Spec 00 §11):**
- [ ] §11.7 — PR checklist: three-pass debate verified by unit test with mock engine

---

#### ⬜ T-03-008 · IMPLEMENT · P0 — GBNF grammar definitions

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P0 |
| **Spec ref** | §3.3 — Grammar-constrained inference |
| **Depends on** | None |
| **Estimated effort** | S |
| **Files to create/modify** | `ios/App/GemmaKit/Sources/Agents/Grammars/GrammarConstraint+Definitions.swift` |

**What to build:**
Create `ios/App/GemmaKit/Sources/Agents/Grammars/GrammarConstraint+Definitions.swift` as an extension on the existing `GrammarConstraint` type. Add five static factory properties: `GrammarConstraint.textAgentGrammar`, `.urlAgentGrammar`, `.imageAgentGrammar`, `.voiceAgentGrammar`, `.judgeGrammar`. Each must embed a GBNF string that constrains model output to a JSON object with the following required fields: `"verdict"` (enum literal `"safe"` | `"suspicious"` | `"scam"`), `"confidence"` (a float 0.0–1.0), `"reasoning"` (a JSON array of strings), and `"toolCalls"` (a JSON array of tool-call objects with `"server"`, `"tool"`, `"input"` string fields). The GBNF must reject any `verdict` value other than those three literals so that `ParsedVerdict.parse` can rely on a closed set.

**Acceptance criteria:**
- [ ] `GrammarConstraint.textAgentGrammar.gbnfString` is non-empty and contains the three verdict literals
- [ ] `GrammarConstraint.judgeGrammar.gbnfString` differs from textAgentGrammar (judge has no `toolCalls` in final pass, or has an extended synthesis field)
- [ ] Feeding `{"verdict":"maybe","confidence":0.5,"reasoning":[],"toolCalls":[]}` to `GrammarValidator.validate(output:grammar:)` throws `GemScanError.grammarViolation`
- [ ] All five properties compile without force-unwraps

**Apple compliance (Spec 00 §11):**
- [ ] §11.7 — N/A (grammar definitions only; no runtime, no data)

---

#### ⬜ T-03-009 · IMPLEMENT · P1 — Prompt templates

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P1 |
| **Spec ref** | §3.2 — Prompt construction and redaction |
| **Depends on** | None |
| **Estimated effort** | S |
| **Files to create/modify** | `ios/App/GemmaKit/Sources/Agents/Prompts/TextAgentPrompts.swift`, `ios/App/GemmaKit/Sources/Agents/Prompts/URLAgentPrompts.swift`, `ios/App/GemmaKit/Sources/Agents/Prompts/ImageAgentPrompts.swift`, `ios/App/GemmaKit/Sources/Agents/Prompts/VoiceAgentPrompts.swift` |

**What to build:**
Create four prompt template files under `ios/App/GemmaKit/Sources/Agents/Prompts/`. `TextAgentPrompts.swift`: `enum TextAgentPrompts` with `static func reactPrompt(content: String, language: String) -> String`. `URLAgentPrompts.swift`: `enum URLAgentPrompts` with `static func reactPrompt(url: String) -> String`. `ImageAgentPrompts.swift`: `enum ImageAgentPrompts` with `static func visionPrompt(base64: String) -> String`. `VoiceAgentPrompts.swift`: `enum VoiceAgentPrompts` with `static func analysisPrompt(transcript: String, deepfakeScore: Float) -> String`. Every prompt that includes user-controlled content must redact the raw content and instead embed a character count note using the exact format: `"[MESSAGE REDACTED — \(content.count) characters]"`. URL and image prompts may include the URL string and base64 length respectively.

**Acceptance criteria:**
- [ ] `TextAgentPrompts.reactPrompt(content: "hello", language: "en")` returns a string containing `"[MESSAGE REDACTED — 5 characters]"` and does NOT contain `"hello"`
- [ ] `VoiceAgentPrompts.analysisPrompt(transcript: "...", deepfakeScore: 0.8)` includes the deepfake score value in the prompt string
- [ ] All four functions are pure (no side effects, no global state)
- [ ] `ImageAgentPrompts.visionPrompt(base64:)` does NOT embed the raw base64 string

**Apple compliance (Spec 00 §11):**
- [ ] §11.7 — PR checklist: raw message content never embedded in prompt strings

---

#### ⬜ T-03-010 · IMPLEMENT · P1 — MCP tool failure recovery

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P1 |
| **Spec ref** | §3.8 — MCP tool failure handling |
| **Depends on** | T-03-003, T-03-004, T-03-005, T-03-006, T-03-007 |
| **Estimated effort** | S |
| **Files to create/modify** | `ios/App/GemmaKit/Sources/Agents/TextAgent.swift`, `ios/App/GemmaKit/Sources/Agents/URLAgent.swift`, `ios/App/GemmaKit/Sources/Agents/ImageAgent.swift`, `ios/App/GemmaKit/Sources/Agents/VoiceAgent.swift`, `ios/App/GemmaKit/Sources/Agents/JudgeAgent.swift` |

**What to build:**
In every agent's MCP call site, wrap `MCPClient.shared.call(...)` in a `do/catch` block with exactly three branches. Branch 1: `catch MCPError.accessDenied` — rethrow immediately (hard stop, do not continue analysis). Branch 2: `catch let error as MCPError` where the error represents a server-side error — log `Logger.shared.warning("MCP tool \(tool) failed: \(error)")` and continue with an empty `MCPToolResult` (safe degradation). Branch 3: `catch is CancellationError` — cancel the entire analysis task by calling `Task.cancel()` on the parent and return a conservative `AgentResult` with `verdict: .suspicious`. All three branches must be present in every agent; use a shared `callMCPWithRecovery(server:tool:input:callerAgentId:)` helper function inside each agent to avoid duplication.

**Acceptance criteria:**
- [ ] `MCPError.accessDenied` causes immediate rethrow — confirmed by unit test that checks the error propagates to the caller
- [ ] A server error (`MCPError.serverError`) is swallowed, logged, and analysis continues — confirmed by mock MCP client test
- [ ] `CancellationError` returns `AgentResult(verdict: .suspicious, confidence: 0.5)`
- [ ] No `try!` or force-unwraps in any MCP call site

**Apple compliance (Spec 00 §11):**
- [ ] §11.7 — PR checklist: no crash paths in MCP failure handling

---

#### ⬜ T-03-011 · IMPLEMENT · P1 — ParsedVerdict + output parsing

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P1 |
| **Spec ref** | §3.4 — Output parsing and verdict validation |
| **Depends on** | T-03-008 |
| **Estimated effort** | S |
| **Files to create/modify** | `ios/App/GemmaKit/Sources/Agents/ParsedVerdict.swift` |

**What to build:**
Create `ios/App/GemmaKit/Sources/Agents/ParsedVerdict.swift`. Define `struct ParsedVerdict: Codable` with fields: `verdict: String`, `confidence: Double`, `reasoning: [String]`, `toolCalls: [RawToolCall]`. Define `struct RawToolCall: Codable` with fields: `server: String`, `tool: String`, `input: [String: String]`. Add `static func parse(from output: String, grammar: GrammarConstraint) throws -> ParsedVerdict`: use `JSONDecoder` to decode `output.data(using: .utf8)`; after decoding, validate that `verdict` is one of `"safe"`, `"suspicious"`, `"scam"` — if not, throw `GemScanError.grammarViolation`. Validate that `confidence` is in `0.0...1.0` — if not, clamp and log a warning. Add a `toAgentResult() -> AgentResult` helper that maps `ParsedVerdict` fields to the `AgentResult` type.

**Acceptance criteria:**
- [ ] `ParsedVerdict.parse(from: validJSON, grammar: .textAgentGrammar)` returns a correctly populated struct
- [ ] `ParsedVerdict.parse(from: "{\"verdict\":\"maybe\",...}", grammar: .textAgentGrammar)` throws `GemScanError.grammarViolation`
- [ ] `confidence` outside `0...1` is clamped, not rejected
- [ ] `RawToolCall` decodes `input` as `[String: String]`, not `[String: Any]`

**Apple compliance (Spec 00 §11):**
- [ ] §11.7 — N/A (pure parsing logic; no I/O)

---

#### ⬜ T-03-012 · TEST · P1 — Agent round-trip tests

| Field | Value |
|---|---|
| **Type** | TEST |
| **Priority** | P1 |
| **Spec ref** | §7.1 — Spec 07 §3.1 agent round-trip test suite |
| **Depends on** | T-03-002, T-03-003, T-03-007, T-03-001 |
| **Estimated effort** | M |
| **Files to create/modify** | `ios/App/GemmaKit/Tests/AgentRoundTripTests.swift` |

**What to build:**
Create `ios/App/GemmaKit/Tests/AgentRoundTripTests.swift` as an `XCTestCase` subclass. Use `MockInferenceEngine` and `MockMCPClient` as defined in Spec 07 §3.0 — these must be injectable via protocol substitution (do not call real singletons). Write four test cases: (1) `testTextAgentClassifiesSafeMessage()` — `MockInferenceEngine` returns `{"verdict":"safe","confidence":0.95,...}`; assert `AgentResult.verdict == .safe`; (2) `testOrchestratorEscalatesWhenConfidenceLow()` — first mock response returns `confidence: 0.74`; assert `MockInferenceEngine.loadE4B()` was called and a second generate call was made; (3) `testJudgeAgentCompletesThreedPassDebate()` — assert `MockInferenceEngine.generate` was called exactly three times; (4) `testMessageRouterTimeoutThrowsInferenceTimeout()` — set mock engine to sleep 10 seconds, set task `timeoutMs: 1`; assert `GemScanError.inferenceTimeout` is thrown.

**Acceptance criteria:**
- [ ] All four tests pass on CI without network access
- [ ] `MockInferenceEngine` is used — no real CoreML or MLX model loading
- [ ] `testOrchestratorEscalatesWhenConfidenceLow` verifies `loadE4B()` call count == 1
- [ ] `testMessageRouterTimeoutThrowsInferenceTimeout` completes in under 2 seconds wall-clock

**Apple compliance (Spec 00 §11):**
- [ ] §11.7 — PR checklist: test targets excluded from App Store distribution build

---

#### ⬜ T-03-013 · TEST · P1 — Agent MCP access control tests

| Field | Value |
|---|---|
| **Type** | TEST |
| **Priority** | P1 |
| **Spec ref** | §4.5 — Spec 04 §5 MCP access control matrix |
| **Depends on** | T-03-003, T-03-004, T-04-001 |
| **Estimated effort** | M |
| **Files to create/modify** | `ios/App/GemmaKit/Tests/AgentAccessControlTests.swift` |

**What to build:**
Create `ios/App/GemmaKit/Tests/AgentAccessControlTests.swift` as an `XCTestCase` subclass. Register all ten mock MCP servers with a real `MCPClient.shared` instance (reset between tests using `MCPClient.resetForTesting()`). Write one test per disallowed combination from Spec 04 §5 matrix. Minimum required tests: `testURLAgentCannotCallContactsServer()` — call `MCPClient.shared.call(server: "contacts", tool: "is_known_sender", input: [:], callerAgentId: AgentID.urlAgent)` and assert `MCPError.accessDenied` is thrown; `testImageAgentCannotCallPhoneReputation()` — same pattern with `callerAgentId: AgentID.imageAgent`, tool `phone_reputation/check`; `testTextAgentCanCallContactsServer()` — assert no error for an allowed combination; `testOrchestratorCanCallSqliteVec()` — assert no error.

**Acceptance criteria:**
- [ ] All disallowed combinations throw `MCPError.accessDenied`
- [ ] All allowed combinations in the matrix return without error
- [ ] `MCPClient.resetForTesting()` clears registered servers between tests (no cross-test pollution)
- [ ] Tests do not require network access

**Apple compliance (Spec 00 §11):**
- [ ] §11.7 — PR checklist: access control matrix enforced at runtime, not just documentation

---

#### ⬜ T-03-014 · TEST · P2 — GBNF grammar validation tests

| Field | Value |
|---|---|
| **Type** | TEST |
| **Priority** | P2 |
| **Spec ref** | §3.3 — Grammar-constrained inference validation |
| **Depends on** | T-03-008, T-03-011 |
| **Estimated effort** | S |
| **Files to create/modify** | `ios/App/GemmaKit/Tests/GrammarConstraintTests.swift` |

**What to build:**
Create `ios/App/GemmaKit/Tests/GrammarConstraintTests.swift` as an `XCTestCase` subclass. Write `testGrammarConstraintRejectsMalformedOutput()`: call `GrammarValidator.validate(output: "{\"verdict\":\"maybe\",\"confidence\":0.5,\"reasoning\":[],\"toolCalls\":[]}", grammar: GrammarConstraint.textAgentGrammar)` and assert that `GemScanError.grammarViolation` is thrown. Write `testGrammarConstraintAcceptsValidOutput()`: call `GrammarValidator.validate(output: "{\"verdict\":\"safe\",\"confidence\":0.95,\"reasoning\":[\"no scam indicators\"],\"toolCalls\":[]}", grammar: GrammarConstraint.textAgentGrammar)` and assert no error is thrown. Write `testAllGrammarsHaveNonEmptyGBNFString()`: iterate all five grammar properties and assert each `.gbnfString.isEmpty == false`.

**Acceptance criteria:**
- [ ] `"maybe"` verdict throws `GemScanError.grammarViolation`
- [ ] `"safe"`, `"suspicious"`, `"scam"` verdicts all pass validation
- [ ] All five grammar static properties produce non-empty GBNF strings
- [ ] Tests do not instantiate real inference engines

**Apple compliance (Spec 00 §11):**
- [ ] §11.7 — N/A (unit tests only)

---

#### ⬜ T-03-015 · DOCUMENT · P2 — Agent system DocC

| Field | Value |
|---|---|
| **Type** | DOCUMENT |
| **Priority** | P2 |
| **Spec ref** | §1 — System architecture and agent routing diagram |
| **Depends on** | T-03-002, T-03-003, T-03-004, T-03-005, T-03-006, T-03-007 |
| **Estimated effort** | S |
| **Files to create/modify** | `ios/App/GemmaKit/Sources/Agents/OrchestratorAgent.swift`, `ios/App/GemmaKit/Sources/Agents/TextAgent.swift`, `ios/App/GemmaKit/Sources/Agents/URLAgent.swift`, `ios/App/GemmaKit/Sources/Agents/ImageAgent.swift`, `ios/App/GemmaKit/Sources/Agents/VoiceAgent.swift`, `ios/App/GemmaKit/Sources/Agents/JudgeAgent.swift`, `ios/App/GemmaKit/Sources/GemmaKit.docc/AgentSystem.md` |

**What to build:**
Add `///` DocC comments to all six agents' `handle(_:)` methods. Each comment block must document: (1) what `AgentTask.type` values the agent accepts; (2) which MCP tools it may call, listed by `server/tool` format; (3) under what conditions it escalates (e.g. low confidence, MLX unavailable); (4) what errors it can throw (`GemScanError.grammarViolation`, `MCPError.accessDenied`, `GemScanError.inferenceTimeout`). Create `ios/App/GemmaKit/Sources/GemmaKit.docc/AgentSystem.md` as a DocC article containing a Markdown table or ASCII diagram reproducing the agent routing diagram from Spec 03 §1, with `MessageRouter` → `OrchestratorAgent` → specialist agents → `JudgeAgent` flow.

**Acceptance criteria:**
- [ ] `xcodebuild docbuild` produces no documentation warnings for the Agents target
- [ ] `AgentSystem.md` is reachable from the GemmaKit documentation root
- [ ] Each `handle(_:)` docstring lists all MCP tools the agent is allowed to call
- [ ] DocC article includes the routing diagram

**Apple compliance (Spec 00 §11):**
- [ ] §11.7 — N/A (documentation only)

---

#### ⬜ T-03-016 · VALIDATE · P1 — Agent system Apple compliance

| Field | Value |
|---|---|
| **Type** | VALIDATE |
| **Priority** | P1 |
| **Spec ref** | §11.1 — Spec 00 §11 PR compliance checklist |
| **Depends on** | T-03-002, T-03-003, T-03-004, T-03-005, T-03-006, T-03-007, T-03-010, T-03-012, T-03-013 |
| **Estimated effort** | S |
| **Files to create/modify** | `ios/App/GemmaKit/Sources/Agents/` (all agent files — no new files, fix issues found) |

**What to build:**
Run the full Spec 00 §11.7 PR compliance checklist for the M3 milestone. Steps: (1) Run Thread Sanitizer (`xcodebuild test -enableThreadSanitizer YES`) on `AgentRoundTripTests` and `AgentAccessControlTests` — assert zero data races in the output; (2) Search all agent source files for `MCPClient.shared.call(` — verify every call site has an explicit `callerAgentId:` argument (no call site may omit it); (3) Build the GemmaKit target with `SWIFT_STRICT_CONCURRENCY=complete` — all agent `actor` types must compile without concurrency warnings; (4) Complete the §11.1 PR checklist markdown in the PR description before merging M3.

**Acceptance criteria:**
- [ ] TSan run reports zero data race warnings in agent tests
- [ ] Grep for `MCPClient.shared.call(` with missing `callerAgentId:` returns zero results
- [ ] `SWIFT_STRICT_CONCURRENCY=complete` build succeeds with zero warnings in `Sources/Agents/` and `Sources/Router/`
- [ ] PR description contains completed Spec 00 §11.1 checklist

**Apple compliance (Spec 00 §11):**
- [ ] §11.1 — Full PR checklist completed before merge
- [ ] §11.7 — TSan clean confirmed on agent round-trip test suite

---

#### ⬜ T-03-017 · IMPLEMENT · P1 — Explainer output reading level validation

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P1 |
| **Spec ref** | §7 — Explainer output spec (Flesch-Kincaid ≤ 70, 6th-grade reading level) |
| **Depends on** | T-03-011 |
| **Estimated effort** | M |
| **Files to create/modify** | `ios/App/GemmaKit/Sources/Agents/ExplainerValidator.swift`, `ios/App/GemmaKit/Tests/ExplainerValidatorTests.swift` |

**What to build:**
Create `ios/App/GemmaKit/Sources/Agents/ExplainerValidator.swift` as an `enum ExplainerValidator` (caseless namespace). Implement `static func fleschKincaidGradeLevel(_ text: String) -> Double` using the standard Flesch-Kincaid formula: `0.39 * (words / sentences) + 11.8 * (syllables / words) - 15.59`. Implement `static func validate(_ reasoning: [String]) -> Bool` that joins the reasoning bullets, computes the grade level, and returns `true` if the grade level ≤ 6.0 (approximately Flesch-Kincaid reading ease ≥ 70). Implement a basic `syllableCount(_ word: String) -> Int` using vowel-group heuristic (count groups of consecutive vowels `[aeiouy]`, subtract 1 for trailing silent `e`, minimum 1). This validator is called in every agent's `toAgentResult()` path — if validation fails, log a `.warning` but do not reject the result (soft enforcement for Cycle 1). Create `ExplainerValidatorTests.swift` with: `testSimpleTextPassesValidation()` (e.g., "This is a scam. Do not click the link.") and `testComplexTextFailsValidation()` (e.g., long sentence with polysyllabic jargon).

**Acceptance criteria:**
- [ ] `ExplainerValidator.fleschKincaidGradeLevel("The cat sat on the mat.")` returns a grade level ≤ 3.0
- [ ] `ExplainerValidator.validate(["This is safe.", "No scam found."])` returns `true`
- [ ] `syllableCount("beautiful")` returns 3
- [ ] Validation failure produces a `.warning` log, not an error or rejection

**Apple compliance (Spec 00 §11):**
- [ ] §11.5 — HIG: sixth-grade reading level supports accessibility for diverse users

---

#### ⬜ T-03-018 · IMPLEMENT · P1 — TypeScript web mock orchestrator

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P1 |
| **Spec ref** | §8 — Web Mock (TypeScript mock orchestrator with golden fixtures) |
| **Depends on** | T-03-009 |
| **Estimated effort** | S |
| **Files to create/modify** | `src/lib/agents/mock-orchestrator.ts`, `src/lib/agents/__tests__/mock-orchestrator.test.ts` |

**What to build:**
Create `src/lib/agents/mock-orchestrator.ts` exporting `async function mockOrchestrate(task: AgentTask): Promise<AgentResult>`. The mock simulates the full agent routing: for `classifySMS` and `classifyEmail` tasks, return the `goldenFixtures` entry matching `task.id` with 300–500 ms delay; for `checkURL` tasks, return URL fixtures with 200–400 ms delay; for `analyseScreenshot` tasks, return image fixtures with 500–800 ms delay (simulating E4B load time); for `scoreVoice` tasks, return voice fixtures with 400–700 ms delay (simulating ASR + inference). If `task.id` is not in golden fixtures, return `goldenFixtures['default']`. The mock must emit `tokenStream` events during the delay period (5–10 fake tokens) to simulate streaming. Create a Vitest test that verifies all task types route correctly and complete within their expected latency ranges.

**Acceptance criteria:**
- [ ] `mockOrchestrate({ type: 'classifySMS', id: 'scam-sms-bank', ... })` returns the `scam-sms-bank` fixture
- [ ] Each call emits at least 5 token events before resolving
- [ ] Unknown `task.id` returns the `'default'` fixture
- [ ] Vitest test passes for all six `AgentTaskType` values

**Apple compliance (Spec 00 §11):**
- [ ] N/A — TypeScript web mock; not shipped in iOS app
