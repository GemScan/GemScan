# Proposed Solution

---

## Section 3 — Proposed Solution: GemScan

### 3.1 System Architecture Overview

GemScan is a **Next.js-plus-Capacitor mobile application** [81] that bundles a **Gemma-based agentic core** (two models, six specialist agents) with a set of **in-process MCP servers** [82][83][84][85][86] and a **platform-native inter-agent message router**, all running entirely on the user's device. The demo build targets iOS, where a shared native package, **GemmaKit**, links the main app target and four system extensions (SMS Filter, Call Directory, Share, App Intents); the architecture is designed so the same inference pipeline and MCP server layer ports to Android with only the platform integration layer changing.

```
 ┌──────────────────────────────────────────────────────────────┐
 │            GemScan (Capacitor mobile shell)                │
 │  Next.js UI ↔ Capacitor Bridge ↔ Native Inference Package  │
 └────────┬─────────────────────────────────────────────────────┘
          │ Platform-native message router (in-process, no network stack)
   ┌──────▼──────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐
   │Orchestrator │ │  Text    │ │  URL     │ │  Voice   │ │  Image   │ │ Judge /  │
   │ (Gemma 4    │ │ Agent    │ │ Agent    │ │ Agent    │ │ Agent    │ │Explainer │
   │  E4B)       │ │ (E2B)    │ │ (E2B)    │ │ (E4B+ASR)│ │ (E4B+VLM)│ │ (E4B)    │
   └──────┬──────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘
          │ MCP (stdio over in-memory pipes)
   ┌──────▼───────────────────────────────────────────────────────────────▼────┐
   │ Local MCP servers: scam_patterns · sqlite-vec · contacts · url_reputation │
   │  whois · reverse_image · phone_reputation · safe_browsing (hash-prefix)   │
   │  clipboard_watcher · message_filter · screen_time                         │
   └──────────────────────────────────────────────────────────────────────────┘
```

### 3.2 Model Allocation: E2B Always-On, E4B Deep Analysis

**Gemma 4 E2B (2.3 B effective / 5.1 B with embeddings, 128 K context, text+image+audio)** [67][68][69] runs as the **always-on screening tier** quantised to **Q4_K_M (~1.5–1.8 GB RAM)** [55][70]. It handles fast binary classification on SMS, call-screen transcripts, incoming notifications, and clipboard URLs. On Qualcomm Dragonwing IQ8 NPUs, Google cites **3,700 prefill / 31 decode tok/s** for E2B; projected to the **A15 Bionic on the iPhone 14 (6 GB RAM, 15.8 TOPS ANE)** — the iOS demo reference device [62][73] — the target is **15–25 decode tok/s and ≤ 400 ms first-token latency** via MLX Swift on iOS [77][78] and LiteRT-LM on Android, with **peak RSS ≤ 2.3 GB including KV cache**.

**Gemma 4 E4B (4.5 B effective / 8 B total)** [67] is the **deep-reasoning tier** quantised to **Q4_K_M (~2.8–3.2 GB)** [55], loaded on demand when E2B's confidence is below a threshold or the user explicitly requests analysis. E4B runs agentic planning, multi-turn reasoning, multimodal screenshot analysis, and audio-deepfake scoring. Because of its 6 GB RAM floor, E4B is opportunistic on devices with 6 GB (e.g. iPhone 14, mid-range Android) and fully resident on devices with 8 GB+ (e.g. iPhone 15/16, flagship Android). Gemma 4 E2B already outperforms **Gemma 3 27B on Tau2 agentic benchmarks (24.5 % vs 16.2 %)** [67] — the first time an on-phone model surpasses last year's cloud flagship on multi-turn tool use — which directly validates the on-device agentic thesis.

### 3.3 Quantisation and Runtime Stack

GemScan will ship **four model artifacts** via the Hugging Face Hub:

