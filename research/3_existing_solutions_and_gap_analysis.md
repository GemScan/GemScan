# Existing Solutions and Gap Analysis

---

## Section 2 — Currently Available Solutions: Strengths and Weaknesses

### 2.1 Telecom-Carrier Defences

Carriers treat scam calls as a **network-level reputation problem**. **AT&T ActiveArmor** ships free with every wireless line — automatic fraud-call blocking, spam filtering, breach alerts — while the **Advanced tier ($7/month)** adds Caller ID, safe browsing, and identity-theft insurance. **Verizon Call Filter** offers free spam detection plus **Call Filter Plus ($3.99–10.99/month)** for a risk-scored Caller Name ID database. **T-Mobile Scam Shield** provides free Scam ID ("Scam Likely" tags) and Scam Block, with a **$4/month Premium** voicemail-routing tier; T-Mobile claims ML updates "every six minutes". Outside the US, **BT Call Protect** (UK) blocked 20 million+ scam calls in its first four months using Hiya's AI, and **Telstra Cleaner Pipes** (Australia) blocks **13 million+ scam calls and 23 million scam SMS monthly**.

All of these rest on **STIR/SHAKEN call authentication**, mandated by the US TRACED Act in 2019. STIR/SHAKEN attaches a cryptographically signed SIP identity header with attestation levels A (full), B (partial), or C (gateway). **The protocol does not stop scam calls — it only signals caller-ID trust.** International calls and complicit originating carriers routinely sign with C-level attestations, and SMS, OTT messaging, and VoIP are out of scope entirely.

**Weaknesses.** Carrier defences are (a) locked to subscribers, (b) overwhelmingly English-only, (c) blind to content — they see metadata, not semantics, (d) unable to analyse images, QR codes, or the audio inside a deepfake voice call, and (e) susceptible to both over-blocking legitimate callers and under-blocking spoofed live scammers.

### 2.2 Device-Level Built-In Protections

Apple's **Silence Unknown Callers** (iOS 13+) is an identity filter, not a scam classifier. **Filter Unknown Senders** in Messages uses on-device ML to sort unknown-sender SMS into Transactions/Promotions/Junk, and **iOS 26's Call Screening** lets Siri ask callers their reason before the user picks up — processed on-device. Google's **Pixel Scam Detection** (announced at I/O 2024, stable from March 2025) runs **Gemini Nano on-device** to analyse live call audio for scam patterns like "bank representative asking for gift cards", and has since expanded to **WhatsApp, Instagram, Signal, Messenger, KakaoTalk, Line, and X**. **Samsung Smart Call** uses Hiya's cloud to power caller ID on Galaxy devices (31 billion blocked fraud attempts in 2024).

**Weaknesses.** Apple's tools do not semantically reason about scams — iOS 26 Call Screening still admits any scammer willing to state a reason. Pixel Scam Detection is **Pixel-only and English-only**, with Gemini Nano's roughly 4 K context and 1.8–3.25 B parameters limiting multi-turn reasoning. Samsung's reliance on Hiya's cloud breaks offline use and raises privacy questions. **Apple Intelligence's Foundation Models framework (WWDC 2025) [74] requires iPhone 15 Pro or later**, excluding the hundreds of millions of iPhone 14-and-below devices where the vulnerable are most likely to live.

### 2.3 Third-Party Consumer Apps

The consumer-app landscape is crowded and deeply fragmented. A representative comparison:

| Solution | Languages | Multi-modal? | Privacy | Cost | Key weakness |
|---|---|---|---|---|---|
| Truecaller | 20+ UI | Calls + SMS + AI screener | Cloud + crowdsourced contacts | Free or $2.99/mo | Contact-book upload → regulatory probes in Nigeria (2025) and Sweden |
| Hiya Premium | English | Calls only | Cloud DB | $3.99/mo | Weak SMS; no semantic scam content analysis |
| RoboKiller | English | Call + SMS audio fingerprinting | Cloud | ~$39.99/yr | U.S.-centric |
| Nomorobo | English | Calls (SMS add-on) | Cloud (VoIP simultaneous ring) | $19.99/yr | Limited scope |
| Norton Genie | English (URL any lang) | Text + email + URL + video deepfake | Cloud (AWS) | Free standalone | English-only; messages uploaded |
| McAfee Scam Detector | English (US/UK/AU) | Text + email + URL + video deepfake | Primarily on-device | Bundled | AV-subscription gated |
| Bitdefender Scamio | Input any; output English | Text + image + URL (WhatsApp integration) | Cloud | Free | Output English-only |
| Aura | English | Calls + SMS + data-broker removal + AV + VPN | Cloud | $12–32/mo | U.S.-centric |
| Incogni | 34 countries | Broker removal only | Cloud | $4.19–14.99/mo | Not a live detector |

**Truecaller serves 450 million monthly active users on Android** and works by aggregating uploaded address books into a crowdsourced database — an approach that has drawn 2025 privacy-regulator probes in Nigeria and Sweden. **Norton Genie has 1 million+ installs and claims 90 %+ accuracy**, but sends message content to AWS. **McAfee Scam Detector — launched at CES January 2025 with on-device text analysis (>99 % accuracy) and deepfake-video detection (96 %) — is the closest current analogue to GemScan**, but lives behind McAfee+ subscriptions and supports only three English locales. **Bitdefender Scamio** accepts multilingual input but answers English-only, crippling its utility for LEP users.

