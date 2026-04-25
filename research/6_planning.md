# Planning

---

## Section 4.1 — Hackathon Execution Timeline

The full build is scoped to **2 weeks**. Training runs (E2B, E4B, DistilBERT) are kicked off on Day 1 and run in parallel with infrastructure work, so model artifacts are ready by mid-Week 1 without blocking the app build.

| Day(s) | Track | Milestone |
|---|---|---|
| **1** | Infra + Models | Fetch Gemma 4 E2B/E4B weights from Kaggle [67][68]; verify GGUF artifacts boot via llama.cpp and MLX Swift [77][78]; kick off E2B QLoRA fine-tune on Kaggle T4 and DistilBERT SMS triage training in parallel [72]; stand up Capacitor + Next.js shell [81]. |
| **2** | App shell | Implement `GemmaPlugin` with streaming token notifications; smoke-test end-to-end prompt → token stream in WebView on iOS simulator and Android emulator; confirm E2B training run is healthy. |
| **3** | Models + MCP | E2B fine-tune completes — spot-check accuracy, export GGUF + MLX 4-bit [55][56]; kick off E4B QLoRA on A100 [72]; implement MCP servers `scam_patterns`, `sqlite_vec`, `url_reputation`, `whois` (Swift + Kotlin) [82][83][86]. |
| **4** | MCP + Agents | E4B fine-tune completes — merge, export, calibrate E2B→E4B threshold (§4.4); implement remaining MCP servers (`contacts`, `reverse_image`, `phone_reputation`, `clipboard_watcher`, `screen_time`); wire six-agent Orchestrator via platform-native message router with GBNF-constrained decoding [96]. |
| **5** | Platform layer | iOS: SMS Filter extension (DistilBERT Core ML, ≤ 5 MB) [53][80], Call Directory, Share Extension, App Intents. Android: SmsRetriever, CallScreeningService, Share intent, App Actions. Verify chat-template parity between Python tokeniser and on-device tokeniser. |
| **6** | UX + Accessibility | Voice-first UI, Guardian mode consent flow (self-enrolment + caregiver-assisted), Trusted Contact push notifications, multi-language Explainer (sixth-grade reading level, 140+ languages) [67]; high-contrast large-type visual mode. |
| **7** | Integration + Testing | Full end-to-end integration test on physical iPhone 14 and mid-range Android device; latency, memory, and battery benchmarks (§4.4) [62]; adversarial prompt-injection suite [87]; fix critical bugs. |
| **8–9** | User testing | Structured sessions with ≥ 10 elders (mean age 70+) and ≥ 10 non-native speakers across ≥ 3 languages (§4.5); iterate on UX, warning copy, and threshold based on task-completion and comprehension results. |
| **10–11** | Polish + Submission | Final accuracy benchmarks; TestFlight beta upload; hackathon submission video (demo of Share Sheet, Guardian mode, and multilingual Explainer); thesis final edit. |
| **12–14** | Buffer | Reserved for regression fixes, App Store privacy-manifest review, and any test-participant scheduling slippage. |

---

## Section 6 — Expected Results

### 6.1 Quantitative Performance Targets

| Metric | E2B-only | E4B-only | Full agentic stack |
|---|---|---|---|
| Precision (English scam corpus) | 94 % | 96 % | **97 %** |
| Recall (English scam corpus) | 86 % | 91 % | **94 %** |
| F1 (composite multilingual) | 87 % | 92 % | **94 %** |
| F1 (multi-modal adversarial corpus) | 78 % | 85 % | **91 %** |
| First-token latency (iPhone 14) | **≤ 400 ms** | ≤ 900 ms | ≤ 1.2 s |
| End-to-end Share-Sheet decision | ≤ 1.5 s | ≤ 3.5 s | **≤ 5 s** |
| Peak RSS (iPhone 14, 6 GB) | **≤ 2.3 GB** | ≤ 3.2 GB (swap-tolerant) | pipelined ≤ 3.5 GB |
| Battery drain in Active mode | ≤ 4 %/h | ≤ 7 %/h | **≤ 6 %/h average** |
| Battery drain in Guardian mode | ≤ 8 %/h | — | — |