- `GemScan/gemma-4-e2b-it-GemScan-q4km.gguf` — LoRA-merged and quantised (~1.5 GB); runs on any platform via llama.cpp [96]
- `GemScan/gemma-4-e4b-it-GemScan-q4km.gguf` — LoRA-merged and quantised (~3.0 GB); cross-platform via llama.cpp [96]
- `GemScan/gemma-4-e2b-it-GemScan-mlx-4bit` — MLX native for the iOS demo build [78]
- `GemScan/gemma-4-e4b-it-GemScan-mlx-4bit` — MLX native with TurboQuant KV-cache compression for the iOS demo build [61]

The **GGUF artifacts are the canonical cross-platform format**: llama.cpp runs on iOS (Metal), Android (Vulkan/OpenCL), Linux, and Windows from the same binary. For the iOS demo build, runtime priority is **MLX Swift** [77][78] for lower latency on Apple Silicon; the Android build will use **LiteRT-LM** (formerly MediaPipe LLM Inference) or llama.cpp with Vulkan backend. Core ML conversion via `coremltools` [75] is deprioritised due to known PyTorch-to-MIL conversion bugs on Gemma 3/4; ExecuTorch's Core ML backend [76] is the iOS ANE fallback once those clear. **We deliberately do not rely on Apple's Foundation Models framework** [74], which requires iPhone 15 Pro+ and would exclude the majority of target devices on both platforms.

### 3.4 Multi-Modal Capabilities

Gemma 4 E2B and E4B are the **first open on-device models with native audio input** [67][68] — the family ships a **USM-style Conformer audio encoder** enabling speech-to-text, audio reasoning, and emotional-tone analysis without an external ASR step. This permits one-shot voice-scam screening: the audio stream of an answered call can be fed directly to E4B, which emits both a transcript and a scam-risk verdict. The vision encoder supports **native-aspect-ratio images with configurable token budgets (70/140/280/560/1120 tokens)**, enabling rapid screenshot analysis for fake TikTok Shop listings, phishing emails, and QR-code phishing images.

### 3.4a Voice Agent: Audio Ingestion Path and Platform Constraints

Live call recording is the most platform-restricted capability in GemScan and requires a distinct implementation strategy on each platform.

**iOS.** Apple prohibits third-party apps from recording the far-end audio of an active phone call via `CallKit` or `AVAudioSession` in most jurisdictions — the microphone input during a call is routed to the system telephony stack and is not accessible to apps. GemScan's Voice Agent therefore operates in two modes on iOS:

1. **Post-call analysis (default).** After a call ends, if the user opts in, the device's own-microphone recording (near-end only) captured via `AVAudioSession` in `.record` category during the call is passed to E4B. This captures the user's side of the conversation — sufficient to detect coached-payment language and urgency scripting directed at the user — but not the scammer's voice directly.
2. **Call screening (Guardian mode).** iOS 26's `CallKit` call-screening API allows an app to intercept an inbound call before the user picks up and receive a transcript via Siri's on-device speech recognition. GemScan hooks this API to pre-screen unknown callers and present a verdict before the user answers. This is legally unambiguous (the call has not yet connected) and technically sanctioned by Apple.
3. **Shared audio (user-initiated).** The Share Extension allows a user to share a voice memo, voicemail, or WhatsApp/Telegram audio message directly to GemScan for deepfake and scam scoring — no call recording involved.

**Android.** Android permits microphone recording during a call via `AudioRecord` with `VOICE_COMMUNICATION` source on many OEM devices, and the `PROCESS_OUTGOING_CALLS` / `READ_CALL_LOG` permissions enable richer integration on rooted or carrier-permissioned builds. For the standard Play Store build, GemScan uses the same three-mode approach as iOS: post-call near-end audio, `CallScreeningService` pre-answer screening, and user-initiated share analysis.

**Consequence for benchmarking.** The Voice Agent's live-scam detection capability is measured on user-initiated audio samples (voicemails, shared recordings) and simulated post-call memos — not on intercepted live call audio. This is a deliberate constraint, not a limitation of the model. The deepfake-detection benchmarks in §4.4 use ASVspoof 5 [39] and DeepSpeak [41] audio files fed via the Share path.