### 2.4 AI-Based Detectors at the Frontier (2024–2026)

Beyond Pixel and McAfee, **Norton Genie Scam Protection Pro** (Feb 2025) added Safe Call, Safe Email OAuth linkage, and NPU-accelerated deepfake detection on AI PCs. **Microsoft Defender SmartScreen's Enhanced Phishing Protection** (Windows 11 22H2+) alerts when work passwords are typed into SmartScreen-flagged sites but only covers credential entry. **Google's Gmail** blocks >99.9 % of spam/phishing/malware across 15 billion unwanted messages daily, with RETVec text vectoring improving spam detection by **38 %** and reducing false positives by **19.4 %**. Despite these wins, **0.1 % miss rate at Gmail's scale still means roughly 15 million malicious emails per day slip through.**

### 2.5 Government and NGO Resources

**FTC ReportFraud, FBI IC3, UK Action Fraud, Scamwatch Australia, AARP Fraud Watch Network (877-908-3360), and Stop Scams UK's 159 service** all play valuable policy and post-hoc roles, but are **overwhelmingly reactive** — recording fraud after victimisation, pursuing macro-level enforcement, producing English-dominant educational material [3][5][12]. AARP's human-operated helpline is one of the few proactive channels, yet it is US-only and English-centric [27].

### 2.6 Academic Research Trajectory

Academic literature shows a clear arc. **URLTran (Maneriker et al. MILCOM 2021)** [42], **SpamBERT variants (Sahmoud & Mikki 2022 [43]; Jamal et al. 2024 [44])**, and **BERT-G3CN (Shen et al. 2025)** [45] established 98–99 % transformer-based accuracy on classical phishing/spam benchmarks. **KnowPhish (Li et al. USENIX Security 2024)** [46] fused a 20,000-brand multimodal knowledge graph with LLM brand-intent extraction to catch **2× more phishing pages** at **5× lower latency** than DynaPhish. **PhishAgent (Wang & Hooi 2024)** [48] and **MultiPhishGuard (Chataut et al. 2025, arXiv 2505.23803)** [51] proved that multi-agent LLM committees outperform single classifiers, especially under adversarial prompts; **PhishDebate (arXiv 2506.15656)** [52] and **PhishLumos (arXiv 2509.21772)** extend this to debate-style adjudication.

Work on smishing and scam-conversation modelling — **Salman et al. (2022, 2025)**, **SmishX (Mehdi et al. SOUPS 2024)** [54], **SpaLLM-Guard (arXiv 2501.04985)** [49], **ElZemity's Agentic Knowledge Distillation (arXiv 2602.10869)** [53] — demonstrated that distilled on-device student models can reach **94 % accuracy and 96 % recall** on SMS threats. On the inference side, **GPTQ (Frantar et al. ICLR 2023)** [55], **AWQ (Lin et al. MLSys 2024)** [56], **SmoothQuant (Xiao et al. ICML 2023)** [57], **MobileLLM (Liu et al. ICML 2024)** [58], and the Gemma technical reports [63][64][65] establish that **sub-4 B models with 4-bit weight-only quantisation match or exceed the cloud 7–13 B baselines of just eighteen months earlier**. Deepfake detection work — **AudioSeal (San Roman et al. ICML 2024)** [38], **ASVspoof 5 (Wang et al. 2024)** [39], **DeepSpeak v1.0 (Barrington et al. 2024)** [41], **Lin et al. CVPR 2024 on fairness** [40] — provides robust pipelines the application layer can call as tools.

### 2.7 Gap Analysis: What No Current Solution Does Well

Ten capability gaps persist:

1. **True on-device multi-modal reasoning** — only Pixel (English) and McAfee (subscription, three locales) ship it; no product unifies call audio, SMS, email, images, QR codes, and browser context under one offline model.
2. **Context-aware agentic protection** across multi-turn conversations (romance and pig-butchering campaigns unfold over weeks).
3. **Proactive inoculation and personalised education** in the user's native language.
4. **Deep multi-language support** — Norton Genie and Gemini Nano are English-only; Scamio takes multilingual input but replies in English.
5. **Real-time deepfake detection during live calls** — existing products detect file uploads, not streams [38][39].
6. **Unified cross-channel policy** across calls, SMS, email, DMs, web, and in-app.
7. **Privacy-preserving architecture** — nearly every competitor sends content to the cloud.
8. **Elderly-accessible UX** — voice-first interaction, high-contrast warnings, trusted-contact escalation.
9. **Banking-API integration** that can pause a transfer mid-scam conversation.
10. **Adversarial robustness** against prompt injection and novel TTS/voice-clone engines.

**GemScan is designed to close all ten.**

---

## References