These targets are grounded in extrapolations from **llama.cpp A-series benchmarks (Mistral-7B Q4 at 5–10 tok/s)** [96] scaled by parameter ratio, corroborated by community reports of Gemma 4 E2B running on iPhone 13 Pro via MLX Swift [77][78], and by Google's cited **3,700 prefill / 31 decode tok/s** on Qualcomm Dragonwing IQ8 NPUs [67].

### 6.2 Qualitative Outcomes

In the user study we expect (a) **≥ 80 % elder task-completion rate** on the Share-Sheet flow versus a pre-registered ~40 % baseline with typical iOS security UIs; (b) **≥ 4.2/5 average comprehension rating** for the native-language Explainer output; (c) **Net Promoter Score ≥ +30** from both elder and LEP cohorts; (d) qualitative evidence that the **Trusted Contact Escalation** feature is valued as a "second opinion" that breaks the isolation scammers engineer.

### 6.3 Societal-Impact Projections

If GemScan reaches even **1 % of the roughly 3.5 billion mid-range and budget smartphone users globally** (the segment on which vulnerable populations predominantly rely) and reduces victimisation in that population by **one-third** — a conservative figure relative to the **30 % false-negative reduction demonstrated by agentic systems in the literature** [52][53] — the annualised financial-loss prevention is on the order of **$2–4 billion** against GASA's $1.03 trillion global baseline [13]. The mental-health benefit, though harder to quantify, is anchored in peer-reviewed evidence (Button 2014; Lichtenberg FINCHES [31]; Sarriá 2019; Kircanski [32]) that every prevented scam is a prevented depression, anxiety, or — in the sextortion case — suicide risk. For LEP and elderly populations specifically, GemScan's multilingual voice-first UI is expected to **close the 2.8× voice-scam vulnerability gap** documented for LEP users [36] and the **38 %-vs-16 % overrepresentation of 65+ adults among voice-scam victims** [7][3].

### 6.4 Comparison to Existing Solutions

| Dimension | Pixel Scam Det. | McAfee SD | Norton Genie | Truecaller | Bitdefender Scamio | **GemScan** |
|---|---|---|---|---|---|---|
| Fully on-device | ✔ | ✔ (mostly) | ✘ | ✘ | ✘ | **✔** |
| Multi-modal (text+URL+image+audio) | partial | ✔ | ✔ | partial | ✔ | **✔** |
| Multi-language reasoning | ✘ English | ✘ 3 locales | ✘ English | UI only | input only | **✔ 140+** |
| Agentic (MCP + actor orchestration) | ✘ | ✘ | ✘ | ✘ | ✘ | **✔** |
| Works on mid-range iOS + Android | ✘ Pixel only | ✔ iOS only | ✔ | ✔ | ✔ | **✔ both** |
| Explanations in user's native language | ✘ | partial | ✘ | ✘ | ✘ | **✔** |
| Trusted-contact escalation | ✘ | ✘ | ✘ | ✘ | ✘ | **✔** |
| Open-source weights + code | ✘ | ✘ | ✘ | ✘ | ✘ | **✔** |

### 6.5 Path to Production and Scaling

Post-hackathon, the roadmap is four-fold. **Production (months 1–3):** iOS TestFlight public beta and App Store submission; Android Play Console internal track and Play Store submission; hardening of MCP permission scopes [83]; platform privacy-manifest compliance on both stores. **Cross-platform (months 3–9):** Capacitor Android build [81] targeting LiteRT-LM / MediaPipe LLM Inference runtime is developed in parallel with iOS and targeted for release by month 6; Progressive Web App fallback for desktop review use cases; desktop Electron build for caregivers. **Federation (months 9–18):** Optional cloud threat-intelligence agent (the Swift actor interface is serialisation-ready for promotion to a remote endpoint over A2A); DP-FedAvg federated learning for continual model improvement; partnerships with carrier scam-reporting APIs (T-Mobile Scam Shield, BT Call Protect) and banking APIs for mid-scam transaction pausing. **Research (continuous):** Collaboration with AARP Fraud Watch [27], Thorn [34], and LEP immigrant-services non-profits to release anonymised, consented scam corpora as public goods, and to co-author peer-reviewed evaluation studies following the benchmarking protocol of §4.4 (see implementation_methodology.md).