Six agents share the inference runtime and communicate via a **platform-native in-process message router** — each agent exposes a typed async `handle(task: AgentTask) -> AgentResult` interface. The Orchestrator routes tasks by capability type (`classifySMS`, `scoreVoiceDeepfake`, `analyseScreenshot`) and collects results concurrently, with no network stack and no serialisation overhead. The iOS demo implements this with Swift actors and `async`/`await`; the Android build will use Kotlin coroutines and the same `AgentTask`/`AgentResult` envelope, keeping the orchestration logic identical across platforms.

- **Orchestrator Agent (E4B)** — intent classification, tool routing, task decomposition, final verdict aggregation. Implements the ReAct loop [92] via Gemma 4's native function-calling [71].
- **Text Agent (E2B)** — SMS, email, DM, and notification content classification with queries to `scam_patterns` and `sqlite-vec` MCP servers.
- **URL Agent (E2B)** — URL extraction, Safe-Browsing hash-prefix lookup [98], WHOIS domain-age check, brand-impersonation detection, following the KnowPhish [46] multimodal approach.
- **Voice Agent (E4B + ASR)** — call audio transcription, voice-cloning artifact scoring (pitch, cadence, spectral), AudioSeal watermark check [38]. See §3.4a for the platform-specific audio ingestion path and its constraints.
- **Image Agent (E4B VLM)** — screenshot OCR, logo and brand detection, reverse-image lookup, QR-code decoding, deepfake-still detection [41][40].
- **Judge/Explainer Agent (E4B)** — aggregates specialist verdicts via weighted voting or structured debate (PhishDebate pattern [52]) and produces a user-facing explanation in the user's native language and dialect.

This hybrid **orchestrator-worker plus debate** topology maximises interpretability (a requirement for elderly and LEP users) while bounding latency.

### 3.6 MCP Server Layer

Every external-world capability is exposed as an **MCP server running in-process over in-memory pipes** [82][83][84][85]. Both mobile sandboxes disallow arbitrary subprocess spawning, so each MCP server is a native class registered at app launch — conforming to the **Anthropic Swift SDK** [86] on iOS and the MCP Kotlin SDK on Android.

| MCP server | Tools | iOS surface | Android surface |
|---|---|---|---|
| `scam_patterns` | `search_patterns`, `match_pattern` | Local SQLite of curated scam regex/templates | Same (SQLite via Room) |
| `sqlite_vec` | `semantic_search`, `nearest_known_scams` | On-device vector DB (ObjectBox [97] or sqlite-vec) | Same (ObjectBox Android) |
| `contacts` | `is_known_contact`, `contact_reputation` | `CNContactStore` | `ContactsContract` |
| `url_reputation` | `check_url`, `safe_browsing_lookup` | Google Safe Browsing v4 hash prefix (local DB, k-anonymous) [98] | Same |
| `whois` | `whois_lookup`, `domain_age` | Public RDAP over HTTPS | Same |
| `reverse_image` | `reverse_image_search` | On-device CLIP embedding similarity | Same |
| `phone_reputation` | `phone_reputation`, `is_voip` | Local heuristics + hashed reputation DB | Same |
| `message_filter` | `enqueue_sms_for_analysis` | `ILMessageFilterExtension` [80] | `SmsRetriever` / `RECEIVE_SMS` |
| `clipboard_watcher` | `scan_clipboard_url` | `UIPasteboard` | `ClipboardManager` |
| `screen_time` | `child_device_policy` | `FamilyControls` / `ManagedSettings` | Digital Wellbeing API |

Because all servers run in-process over memory pipes (not over HTTP), the MCP OAuth 2.1 model does not apply directly — there is no network origin to authenticate. Instead, the Orchestrator enforces **capability-level access control at the router layer**: each agent is statically declared with a permitted tool set at registration time, and the router rejects any `tool/call` that crosses capability boundaries (e.g., the `message_filter` server is registered with network-tool access disabled). This achieves the same least-privilege intent as MCP's OAuth scoping model [83], implemented as compile-time typed permissions rather than runtime token checks.

### 3.7 Inter-Agent Orchestration and Future Federation