3. FTC. "Protecting Older Consumers 2024-2025 Report to Congress." December 2025. https://www.ftc.gov/news-events/news/press-releases/2025/12/ftc-issues-annual-report-congress-agencys-actions-protect-older-adults
5. Federal Bureau of Investigation, Internet Crime Complaint Center. *2024 Internet Crime Report.* April 2025. https://www.ic3.gov/AnnualReport/Reports/2024_IC3Report.pdf
12. ACCC / National Anti-Scam Centre. *Targeting Scams Report 2024.* March 2025. https://www.scamwatch.gov.au/system/files/targeting-scams-report-2024.pdf
27. AARP. "Vital Voices: Fraud Concerns of Older Adults." 2025. https://www.aarp.org/pri/topics/aging-experience/demographics/vital-voices-fraud-concerns-older-adults.html
38. San Roman, R., Fernandez, P., et al. "Proactive Detection of Voice Cloning with Localized Watermarking (AudioSeal)." ICML 2024. https://arxiv.org/abs/2401.17264
39. Wang, X., Delgado, H., et al. "ASVspoof 5: Crowdsourced speech data, deepfakes, and adversarial attacks at scale." ASVspoof Workshop 2024. https://arxiv.org/abs/2408.08739
40. Lin, L., He, X., et al. "Preserving Fairness Generalization in Deepfake Detection." CVPR 2024.
41. Barrington, S., Bohacek, M., Farid, H. "DeepSpeak Dataset v1.0." arXiv:2408.05366, 2024.
42. Maneriker, P., et al. "URLTran: Improving Phishing URL Detection Using Transformers." MILCOM 2021. https://arxiv.org/abs/2106.05256
43. Sahmoud, T., Mikki, M. "Spam Detection Using BERT." arXiv:2206.02443, 2022.
44. Jamal, S., et al. "An Improved Transformer-based Model for Detecting Phishing, Spam and Ham Emails." *Security and Privacy*, 2024. https://arxiv.org/pdf/2311.04913
45. Shen, L., Wang, Y., Li, Z., Ma, W. "SMS Spam Detection Using BERT and Multi-Graph Convolutional Networks." 2025. https://www.sciencedirect.com/science/article/pii/S2666603025000089
46. Li, Y., et al. "KnowPhish: Large Language Models Meet Multimodal Knowledge Graphs." USENIX Security 2024. https://www.usenix.org/conference/usenixsecurity24/presentation/li-yuexin
48. Wang, Y., Hooi, B. "PhishAgent: A Robust Multimodal Agent for Phishing Webpage Detection." arXiv:2408.10738, 2024.
49. Salman, M., Ikram, M., Basta, N., Kaafar, M. A. "SpaLLM-Guard: Pairing SMS Spam Detection Using Open-source and Commercial LLMs." arXiv:2501.04985, 2025.
51. Chataut, R., et al. "MultiPhishGuard: An LLM-based Multi-Agent System for Phishing Email Detection." arXiv:2505.23803, 2025.
52. "PhishDebate: An LLM-Based Multi-Agent Framework for Phishing Website Detection." arXiv:2506.15656, 2025.
53. ElZemity, A. "Agentic Knowledge Distillation: Autonomous Training of Small Language Models for SMS Threat Detection." arXiv:2602.10869, 2026.
54. Mehdi, S., et al. "SmishX: Explainable SMS Phishing Detection using LLM-Based Agents." SOUPS 2024.
55. Frantar, E., Ashkboos, S., Hoefler, T., Alistarh, D. "GPTQ: Accurate Post-Training Quantization for Generative Pre-trained Transformers." ICLR 2023. https://arxiv.org/abs/2210.17323
56. Lin, J., Tang, J., et al. "AWQ: Activation-aware Weight Quantization for LLM Compression and Acceleration." MLSys 2024. https://arxiv.org/abs/2306.00978
57. Xiao, G., Lin, J., et al. "SmoothQuant: Accurate and Efficient Post-Training Quantization for LLMs." ICML 2023. https://arxiv.org/abs/2211.10438
58. Liu, Z., Zhao, C., et al. "MobileLLM: Optimizing Sub-billion Parameter Language Models for On-Device Use Cases." ICML 2024. https://arxiv.org/abs/2402.14905
63. Gemma Team / Google DeepMind. "Gemma: Open Models Based on Gemini Research and Technology." arXiv:2403.08295, 2024.
64. Gemma Team. "Gemma 2 Technical Report." arXiv:2408.00118, 2024.
65. Gemma Team. "Gemma 3 Technical Report." arXiv:2503.19786, 2025.
67. Google AI Edge Team. "Bring State-of-the-Art Agentic Skills to the Edge with Gemma 4." April 2026. https://developers.googleblog.com/bring-state-of-the-art-agentic-skills-to-the-edge-with-gemma-4/
68. Hugging Face. "Welcome Gemma 4: Frontier Multimodal Intelligence on Device." 2026. https://huggingface.co/blog/gemma4
69. Google. "Gemma 4: Byte for Byte, the Most Capable Open Models." 2026. https://blog.google/innovation-and-ai/technology/developers-tools/gemma-4/
74. Apple. "Introducing Apple's On-Device and Server Foundation Models." 2024. https://machinelearning.apple.com/research/introducing-apple-foundation-models