---

## Conclusion

**Three forces have converged in 2024–2026: scams have become a trillion-dollar transnational industry [13], generative AI has trivialised their production [20][22][24], and open on-device models have matured enough to fight back [55][56][57][58].** Gemma 4 E2B and E4B — 2.3 B and 4.5 B effective parameters, multi-modal text+image+audio, 128 K context, 140+ languages, Apache 2.0 licensed, and empirically outperforming Gemma 3 27B on agentic tool-use tasks while fitting on an iPhone 14 [67][68][69] — represent the first moment at which a privacy-first, multilingual, voice-first, agentic consumer scam-defence app is technically viable on a mainstream budget device.

GemScan is the concrete realisation of that opportunity. By combining (i) a two-model tiered architecture, (ii) a six-agent MCP-backed orchestration with a platform-native message router [82][83], (iii) native-language explanations and trusted-contact escalation, and (iv) a strict on-device privacy posture, it closes the ten capability gaps that existing commercial and academic solutions collectively leave open. The hypotheses in §5 are rigorous and falsifiable; the methodology in §4 is executable within a hackathon timeline; the expected results in §6 are bold but grounded in extrapolations from published benchmarks. If validated, GemScan would establish a new class of **on-device protective agents** — ones that belong *to* and run *for* their user, not a cloud vendor — and demonstrate that the most vulnerable populations globally can finally receive first-class, equitable, culturally competent protection from the fastest-growing crime on Earth.

*The twenty-first-century scammer has an AI. Until now, the twenty-first-century grandmother has not. GemScan changes that.*

---

## References

> Full master reference list (all 100 entries) is reproduced here. Each entry appears in at least one document in this research series.