The in-process native router is the right primitive for a mobile MVP: it requires no HTTP stack, respects both iOS and Android sandboxing with zero friction, and keeps latency in the microsecond range. On iOS the implementation uses Swift actors with structured concurrency; on Android it uses Kotlin coroutines with `Flow`-based result streaming — both conforming to the same `AgentTask`/`AgentResult` contract.

Federation is preserved as a future option. The `AgentTask` / `AgentResult` envelope is designed to be serialisable, so any agent can be promoted to a remote endpoint later without changing its callers — the Orchestrator simply swaps the local actor call for an HTTPS request to a cloud agent. When that path is pursued (e.g., an opt-in threat-intelligence consensus agent), the A2A protocol becomes the natural wire format, since the agent interface already maps cleanly onto A2A's skill-and-task model.

### 3.8 Tool Use and Function Calling

Gemma 4 ships **first-class JSON-schema function calling** [71] via `processor.apply_chat_template(messages, tools=...)`. GemScan wraps every agent call and every MCP tool invocation in **grammar-constrained decoding** using **llama.cpp GBNF** [96] (converted from JSON Schema) to guarantee syntactically valid tool outputs even from quantised E2B. Platform system actions are enumerated at launch and presented to the agent as additional tools — `BlockSenderIntent`, `ReportSpamIntent`, `ReadLastNotificationIntent`, `CallTrustedContactIntent` — so OS-level actions become first-class members of the agent's toolbox (App Intents on iOS; Android App Actions / `Intent` dispatch on Android). This extends the Toolformer [93] and AutoGen [94] paradigms to mobile platforms using native concurrency primitives rather than a network-layer agent protocol.

### 3.9 Privacy-First Architecture

By default, **no message content, call audio, screenshot, or contact record ever leaves the device**. Network calls are restricted to three narrow endpoints: (a) **Safe Browsing hash-prefix queries** (k-anonymous) [98], (b) **RDAP WHOIS** over HTTPS, and (c) **optional, user-initiated escalation** to a cloud A2A agent. Vector-DB keys are sealed in **device secure storage** (Secure Enclave on iOS; Android Keystore on Android) [61]. An **encrypted cross-device sync** option lets users restore their scam-report history; the encryption key never leaves local hardware. **Federated learning with local DP noise (DP-FedAvg)** is the long-term path for improving the shared model without ever collecting raw messages.

### 3.10 Accessibility for Elders and Non-Native Speakers

Gemma 4's **140+-language support** [67][68] is the linchpin of GemScan's accessibility plan. The UI launches with **voice-first interaction** in the user's OS language, a **high-contrast large-type visual mode**, and **single-button "Check this for me"** affordance invoked via the system share sheet, a home-screen widget, or a voice assistant shortcut (Siri on iOS; Google Assistant on Android). When E4B produces a verdict, the Explainer Agent renders the reasoning in the user's native language at a sixth-grade reading level, with **culturally-aware warnings** (e.g., the Judge knows that an "RBI call" impersonation has a different shape in Hindi than a "CBI digital arrest" framing, and that the Japanese ore-ore pattern differs from the US grandparent scam). A **Trusted Contact Escalation** feature lets the user nominate an adult child or grandchild who receives a push notification when a high-risk event is detected, closing the social-proof loop that scammers deliberately isolate. This directly operationalises the LEP-vulnerability findings of Olivares-Pasillas [36] and AARP's multicultural fraud surveys [27][99].

### 3.11 Platform Integration Points

GemScan hooks into four OS-level surfaces on each platform. The iOS demo build uses:

1. **SMS Filter** (`ILMessageFilterExtension` [80]) — triggered only on SMS from non-contacts. Because the extension has a **~50 MB memory ceiling**, it cannot run E2B; it instead uses a **distilled DistilBERT on-device classifier ≤ 5 MB** for the real-time allow/junk/promotion/transaction decision [53], and hands flagged messages to the main app for full E2B/E4B re-analysis.
2. **Call Directory** (`CXCallDirectoryExtension`) — periodically regenerates a blocked-number list from the `phone_reputation` MCP server.
3. **Share Extension** — users can share any URL, message, or screenshot to GemScan for immediate analysis.
4. **Voice Assistant / App Intents** — exposes `CheckWithGemScanIntent`, `ReportScamIntent`, `BlockSenderIntent` to the system assistant and shortcut surfaces.

