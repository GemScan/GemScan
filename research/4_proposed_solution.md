# Proposed Solution

---

## Section 3 — Proposed Solution: GemScan

### 3.1 System Architecture Overview

GemScan is a **Next.js-plus-Capacitor iOS application** [81] that bundles a **Gemma-based agentic core** (two models, six specialist agents) with a set of **in-process MCP servers** [82][83][84][85][86] and **A2A-mediated inter-agent communication** [88][89][90], all running entirely on the user's iPhone. A single shared Swift package, **GemmaKit**, is linked by the main app target and by four iOS extensions (Message Filter, Call Directory, Share, App Intents), so the same inference pipeline powers every entry point.

```
 ┌──────────────────────────────────────────────────────────────┐
 │                 GemScan (iOS, Capacitor shell)             │
 │   Next.js UI ↔ Capacitor Bridge ↔ GemmaKit (Swift)           │
 └────────┬─────────────────────────────────────────────────────┘
          │ A2A (local JSON-RPC 2.0 over in-proc pipes)
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

**Gemma 4 E2B (2.3 B effective / 5.1 B with embeddings, 128 K context, text+image+audio)** [67][68][69] runs as the **always-on screening tier** quantised to **Q4_K_M (~1.5–1.8 GB RAM)** [55][70]. It handles fast binary classification on SMS, call-screen transcripts, incoming notifications, and clipboard URLs. On Qualcomm Dragonwing IQ8 NPUs, Google cites **3,700 prefill / 31 decode tok/s** for E2B; projected to the **A15 Bionic's 15.8 TOPS ANE + 5-core GPU on iPhone 14 (6 GB RAM)** [62][73], the target is **15–25 decode tok/s and ≤ 400 ms first-token latency** via MLX Swift GPU inference [77][78], with **peak RSS ≤ 2.3 GB including KV cache**.

**Gemma 4 E4B (4.5 B effective / 8 B total)** [67] is the **deep-reasoning tier** quantised to **Q4_K_M (~2.8–3.2 GB)** [55], loaded on demand when E2B's confidence is below a threshold or the user explicitly requests analysis. E4B runs agentic planning, multi-turn reasoning, multimodal screenshot analysis, and audio-deepfake scoring. Because of its 6 GB RAM floor, E4B is opportunistic on iPhone 14 (6 GB) and fully resident on iPhone 14 Pro / 15 / 16 (6–8 GB). Gemma 4 E2B already outperforms **Gemma 3 27B on Tau2 agentic benchmarks (24.5 % vs 16.2 %)** [67] — the first time an on-phone model surpasses last year's cloud flagship on multi-turn tool use — which directly validates the on-device agentic thesis.

### 3.3 Quantisation and Runtime Stack

GemScan will ship **four model artifacts** via the Hugging Face Hub:

- `GemScan/gemma-4-e2b-it-GemScan-q4km.gguf` — LoRA-merged and quantised (~1.5 GB)
- `GemScan/gemma-4-e4b-it-GemScan-q4km.gguf` — LoRA-merged and quantised (~3.0 GB)
- `GemScan/gemma-4-e2b-it-GemScan-mlx-4bit` — MLX native for Apple Silicon [78]
- `GemScan/gemma-4-e4b-it-GemScan-mlx-4bit` — MLX native with TurboQuant KV-cache compression [61]

Runtime priority on iOS is **MLX Swift** (via `mlx-swift-examples`'s `LLMModelFactory`) [77][78] with Metal GPU backend. Core ML conversion via `coremltools` [75] is attempted but deprioritised due to **known PyTorch-to-MIL conversion bugs on Gemma 3/4** (coremltools issue #2560); ExecuTorch's Core ML backend [76] is the fallback path for ANE targeting once those bugs clear. **We deliberately do not rely on Apple's Foundation Models framework** [74], because it requires Apple Intelligence hardware (iPhone 15 Pro+) and excludes the iPhone 14 baseline.

### 3.4 Multi-Modal Capabilities

Gemma 4 E2B and E4B are the **first open on-device models with native audio input** [67][68] — the family ships a **USM-style Conformer audio encoder** enabling speech-to-text, audio reasoning, and emotional-tone analysis without an external ASR step. This permits one-shot voice-scam screening: the audio stream of an answered call can be fed directly to E4B, which emits both a transcript and a scam-risk verdict. The vision encoder supports **native-aspect-ratio images with configurable token budgets (70/140/280/560/1120 tokens)**, enabling rapid screenshot analysis for fake TikTok Shop listings, phishing emails, and QR-code phishing images.

### 3.5 Multi-Agent Architecture over MCP and A2A

Six agents share the inference runtime and communicate over an **in-process A2A bus** [88][89][91] using the canonical JSON-RPC 2.0 envelope and Agent Card discovery defined in **A2A v1.0** (hosted at `/.well-known/agent-card.json` even for local agents). Each agent exposes its skills (e.g., `classify_sms`, `score_voice_deepfake`, `analyse_screenshot`) through an Agent Card at launch, letting the Orchestrator route tasks dynamically.

- **Orchestrator Agent (E4B)** — intent classification, tool routing, task decomposition, final verdict aggregation. Implements the ReAct loop [92] via Gemma 4's native function-calling [71].
- **Text Agent (E2B)** — SMS, email, DM, and notification content classification with queries to `scam_patterns` and `sqlite-vec` MCP servers.
- **URL Agent (E2B)** — URL extraction, Safe-Browsing hash-prefix lookup [98], WHOIS domain-age check, brand-impersonation detection, following the KnowPhish [46] multimodal approach.
- **Voice Agent (E4B + ASR)** — live call audio transcription, voice-cloning artifact scoring (pitch, cadence, spectral), AudioSeal watermark check [38].
- **Image Agent (E4B VLM)** — screenshot OCR, logo and brand detection, reverse-image lookup, QR-code decoding, deepfake-still detection [41][40].
- **Judge/Explainer Agent (E4B)** — aggregates specialist verdicts via weighted voting or structured debate (PhishDebate pattern [52]) and produces a user-facing explanation in the user's native language and dialect.

This hybrid **orchestrator-worker plus debate** topology maximises interpretability (a requirement for elderly and LEP users) while bounding latency.

### 3.6 MCP Server Layer

Every external-world capability is exposed as an **MCP server running in-process over in-memory pipes** [82][83][84][85]. Because iOS sandboxing disallows arbitrary subprocess spawning, each MCP server is a Swift class conforming to the **official Anthropic Swift SDK** [86] (`modelcontextprotocol/swift-sdk`), registered at app launch.

| MCP server | Tools | iOS surface |
|---|---|---|
| `scam_patterns` | `search_patterns`, `match_pattern` | Local SQLite of curated scam regex/templates |
| `sqlite_vec` | `semantic_search`, `nearest_known_scams` | On-device vector DB (ObjectBox [97] or sqlite-vec) over labelled scam corpus |
| `contacts` | `is_known_contact`, `contact_reputation` | `CNContactStore` |
| `url_reputation` | `check_url`, `safe_browsing_lookup` | Google Safe Browsing v4 hash prefix (local DB, k-anonymous) [98] |
| `whois` | `whois_lookup`, `domain_age` | Public RDAP over HTTPS |
| `reverse_image` | `reverse_image_search` | On-device CLIP embedding similarity against curated known-scam-image DB |
| `phone_reputation` | `phone_reputation`, `is_voip` | Local heuristics + hashed reputation DB |
| `message_filter` | `enqueue_sms_for_analysis` | `ILMessageFilterExtension` [80] bridge via App Group |
| `clipboard_watcher` | `scan_clipboard_url` | `UIPasteboard` (with system pill) |
| `screen_time` | `child_device_policy` | `FamilyControls` / `ManagedSettings` |

All servers are scoped by **least-privilege permission tokens** derived from MCP's 2025-06-18 OAuth 2.1 update [83], so that (for example) the `message_filter` server cannot call network tools.

### 3.7 A2A as the Inter-Agent Glue — and a Future Federation Point

At MVP, A2A [88][89][90][91] runs entirely locally. The principled reason to use A2A rather than direct function calls is **optionality**: any agent can be *promoted* to a cloud agent in the future without changing its callers. A user worried about deepfake-laden corporate video calls could, for example, opt in to a cloud-side **threat-intelligence consensus agent** that cross-votes with the on-device Judge. A2A's Agent Card signatures and OAuth scopes give us a clean trust boundary when that day comes.

### 3.8 Tool Use and Function Calling

Gemma 4 ships **first-class JSON-schema function calling** [71] via `processor.apply_chat_template(messages, tools=...)`. GemScan wraps every agent call and every MCP tool invocation in **grammar-constrained decoding** using **llama.cpp GBNF** [96] (converted from JSON Schema) to guarantee syntactically valid tool outputs even from quantised E2B. Apple **App Intents** are enumerated at launch and presented to the agent as additional tools — `BlockSenderIntent`, `ReportSpamIntent`, `ReadLastNotificationIntent`, `CallTrustedContactIntent` — so system-level actions become first-class members of the agent's toolbox. This extends the Toolformer [93] and AutoGen [94] paradigms to the iOS platform.

### 3.9 Privacy-First Architecture

By default, **no message content, call audio, screenshot, or contact record ever leaves the device**. Network calls are restricted to three narrow endpoints: (a) **Safe Browsing hash-prefix queries** (k-anonymous) [98], (b) **RDAP WHOIS** over HTTPS, and (c) **optional, user-initiated escalation** to a cloud A2A agent. Vector-DB keys are sealed in the **Secure Enclave** [61]. An **encrypted iCloud sync** option lets users restore their scam-report history across devices; the key never leaves local hardware. **Federated learning with local DP noise (DP-FedAvg)** is the long-term path for improving the shared model without ever collecting raw messages.

### 3.10 Accessibility for Elders and Non-Native Speakers

Gemma 4's **140+-language support** [67][68] is the linchpin of GemScan's accessibility plan. The UI launches with **voice-first interaction** in the user's OS language, a **high-contrast large-type visual mode**, and **single-button "Check this for me"** affordance invoked via Siri Shortcut, Share Sheet, or a lock-screen widget. When E4B produces a verdict, the Explainer Agent renders the reasoning in the user's native language at a sixth-grade reading level, with **culturally-aware warnings** (e.g., the Judge knows that an "RBI call" impersonation has a different shape in Hindi than a "CBI digital arrest" framing, and that the Japanese ore-ore pattern differs from the US grandparent scam). A **Trusted Contact Escalation** feature lets the user nominate an adult child or grandchild who receives a push notification when a high-risk event is detected, closing the social-proof loop that scammers deliberately isolate. This directly operationalises the LEP-vulnerability findings of Olivares-Pasillas [36] and AARP's multicultural fraud surveys [27][99].

### 3.11 iOS Extension Integration Points

GemScan ships four extensions, each linking **GemmaKit**:

1. **Message Filter Extension (`ILMessageFilterExtension`)** [80] — triggered only on SMS from non-contacts. Because the extension has a **~50 MB memory ceiling**, it cannot run E2B; it instead uses a **distilled DistilBERT Core ML classifier ≤ 5 MB** for the real-time allow/junk/promotion/transaction decision, following the distillation approach of ElZemity [53], and hands flagged messages to the main app via App Group for full E2B/E4B re-analysis.
2. **Call Directory Extension (`CXCallDirectoryExtension`)** — periodically regenerates a blocked-number list from the `phone_reputation` MCP server.
3. **Share Extension** — users can share any URL, message, or screenshot to GemScan; the extension defers to the main app via `NSFileCoordinator`.
4. **App Intents Extension** — exposes `CheckWithGemScanIntent`, `ReportScamIntent`, `BlockSenderIntent` to Siri, Shortcuts, and the system Action Button.

A **Safari Content Blocker** extension consumes declarative JSON rules generated by the main app from the user's flagged URLs.

### 3.12 Real-Time vs On-Demand Modes

GemScan has three screening modes. **Passive mode** runs the Message Filter extension and Call Directory only — zero main-app battery draw. **Active mode** keeps E2B resident for fast on-demand analysis of user-shared content. **Guardian mode** (requires user consent and is intended for elders or teens) additionally monitors inbound notifications via the **Focus/Notification Content Extension**, answers unknown calls with Siri-powered screening, and pre-scores clipboard URLs — while still never transmitting content off-device.

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
81. Capacitor Documentation. "Custom Native iOS Code." https://capacitorjs.com/docs/ios/custom-code
82. Anthropic. "Introducing the Model Context Protocol." November 2024. https://www.anthropic.com/news/model-context-protocol
83. Model Context Protocol Specification (2025-06-18 and November 2025 revisions). https://modelcontextprotocol.io/
84. Model Context Protocol Architecture. https://modelcontextprotocol.io/docs/learn/architecture
85. Model Context Protocol Transports. https://modelcontextprotocol.io/specification/2025-03-26/basic/transports
86. Anthropic. "MCP Swift SDK." https://github.com/modelcontextprotocol/swift-sdk
88. Google Developers Blog. "Announcing the Agent2Agent Protocol (A2A)." April 2025. https://developers.googleblog.com/en/a2a-a-new-era-of-agent-interoperability/
89. A2A Protocol. Version 1.0 Specification. https://a2a-protocol.org/latest/specification/
90. A2A Project. GitHub Repository. https://github.com/a2aproject/A2A
91. Linux Foundation. "Linux Foundation Launches the Agent2Agent Protocol Project." June 2025. https://www.linuxfoundation.org/press/linux-foundation-launches-the-agent2agent-protocol-project-to-enable-secure-intelligent-communication-between-ai-agents
92. Yao, S., et al. "ReAct: Synergizing Reasoning and Acting in Language Models." ICLR 2023. https://arxiv.org/abs/2210.03629
93. Schick, T., et al. "Toolformer: Language Models Can Teach Themselves to Use Tools." NeurIPS 2023. https://arxiv.org/abs/2302.04761
94. Wu, Q., et al. "AutoGen: Enabling Next-Gen LLM Applications via Multi-Agent Conversation Framework." arXiv:2308.08155, 2023.
96. llama.cpp GBNF Grammars. https://github.com/ggml-org/llama.cpp/blob/master/grammars/README.md
97. ObjectBox. On-Device Vector Search Documentation. https://docs.objectbox.io/on-device-vector-search
98. Google. Safe Browsing API v4 Documentation.
99. AARP. "Scams Take Toll on Older Asian American Pacific Islanders." FCC. https://www.fcc.gov/scams-take-toll-older-asian-american-pacific-islanders
