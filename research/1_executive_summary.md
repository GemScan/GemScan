# GemScan: On-Device Agentic Defense With Gemma 4

**A Hackathon Thesis for the Gemma 4 Good Hackathon (Google / Kaggle)**

*A privacy-first, multi-modal, multi-lingual mobile application (iOS demo; Android-compatible architecture) that uses Gemma 4 E2B and E4B with Model Context Protocol (MCP) and a platform-native multi-agent orchestrator to protect vulnerable youngsters and elders from scams.*

---

## Executive Summary

**Scams now steal more than US$1 trillion globally every year, and generative AI has industrialised the production of convincing fakes in every major language.** The FTC logged **$12.5 billion in 2024 US fraud losses (+25% YoY)** [1][2], the FBI IC3 recorded **$16.6 billion (+33% YoY)** [5], and elder-fraud losses jumped **43% to $4.885 billion** [7]. Meanwhile, youth sextortion drove at least **20 documented suicides of minors** between October 2021 and March 2023 [33][35], and Southeast-Asian pig-butchering compounds — staffed by **220,000–300,000 trafficked workers** [16] — generated an estimated **$63.9 billion in 2023 alone** [16]. Current defences are fragmented, English-centric, cloud-dependent, single-modal, and reactive. **No consumer solution today combines on-device reasoning, multi-modal analysis, agentic orchestration, and native-language coaching for both elders and youth on budget iPhones.**

This thesis proposes **GemScan**, a Next.js-plus-Capacitor mobile application that ships Gemma 4 E2B (~2.3 B effective parameters) as an always-on screening agent and Gemma 4 E4B (~4.5 B effective parameters) as a deeper-reasoning agent, both running entirely on-device. The demo build runs on iOS via Apple's MLX Swift framework [77][78]; the architecture is runtime-agnostic, with Android supported via LiteRT-LM and the same GGUF model artifacts. A six-agent architecture orchestrated by a platform-native in-process message router and querying in-process MCP servers [82][83] unifies call, SMS, email, URL, screenshot, and voice analysis under one explainable, multilingual, voice-first user interface. We hypothesise — and plan to demonstrate — that GemScan's E4B agent can reach ≥ 92 % F1 on composite scam-detection benchmarks while consuming ≤ 3 GB RAM and preserving battery at a cost of < 6 % per hour of active screening on an A15 iPhone 14. By proving that a 2–4 B-parameter open model running fully offline can match cloud-scale defensive systems [67][68][69], this work establishes a new paradigm for equitable, culturally competent scam protection.

---

## References

1. Federal Trade Commission. *Consumer Sentinel Network Data Book 2024.* 2025. https://www.ftc.gov/system/files/ftc_gov/pdf/csn-annual-data-book-2024.pdf
2. FTC Press Release. "New FTC Data Show Big Jump in Reported Losses to Fraud to $12.5 Billion in 2024." March 2025. https://www.ftc.gov/news-events/news/press-releases/2025/03/new-ftc-data-show-big-jump-reported-losses-fraud-125-billion-2024
5. Federal Bureau of Investigation, Internet Crime Complaint Center. *2024 Internet Crime Report.* April 2025. https://www.ic3.gov/AnnualReport/Reports/2024_IC3Report.pdf
7. FBI IC3. *Elder Fraud Tri-Fold 2025.* https://www.ic3.gov/Outreach/Brochures/elder_fraud_tri-fold.pdf
16. U.S.-China Economic and Security Review Commission. *China's Exploitation of Scam Centers in Southeast Asia.* July 2025. https://www.uscc.gov/sites/default/files/2025-07/Chinas_Exploitation_of_Scam_Centers_in_Southeast_Asia.pdf
33. FBI. "Sextortion: A Growing Threat Targeting Minors." https://www.fbi.gov/contact-us/field-offices/nashville/news/sextortion-a-growing-threat-targeting-minors
35. Thorn & NCMEC. *Trends in Financial Sextortion.* June 2024. https://info.thorn.org/hubfs/Research/Thorn_TrendsInFinancialSextortion_June2024.pdf
67. Google AI Edge Team. "Bring State-of-the-Art Agentic Skills to the Edge with Gemma 4." April 2026. https://developers.googleblog.com/bring-state-of-the-art-agentic-skills-to-the-edge-with-gemma-4/
68. Hugging Face. "Welcome Gemma 4: Frontier Multimodal Intelligence on Device." 2026. https://huggingface.co/blog/gemma4
69. Google. "Gemma 4: Byte for Byte, the Most Capable Open Models." 2026. https://blog.google/innovation-and-ai/technology/developers-tools/gemma-4/
77. Swift.org. "On-device ML research with MLX and Swift." 2024. https://www.swift.org/blog/mlx-swift/
78. Apple ml-explore. "mlx-swift." https://github.com/ml-explore/mlx-swift
82. Anthropic. "Introducing the Model Context Protocol." November 2024. https://www.anthropic.com/news/model-context-protocol
83. Model Context Protocol Specification (2025-06-18 and November 2025 revisions). https://modelcontextprotocol.io/