A **browser content blocker** extension consumes declarative JSON rules generated by the main app from the user's flagged URLs (Safari Content Blocker on iOS; Chrome Custom Tabs / WebView rule injection on Android).

The Android build maps to the same four surfaces: `SmsRetriever` / `RECEIVE_SMS` broadcast for SMS filtering; `CallScreeningService` for call blocking; the system Share intent for content sharing; and Android App Actions for voice assistant integration. All four share the same MCP server layer and inference pipeline — only the OS binding layer differs.

### 3.12 Real-Time vs On-Demand Modes

GemScan has three screening modes applicable on both platforms. **Passive mode** runs the SMS filter and call-blocking extension only — zero main-app battery draw. **Active mode** keeps E2B resident for fast on-demand analysis of user-shared content. **Guardian mode** is the most protective tier but also the most sensitive from a consent and autonomy standpoint, so its activation is deliberately multi-step.

**Guardian mode consent flow.** Guardian mode can be enabled in two ways, reflecting the two primary use cases:

1. **Self-enrolment (elder or teen activates for themselves).** The user navigates to Settings → Guardian Mode and is shown a plain-language summary of what the mode does (monitors notifications, screens unknown calls, pre-scores clipboard URLs) before any permission is requested. A single "Turn on Guardian Mode" button triggers the platform permission dialogs sequentially. The user can disable any individual capability without leaving Guardian mode entirely.

2. **Caregiver-assisted enrolment.** A nominated Trusted Contact (parent, adult child) can send a Guardian Mode invitation via the app. The device owner receives the invitation as an in-app notification and must explicitly accept it — the Trusted Contact cannot enable Guardian mode remotely without the device owner's confirmation. This preserves autonomy: the elder or teen is an active participant, not a passive subject.

In both cases: (a) Guardian mode status is displayed persistently in the app's main UI so it is never invisible; (b) a one-tap "Pause Guardian Mode" action is available from the lock screen widget and notification centre; (c) the Trusted Contact receives a push notification when Guardian mode is enabled, paused, or disabled, so both parties have shared awareness.

This design directly addresses the isolation tactic scammers use — the Trusted Contact link breaks that isolation — while ensuring the protected person retains meaningful control, in line with the dignity-centred framing of AARP's elder-fraud recommendations [27].

---

## References