1. Federal Trade Commission. *Consumer Sentinel Network Data Book 2024.* 2025. https://www.ftc.gov/system/files/ftc_gov/pdf/csn-annual-data-book-2024.pdf
2. FTC Press Release. "New FTC Data Show Big Jump in Reported Losses to Fraud to $12.5 Billion in 2024." March 2025. https://www.ftc.gov/news-events/news/press-releases/2025/03/new-ftc-data-show-big-jump-reported-losses-fraud-125-billion-2024
3. FTC. "Protecting Older Consumers 2024-2025 Report to Congress." December 2025. https://www.ftc.gov/news-events/news/press-releases/2025/12/ftc-issues-annual-report-congress-agencys-actions-protect-older-adults
4. FTC. "Paying to Get Paid: Gamified Job Scams Drive Record Losses." December 2024. https://www.ftc.gov/news-events/data-visualizations/data-spotlight/2024/12/paying-get-paid-gamified-job-scams-drive-record-losses
5. Federal Bureau of Investigation, Internet Crime Complaint Center. *2024 Internet Crime Report.* April 2025. https://www.ic3.gov/AnnualReport/Reports/2024_IC3Report.pdf
6. FBI IC3. *2023 Internet Crime Report.* 2024. https://www.aha.org/system/files/media/file/2024/03/fbi-internet-crime-report-2023.pdf
7. FBI IC3. *Elder Fraud Tri-Fold 2025.* https://www.ic3.gov/Outreach/Brochures/elder_fraud_tri-fold.pdf
8. FBI. "Chinese Police Imposter Scam PSA." IC3 PSA 240103, January 2024. https://www.ic3.gov/PSA/2024/PSA240103
9. UK Finance. *Annual Fraud Report 2025.* May 2025. https://www.ukfinance.org.uk/system/files/2025-05/UK%20Finance%20Annual%20Fraud%20report%202025.pdf
10. RSM UK. "Fraud loss reaches £2.3 billion as fraudsters become increasingly sophisticated." 2025. https://www.rsmuk.com/news/fraud-loss-reaches-2-point-3-billion-fraudsters-become-increasingly-sophisticated
11. Cifas / GASA. *State of Scams UK 2024.* https://www.cifas.org.uk/newsroom/gasa-stateofscamsuk2024
12. ACCC / National Anti-Scam Centre. *Targeting Scams Report 2024.* March 2025. https://www.scamwatch.gov.au/system/files/targeting-scams-report-2024.pdf
13. Global Anti-Scam Alliance / Feedzai. *Global State of Scams Report 2024.* 2024. https://www.gasa.org/post/global-state-of-scams-report-2024-1-trillion-stolen-in-12-months-gasa-feedzai
14. Chainalysis. *2025 Crypto Crime Report.* 2025. https://www.chainalysis.com/blog/2025-crypto-crime-report-introduction/
15. Chainalysis. "2024 Pig Butchering Scam Revenue Grows YoY." 2025. https://www.chainalysis.com/blog/2024-pig-butchering-scam-revenue-grows-yoy/
16. U.S.-China Economic and Security Review Commission. *China's Exploitation of Scam Centers in Southeast Asia.* July 2025. https://www.uscc.gov/sites/default/files/2025-07/Chinas_Exploitation_of_Scam_Centers_in_Southeast_Asia.pdf
17. Interpol. "Operation HAECHI V: Record 5,500 arrests, $400 M seized." 2024. https://www.interpol.int/News-and-Events/News/2024/INTERPOL-financial-crime-operation-makes-record-5-500-arrests-seizures-worth-over-USD-400-million
18. CNN. "Finance Worker Pays Out $25 M in Deepfake Scam." May 16, 2024. https://www.cnn.com/2024/05/16/tech/arup-deepfake-scam-loss-hong-kong-intl-hnk
19. Fortune. "Arup Deepfake Fraud Scam Victim Hong Kong 25 Million CFO." May 17, 2024. https://fortune.com/europe/2024/05/17/arup-deepfake-fraud-scam-victim-hong-kong-25-million-cfo/
20. Heiding, F., Schneier, B., Vishwanath, A., Bernstein, J., Park, P. S. "Devising and Detecting Phishing Emails Using Large Language Models." *IEEE Access* 12, 2024. https://ieeexplore.ieee.org/document/10466545
21. Harvard Business Review. "AI Will Increase the Quantity — and Quality — of Phishing Scams." May 2024. https://hbr.org/2024/05/ai-will-increase-the-quantity-and-quality-of-phishing-scams
22. Krebs, B. "Meet the Brains Behind the Malware-Friendly AI Chat Service WormGPT." KrebsOnSecurity, August 2023. https://krebsonsecurity.com/2023/08/meet-the-brains-behind-the-malware-friendly-ai-chat-service-wormgpt/
23. CATO Networks CTRL / CSO Online. "WormGPT returns: new malicious AI variants built on Grok and Mixtral uncovered." March 2025. https://www.csoonline.com/article/4008912/wormgpt-returns-new-malicious-ai-variants-built-on-grok-and-mixtral-uncovered.html
24. LevelBlue. "WormGPT and FraudGPT: The Rise of Malicious LLMs." https://www.levelblue.com/blogs/spiderlabs-blog/wormgpt-and-fraudgpt-the-rise-of-malicious-llms
25. Netenrich. "FraudGPT: The Villain Avatar of ChatGPT." July 2023. https://netenrich.com/blog/fraudgpt-the-villain-avatar-of-chatgpt
26. AARP Public Policy Institute (Gunther, J.). *Scope of Elder Financial Exploitation.* June 2023. https://doi.org/10.26419/ppi.00194.001
27. AARP. "Vital Voices: Fraud Concerns of Older Adults." 2025. https://www.aarp.org/pri/topics/aging-experience/demographics/vital-voices-fraud-concerns-older-adults.html
28. Burnes, D., Henderson, C. R., et al. "Prevalence of Financial Fraud and Scams Among Older Adults in the United States." *American Journal of Public Health*, 2017. https://pmc.ncbi.nlm.nih.gov/articles/PMC5508139/
29. Peterson, J. C., Burnes, D. P., et al. "Financial Exploitation of Older Adults: A Population-Based Prevalence Study." *Journal of General Internal Medicine*, 2014. https://pubmed.ncbi.nlm.nih.gov/25103121/
30. Han, S. D., Boyle, P. A., et al. "Cognitive and Neuroimaging Correlates of Financial Exploitation Vulnerability in Older Adults." *Neuroscience & Biobehavioral Reviews*, 2023. https://pmc.ncbi.nlm.nih.gov/articles/PMC9815424/
31. Lichtenberg et al. "FINCHES Mental Health Study." https://pmc.ncbi.nlm.nih.gov/articles/PMC6933096/
32. Kircanski, K. et al. "Emotional Arousal May Increase Susceptibility to Fraud." https://pmc.ncbi.nlm.nih.gov/articles/PMC6005691/
33. FBI. "Sextortion: A Growing Threat Targeting Minors." https://www.fbi.gov/contact-us/field-offices/nashville/news/sextortion-a-growing-threat-targeting-minors
34. Thorn. *Sexual Extortion & Young People: Navigating Threats in Digital Environments.* June 2025. https://info.thorn.org/hubfs/Research/Thorn_SexualExtortionandYoungPeople_June2025.pdf
35. Thorn & NCMEC. *Trends in Financial Sextortion.* June 2024. https://info.thorn.org/hubfs/Research/Thorn_TrendsInFinancialSextortion_June2024.pdf
36. Olivares-Pasillas, M. C., et al. "Insurgent Citizenship: How Consumer Complaints on Immigration Scams Inform Policy." *Georgetown Immigration Law Journal*, 2024. https://www.law.georgetown.edu/immigration-law-journal/wp-content/uploads/sites/19/2024/03/GT-GILJ230012-1.pdf
37. Barua, R., Koorma, G., Barrington, S., Farid, H. "Single and Multi-Speaker Cloned Voice Detection." arXiv:2307.07683, 2023.
38. San Roman, R., Fernandez, P., et al. "Proactive Detection of Voice Cloning with Localized Watermarking (AudioSeal)." ICML 2024. https://arxiv.org/abs/2401.17264
39. Wang, X., Delgado, H., et al. "ASVspoof 5: Crowdsourced speech data, deepfakes, and adversarial attacks at scale." ASVspoof Workshop 2024. https://arxiv.org/abs/2408.08739
40. Lin, L., He, X., et al. "Preserving Fairness Generalization in Deepfake Detection." CVPR 2024.
41. Barrington, S., Bohacek, M., Farid, H. "DeepSpeak Dataset v1.0." arXiv:2408.05366, 2024.
42. Maneriker, P., et al. "URLTran: Improving Phishing URL Detection Using Transformers." MILCOM 2021. https://arxiv.org/abs/2106.05256
43. Sahmoud, T., Mikki, M. "Spam Detection Using BERT." arXiv:2206.02443, 2022.
44. Jamal, S., et al. "An Improved Transformer-based Model for Detecting Phishing, Spam and Ham Emails." *Security and Privacy*, 2024. https://arxiv.org/pdf/2311.04913
45. Shen, L., Wang, Y., Li, Z., Ma, W. "SMS Spam Detection Using BERT and Multi-Graph Convolutional Networks." 2025. https://www.sciencedirect.com/science/article/pii/S2666603025000089
46. Li, Y., et al. "KnowPhish: Large Language Models Meet Multimodal Knowledge Graphs." USENIX Security 2024. https://www.usenix.org/conference/usenixsecurity24/presentation/li-yuexin
47. Lee, J., Xin, P., See-To, M. N., Hooi, B. "Multimodal Large Language Models for Phishing Webpage Detection and Identification." APWG eCrime 2024. https://arxiv.org/abs/2408.05941
48. Wang, Y., Hooi, B. "PhishAgent: A Robust Multimodal Agent for Phishing Webpage Detection." arXiv:2408.10738, 2024.
49. Salman, M., Ikram, M., Basta, N., Kaafar, M. A. "SpaLLM-Guard: Pairing SMS Spam Detection Using Open-source and Commercial LLMs." arXiv:2501.04985, 2025.
50. Nahmias, D., Engelberg, G., Klein, D., Shabtai, A. "Enhancing Phishing Email Identification with Large Language Models (APOLLO)." arXiv:2502.04759, 2024.
51. Chataut, R., et al. "MultiPhishGuard: An LLM-based Multi-Agent System for Phishing Email Detection." arXiv:2505.23803, 2025.
52. "PhishDebate: An LLM-Based Multi-Agent Framework for Phishing Website Detection." arXiv:2506.15656, 2025.
53. ElZemity, A. "Agentic Knowledge Distillation: Autonomous Training of Small Language Models for SMS Threat Detection." arXiv:2602.10869, 2026.
54. Mehdi, S., et al. "SmishX: Explainable SMS Phishing Detection using LLM-Based Agents." SOUPS 2024.
55. Frantar, E., Ashkboos, S., Hoefler, T., Alistarh, D. "GPTQ: Accurate Post-Training Quantization for Generative Pre-trained Transformers." ICLR 2023. https://arxiv.org/abs/2210.17323
56. Lin, J., Tang, J., et al. "AWQ: Activation-aware Weight Quantization for LLM Compression and Acceleration." MLSys 2024. https://arxiv.org/abs/2306.00978
57. Xiao, G., Lin, J., et al. "SmoothQuant: Accurate and Efficient Post-Training Quantization for LLMs." ICML 2023. https://arxiv.org/abs/2211.10438
58. Liu, Z., Zhao, C., et al. "MobileLLM: Optimizing Sub-billion Parameter Language Models for On-Device Use Cases." ICML 2024. https://arxiv.org/abs/2402.14905
59. Abdin, M., et al. "Phi-3 Technical Report: A Highly Capable Language Model Locally on Your Phone." arXiv:2404.14219, 2024.
60. Xu, J., Li, Z., et al. "On-Device Language Models: A Comprehensive Review." arXiv:2409.00088, 2024.
61. Yang, H., Zhang, D., et al. "A First Look at Efficient and Secure On-Device LLM Inference Against KV Leakage." ACM MobiArch 2024. https://arxiv.org/abs/2409.04040
62. Ajayi, O. A., Ahmad, I. "Benchmarking On-Device Machine Learning on Apple Silicon with MLX." arXiv:2510.18921, 2024.
63. Gemma Team / Google DeepMind. "Gemma: Open Models Based on Gemini Research and Technology." arXiv:2403.08295, 2024.
64. Gemma Team. "Gemma 2 Technical Report." arXiv:2408.00118, 2024.
65. Gemma Team. "Gemma 3 Technical Report." arXiv:2503.19786, 2025.
66. Google. "Introducing Gemma 3n: Mobile-First Multimodal AI." Developer Blog, 2025. https://developers.googleblog.com/en/introducing-gemma-3n-developer-guide/
67. Google AI Edge Team. "Bring State-of-the-Art Agentic Skills to the Edge with Gemma 4." April 2026. https://developers.googleblog.com/bring-state-of-the-art-agentic-skills-to-the-edge-with-gemma-4/
68. Hugging Face. "Welcome Gemma 4: Frontier Multimodal Intelligence on Device." 2026. https://huggingface.co/blog/gemma4
69. Google. "Gemma 4: Byte for Byte, the Most Capable Open Models." 2026. https://blog.google/innovation-and-ai/technology/developers-tools/gemma-4/
70. Yvinec, E., Culliton, P. "Gemma 3 QAT Models." Google Developers Blog, 2025. https://developers.googleblog.com/en/gemma-3-quantized-aware-trained-state-of-the-art-ai-to-consumer-gpus/
71. Google AI. "Function Calling with Gemma 4." 2026. https://ai.google.dev/gemma/docs/capabilities/text/function-calling-gemma4
72. Unsloth. "Gemma 4 Fine-tuning Guide." 2026. https://unsloth.ai/docs/models/gemma-4/train
73. Apple Machine Learning Research. "Deploying Transformers on the Apple Neural Engine." 2022. https://machinelearning.apple.com/research/neural-engine-transformers
74. Apple. "Introducing Apple's On-Device and Server Foundation Models." 2024. https://machinelearning.apple.com/research/introducing-apple-foundation-models
75. Apple. Core ML Tools Documentation. https://apple.github.io/coremltools/docs-guides/
76. Apple. ExecuTorch Core ML Backend Documentation. https://docs.pytorch.org/executorch/0.7/backends-coreml.html
77. Swift.org. "On-device ML research with MLX and Swift." 2024. https://www.swift.org/blog/mlx-swift/
78. Apple ml-explore. "mlx-swift." https://github.com/ml-explore/mlx-swift
79. MLC AI. "MLC LLM: Universal LLM Deployment." https://llm.mlc.ai/
80. Apple Developer. "ILMessageFilterExtension." https://developer.apple.com/documentation/sms_and_call_reporting/ilmessagefilterextension
81. Capacitor Documentation. "Custom Native iOS Code." https://capacitorjs.com/docs/ios/custom-code
82. Anthropic. "Introducing the Model Context Protocol." November 2024. https://www.anthropic.com/news/model-context-protocol
83. Model Context Protocol Specification (2025-06-18 and November 2025 revisions). https://modelcontextprotocol.io/
84. Model Context Protocol Architecture. https://modelcontextprotocol.io/docs/learn/architecture
85. Model Context Protocol Transports. https://modelcontextprotocol.io/specification/2025-03-26/basic/transports
86. Anthropic. "MCP Swift SDK." https://github.com/modelcontextprotocol/swift-sdk
87. Hou et al. "MCP Security Analysis." arXiv:2503.23278, 2025.
88. Google Developers Blog. "Announcing the Agent2Agent Protocol (A2A)." April 2025. https://developers.googleblog.com/en/a2a-a-new-era-of-agent-interoperability/
89. A2A Protocol. Version 1.0 Specification. https://a2a-protocol.org/latest/specification/
90. A2A Project. GitHub Repository. https://github.com/a2aproject/A2A
91. Linux Foundation. "Linux Foundation Launches the Agent2Agent Protocol Project." June 2025. https://www.linuxfoundation.org/press/linux-foundation-launches-the-agent2agent-protocol-project-to-enable-secure-intelligent-communication-between-ai-agents
92. Yao, S., et al. "ReAct: Synergizing Reasoning and Acting in Language Models." ICLR 2023. https://arxiv.org/abs/2210.03629
93. Schick, T., et al. "Toolformer: Language Models Can Teach Themselves to Use Tools." NeurIPS 2023. https://arxiv.org/abs/2302.04761
94. Wu, Q., et al. "AutoGen: Enabling Next-Gen LLM Applications via Multi-Agent Conversation Framework." arXiv:2308.08155, 2023.
95. Hong, S., et al. "MetaGPT: Meta Programming for A Multi-Agent Collaborative Framework." ICLR 2024. https://arxiv.org/abs/2308.00352
96. llama.cpp GBNF Grammars. https://github.com/ggml-org/llama.cpp/blob/master/grammars/README.md
97. ObjectBox. On-Device Vector Search Documentation. https://docs.objectbox.io/on-device-vector-search
98. Google. Safe Browsing API v4 Documentation.
99. AARP. "Scams Take Toll on Older Asian American Pacific Islanders." FCC. https://www.fcc.gov/scams-take-toll-older-asian-american-pacific-islanders
100. FTC. "Visit FTC.gov/Languages for Fraud & Scam Advice in 12 Languages." 2023. https://consumer.ftc.gov/consumer-alerts/2023/02/visit-ftcgovlanguages-fraud-scam-advice-12-languages