27. AARP. "Vital Voices: Fraud Concerns of Older Adults." 2025. https://www.aarp.org/pri/topics/aging-experience/demographics/vital-voices-fraud-concerns-older-adults.html
36. Olivares-Pasillas, M. C., et al. "Insurgent Citizenship: How Consumer Complaints on Immigration Scams Inform Policy." *Georgetown Immigration Law Journal*, 2024. https://www.law.georgetown.edu/immigration-law-journal/wp-content/uploads/sites/19/2024/03/GT-GILJ230012-1.pdf
38. San Roman, R., Fernandez, P., et al. "Proactive Detection of Voice Cloning with Localized Watermarking (AudioSeal)." ICML 2024. https://arxiv.org/abs/2401.17264
40. Lin, L., He, X., et al. "Preserving Fairness Generalization in Deepfake Detection." CVPR 2024.
41. Barrington, S., Bohacek, M., Farid, H. "DeepSpeak Dataset v1.0." arXiv:2408.05366, 2024.
46. Li, Y., et al. "KnowPhish: Large Language Models Meet Multimodal Knowledge Graphs." USENIX Security 2024. https://www.usenix.org/conference/usenixsecurity24/presentation/li-yuexin
52. "PhishDebate: An LLM-Based Multi-Agent Framework for Phishing Website Detection." arXiv:2506.15656, 2025.
53. ElZemity, A. "Agentic Knowledge Distillation: Autonomous Training of Small Language Models for SMS Threat Detection." arXiv:2602.10869, 2026.
55. Frantar, E., Ashkboos, S., Hoefler, T., Alistarh, D. "GPTQ: Accurate Post-Training Quantization for Generative Pre-trained Transformers." ICLR 2023. https://arxiv.org/abs/2210.17323
61. Yang, H., Zhang, D., et al. "A First Look at Efficient and Secure On-Device LLM Inference Against KV Leakage." ACM MobiArch 2024. https://arxiv.org/abs/2409.04040
62. Ajayi, O. A., Ahmad, I. "Benchmarking On-Device Machine Learning on Apple Silicon with MLX." arXiv:2510.18921, 2024.
67. Google AI Edge Team. "Bring State-of-the-Art Agentic Skills to the Edge with Gemma 4." April 2026. https://developers.googleblog.com/bring-state-of-the-art-agentic-skills-to-the-edge-with-gemma-4/
68. Hugging Face. "Welcome Gemma 4: Frontier Multimodal Intelligence on Device." 2026. https://huggingface.co/blog/gemma4
69. Google. "Gemma 4: Byte for Byte, the Most Capable Open Models." 2026. https://blog.google/innovation-and-ai/technology/developers-tools/gemma-4/
70. Yvinec, E., Culliton, P. "Gemma 3 QAT Models." Google Developers Blog, 2025. https://developers.googleblog.com/en/gemma-3-quantized-aware-trained-state-of-the-art-ai-to-consumer-gpus/
71. Google AI. "Function Calling with Gemma 4." 2026. https://ai.google.dev/gemma/docs/capabilities/text/function-calling-gemma4
73. Apple Machine Learning Research. "Deploying Transformers on the Apple Neural Engine." 2022. https://machinelearning.apple.com/research/neural-engine-transformers
74. Apple. "Introducing Apple's On-Device and Server Foundation Models." 2024. https://machinelearning.apple.com/research/introducing-apple-foundation-models
75. Apple. Core ML Tools Documentation. https://apple.github.io/coremltools/docs-guides/
76. Apple. ExecuTorch Core ML Backend Documentation. https://docs.pytorch.org/executorch/0.7/backends-coreml.html
77. Swift.org. "On-device ML research with MLX and Swift." 2024. https://www.swift.org/blog/mlx-swift/
78. Apple ml-explore. "mlx-swift." https://github.com/ml-explore/mlx-swift
80. Apple Developer. "ILMessageFilterExtension." https://developer.apple.com/documentation/sms_and_call_reporting/ilmessagefilterextension
81. Capacitor Documentation. "Custom Native Code." https://capacitorjs.com/docs/plugins/creating-plugins
82. Anthropic. "Introducing the Model Context Protocol." November 2024. https://www.anthropic.com/news/model-context-protocol
83. Model Context Protocol Specification (2025-06-18 and November 2025 revisions). https://modelcontextprotocol.io/
84. Model Context Protocol Architecture. https://modelcontextprotocol.io/docs/learn/architecture
85. Model Context Protocol Transports. https://modelcontextprotocol.io/specification/2025-03-26/basic/transports
86. Anthropic. "MCP Swift SDK." https://github.com/modelcontextprotocol/swift-sdk
92. Yao, S., et al. "ReAct: Synergizing Reasoning and Acting in Language Models." ICLR 2023. https://arxiv.org/abs/2210.03629
93. Schick, T., et al. "Toolformer: Language Models Can Teach Themselves to Use Tools." NeurIPS 2023. https://arxiv.org/abs/2302.04761
94. Wu, Q., et al. "AutoGen: Enabling Next-Gen LLM Applications via Multi-Agent Conversation Framework." arXiv:2308.08155, 2023.
96. llama.cpp GBNF Grammars. https://github.com/ggml-org/llama.cpp/blob/master/grammars/README.md
97. ObjectBox. On-Device Vector Search Documentation. https://docs.objectbox.io/on-device-vector-search
98. Google. Safe Browsing API v4 Documentation.
99. AARP. "Scams Take Toll on Older Asian American Pacific Islanders." FCC. https://www.fcc.gov/scams-take-toll-older-asian-american-pacific-islanders
