# ScamGuard: On-Device Agentic Defense With Gemma 4

**A Hackathon Thesis for the Gemma 4 Good Hackathon (Google / Kaggle)**

*A privacy-first, multi-modal, multi-lingual iOS application that uses Gemma 4 E2B and E4B with Model Context Protocol (MCP) and Agent-to-Agent (A2A) orchestration to protect vulnerable youngsters and elders from scams.*

---

## Executive summary

**Scams now steal more than US$1 trillion globally every year, and generative AI has industrialised the production of convincing fakes in every major language.** The FTC logged **$12.5 billion in 2024 US fraud losses (+25% YoY)**, the FBI IC3 recorded **$16.6 billion (+33% YoY)**, and elder-fraud losses jumped **43% to $4.885 billion**. Meanwhile, youth sextortion drove at least **20 documented suicides of minors** between October 2021 and March 2023, and Southeast-Asian pig-butchering compounds — staffed by **220,000–300,000 trafficked workers** — generated an estimated **$63.9 billion in 2023 alone**. Current defences are fragmented, English-centric, cloud-dependent, single-modal, and reactive. **No consumer solution today combines on-device reasoning, multi-modal analysis, agentic orchestration, and native-language coaching for both elders and youth on budget iPhones.**

This thesis proposes **ScamGuard**, a Next.js-plus-Capacitor iOS application that ships Gemma 4 E2B (~2.3 B effective parameters) as an always-on screening agent and Gemma 4 E4B (~4.5 B effective parameters) as a deeper-reasoning agent, both running entirely on-device via Apple's MLX Swift framework. A six-agent architecture communicating over a local A2A bus and querying in-process MCP servers unifies call, SMS, email, URL, screenshot, and voice analysis under one explainable, multilingual, voice-first user interface. We hypothesise — and plan to demonstrate — that ScamGuard's E4B agent can reach ≥ 92 % F1 on composite scam-detection benchmarks while consuming ≤ 3 GB RAM and preserving battery at a cost of < 6 % per hour of active screening on an A15 iPhone 14. By proving that a 2–4 B-parameter open model running fully offline can match cloud-scale defensive systems, this work establishes a new paradigm for equitable, culturally competent scam protection.

---

## Section 1 — Problem statement

### 1.1 The scale of the global scam economy

Over the past thirty-six months, reported fraud losses have accelerated along every credible measurement axis. The **FTC Consumer Sentinel Network 2024 Data Book** logged **6.47 million reports and $12.5 billion in losses**, a **25 % rise over 2023's $10 billion** that is itself the first year US reported fraud crossed the ten-billion-dollar threshold. Investment-fraud losses hit **$5.7 billion**, imposter scams **$2.95 billion**, and job-scam losses leapt **5.5×** from $90 million in 2020 to **$501 million in 2024**. The **FBI IC3 2024 report** is darker still: **$16.6 billion in losses, a 33 % increase**, with the **average loss per incident climbing from $14,197 to $19,372** in a single year — meaning each scam is becoming dramatically more profitable even as complaint counts plateau. Cyber-enabled fraud now accounts for **83 % of IC3 losses**, concentrated in investment/crypto ($6.57 B), business-email compromise ($2.77 B), and tech support ($1.46 B).

The UK's **UK Finance Annual Fraud Report 2025** documents **£1.17 billion stolen via banking fraud** in 2024, while GASA/Cifas's **State of Scams UK 2024** measured a broader **£11.4 billion in total UK losses**, or **0.4 % of UK GDP**. Australia's National Anti-Scam Centre recorded combined 2025 losses of **A$2.18 billion**. Globally, the **Global Anti-Scam Alliance (GASA) 2024 Global State of Scams Report** — extrapolated from 58,329 respondents across 43 countries — estimates **US$1.03 trillion stolen in a twelve-month window**, with only **4 % of victims recovering any money**. Asia alone contributed **$688.42 billion** of that total. **Chainalysis's 2025 Crypto Crime Report** attributes **$9.9 billion (revised upward to $12.4 billion)** to crypto-related scam revenue in 2024, a figure that reached **$17 billion in 2025**, and notes that pig-butchering revenue grew **40 % YoY** while deepfake-government-official scams surged **1,400 %**.

### 1.2 Elders: disproportionately victimised, catastrophically harmed

The FBI's **2024 Elder Fraud Report** found that **147,127 victims aged 60+ reported $4.885 billion in losses**, a **43 % YoY increase**; **7,500+ elderly victims each lost more than $100,000**. By 2025 those figures climbed to **201,000 victims and $7.7 billion (+37 %)**. **FTC's Protecting Older Consumers 2024–2025 report** showed older-adult losses growing **4× since 2020**, from $600 million to **$2.4 billion**, with losses above $100,000 representing **5 % of reports but 68 % of aggregate dollars lost**. Factoring underreporting, the FTC itself estimated **true 2024 elder losses could approach $82 billion** and AARP's Public Policy Institute pegs **annual elder financial exploitation at $28.3 billion**. The **Burnes et al. (2017) meta-analysis** found a one-year prevalence of stranger-perpetrated scams on US older adults of **5.4 %**, and **Han et al. (2023)** linked scam susceptibility directly to prefrontal cortical decline, framing financial exploitation vulnerability as an **early behavioural marker of Alzheimer's disease**.

Elder-targeted patterns include the **grandparent scam** (now AI-voice-cloned), **IRS/SSA/Medicare impersonation**, **tech-support ransom scams**, **romance scams** (median loss for 70+ victims is roughly twelve times that of 18–29 victims), and **investment fraud** ($744 million in 2024 FTC older-adult losses). Japan's **2024 \"special fraud\" total reached ¥324 billion (~$2.1 billion)**, concentrated in the elderly-targeted **ore ore sagi (\"it's me\") scam** — a linguistic-cultural cousin of the grandparent scam so prevalent that Japan is piloting removal of debit cards from vulnerable seniors.

### 1.3 Youngsters: sextortion, gaming, and gamified job fraud

Children, teens, and young adults face a different — and equally severe — threat profile. Between **October 2021 and March 2023, the FBI and HSI received more than 13,000 reports of financial sextortion of minors** involving **12,600 identified victims (predominantly boys 14–17) and at least 20 suicides**. By 2024, annual sextortion victim counts had reached **54,000**, up from 34,000 in 2023, with **$65 million+ transferred to perpetrators over two years**. **Thorn's 2025 research** finds that **1 in 5 teens report experiencing sextortion**, with **1 in 7 reporting self-harm** afterward (**28 % among LGBTQ+ youth**). **Internet Watch Foundation reported a 380 % increase** in AI-generated child-sexual-abuse material in 2024, and US Homeland Security Investigations documented a **600 % increase** in AI-CSAM reports during the first half of 2025 alone.

Meanwhile, **FTC gamified task-job scams exploded from zero reports in 2020 to roughly 20,000 in H1 2024 alone**, and overall job-scam losses tripled from $90 million to $501 million in four years. Gaming scams targeting **Roblox (66.1 M DAU) and Fortnite (237 M DAU)** are systematically documented by the **ACM CHI 2025 paper \"They're Scamming Me\"**. Social-media-originated scams — dominant on TikTok, Instagram, Snapchat — accounted for **$2.7 billion in reported US losses since 2021**, more than any other contact method.

### 1.4 AI as a force multiplier for offenders

**Malicious LLMs have crossed from research curiosity to dark-web commodity in under three years.** WormGPT appeared on HackForums on **13 July 2023** (fine-tuned from GPT-J, priced €60–100/month), and FraudGPT followed on **22 July 2023** at **$200/month to $1,700/year**, reportedly achieving **3,000+ confirmed sales** within weeks. CATO Networks' CTRL team identified new WormGPT variants built on **xAI's Grok and Mistral's Mixtral** in late 2024 and early 2025, proving the ecosystem is resilient to take-downs. **Heiding, Schneier, Vishwanath and Park (IEEE Access 2024)** found AI-automated spear phishing achieves a **54 % click-through rate at roughly 5 % of the cost of human-crafted campaigns**; IBM X-Force's 2023 field test showed AI-generated phishing hitting an **11 % click-through rate versus 14 % for elite human social engineers** while cutting authoring time from **16 hours to 5 minutes**. Hoxhunt's 2026 report measured the share of reported emails bearing AI-generation signatures rising from **~4 % in November 2024 to 56 % by December 2024**.

Voice-cloning tools now require only **three seconds of audio** to produce convincing replicas. The **Jennifer DeStefano case (Arizona 2023)** demonstrated near-real-time cloning of a teenager's voice for a ransom demand. The **Arup (Hong Kong) February 2024 attack** remains the canonical corporate deepfake-fraud case: a finance employee, invited to a video conference populated entirely by AI-generated \"colleagues,\" executed **15 transfers totalling HK$200 million (US$25.6 million)**. **Deloitte projects AI voice-enabled fraud in the US alone will hit $40 billion per year by 2027.** The FBI's 2025 IC3 report already catalogues **22,000+ AI-related fraud complaints and $893 million in reported AI-linked losses**.

### 1.5 Pig butchering and industrialised transnational fraud

The term **sha zhu pan (杀猪盘)** — \"pig slaughter\" — describes multi-month emotional grooming followed by fake investment draining. **UN OHCHR (August 2023)** estimated **~120,000 trafficked workers in Myanmar and ~100,000 in Cambodia**; USIP's 2024 update put the global figure at **300,000+ people from 66 countries**. **USIP estimates $63.9 billion in 2023 pig-butchering revenue, of which $43.8 billion came from compounds in Burma, Cambodia and Laos — approximately 40 % of those countries' combined GDP.** The October 2025 DOJ indictment against **Chen Zhi and the Prince Group** seized **$15 billion in Bitcoin** — the largest crypto forfeiture in history — and catalogued a single **\"phone farm\" operating 76,000+ social-media accounts across 1,250 physical devices**, plus **ten violent forced-labour camps**. Victims' losses are only half the human toll.

### 1.6 Non-native speakers and cultural localisation

Scams are now **meticulously localised**. India's **National Cybercrime Reporting Portal documented 740,000 \"digital arrest\" complaints in the first four months of 2024 alone**, with **₹2,140 crore (~$257 million)** stolen in the first ten months — targeting middle-class Hindi- and Tamil-speaking victims with CBI/ED/RBI impersonations. In Spain, authorities arrested **100+ operators of the \"hijo en problemas\" WhatsApp scam** in early 2024 after a **nearly €1 million** loss wave. Kenya's **mobile-money fraud surged 344 % to KES 810 million in 2024**, and SIM-swap investigations rose **327 %**. Within US shores, **AARP data shows 39 % of AAPI adults 50+** reporting fraud experiences, with **average losses of $15,000**; the FBI-documented **Chinese Embassy / Police imposter scam** has a **$164,000 average loss per victim** and has defrauded the AAPI community of roughly **$40 million**.

**The FTC has formally determined Spanish speakers are more likely to be scam victims and less likely to report** than English speakers, and opened reporting in **twelve languages in November 2023**. **Olivares-Pasillas (Georgetown Immigration Law Journal 2024)** documented systematic under-protection of LEP immigrants through analysis of 1,040 FTC complaints. Aggregated estimates suggest **LEP individuals are roughly 2.8× more likely to fall victim to voice scams** — because they cannot detect grammar anomalies, cannot recognise authentic authority signals, and come from cultures (notably East Asian and South Asian) where authority compliance is a deeply embedded social norm. **Australian 2025 data showed a 44 % YoY increase in loss-involving reports among English-second-language consumers**.

### 1.7 Psychological and trust damage

Scam victimisation is a **mental-health crisis, not merely a financial one**. Peer-reviewed studies (Button 2014; Lichtenberg's FINCHES PMC6933096; Sarriá 2019; Kircanski PMC6005691) link victimisation to clinically significant depression, anxiety, sleep disturbance, and — in youth sextortion — completed suicide. AARP's Kathy Stokes summarises the elder case: *\"The impact is often catastrophic — emotional and health harms, fraught family dynamics, and in many cases the reality that despite having saved for a secure retirement, they are left to survive on local, state and federal safety nets.\"* Trust erosion compounds the damage: GASA 2024 found consumers in Brazil, Hong Kong, and South Korea exposed to scams near-daily, corroding baseline confidence in digital communication itself.

### 1.8 Multi-modality is now the default, not the exception

Modern attacks braid channels. A pig-butchering campaign begins with an **SMS \"wrong number\" text**, migrates to **WhatsApp** text chat, introduces **AI-generated profile photos** and occasional **deepfake video calls**, pivots to a **fake investment app**, and ends in **crypto wire transfers**. **Quishing (QR-code phishing)** rose from 0.8 % of phishing emails in 2021 to **12 % in 2025**, with **Barracuda detecting 500,000+ phishing emails containing QR codes in PDF attachments** during October 2024 alone. Smishing losses climbed **5.5× from $86 million (2020) to $470 million (2024)** per FTC data, with **vishing incidents surging 442 % in H2 2024**. **Single-modal defences are structurally unable to respond**, because the decisive evidence lives in the handoff between modalities — an innocuous text becomes lethal only after the deepfake video call that follows it.

### 1.9 Why current solutions fail at scale

Contemporary anti-scam tooling — carrier filters, OS-level silencers, third-party apps, government helplines — uses **blocklist-and-reputation heuristics** that were designed against the 2015 threat model. They do not reason about conversation context across multiple turns, do not analyse image or audio content semantically, do not operate in more than one or two languages, do not proactively educate users, and — crucially — almost always send sensitive content to the cloud for analysis. The result is a **defensive stack that is both too leaky and too privacy-invasive**, and that disproportionately fails the populations — non-native speakers, elders with cognitive decline, teens vulnerable to sextortion — who need protection most.

---

## Section 2 — Currently available solutions: strengths and weaknesses

### 2.1 Telecom-carrier defences

Carriers treat scam calls as a **network-level reputation problem**. **AT&T ActiveArmor** ships free with every wireless line — automatic fraud-call blocking, spam filtering, breach alerts — while the **Advanced tier ($7/month)** adds Caller ID, safe browsing, and identity-theft insurance. **Verizon Call Filter** offers free spam detection plus **Call Filter Plus ($3.99–10.99/month)** for a risk-scored Caller Name ID database. **T-Mobile Scam Shield** provides free Scam ID (\"Scam Likely\" tags) and Scam Block, with a **$4/month Premium** voicemail-routing tier; T-Mobile claims ML updates \"every six minutes\". Outside the US, **BT Call Protect** (UK) blocked 20 million+ scam calls in its first four months using Hiya's AI, and **Telstra Cleaner Pipes** (Australia) blocks **13 million+ scam calls and 23 million scam SMS monthly**.

All of these rest on **STIR/SHAKEN call authentication**, mandated by the US TRACED Act in 2019. STIR/SHAKEN attaches a cryptographically signed SIP identity header with attestation levels A (full), B (partial), or C (gateway). **The protocol does not stop scam calls — it only signals caller-ID trust.** International calls and complicit originating carriers routinely sign with C-level attestations, and SMS, OTT messaging, and VoIP are out of scope entirely.

**Weaknesses.** Carrier defences are (a) locked to subscribers, (b) overwhelmingly English-only, (c) blind to content — they see metadata, not semantics, (d) unable to analyse images, QR codes, or the audio inside a deepfake voice call, and (e) susceptible to both over-blocking legitimate callers and under-blocking spoofed live scammers.

### 2.2 Device-level built-in protections

Apple's **Silence Unknown Callers** (iOS 13+) is an identity filter, not a scam classifier. **Filter Unknown Senders** in Messages uses on-device ML to sort unknown-sender SMS into Transactions/Promotions/Junk, and **iOS 26's Call Screening** lets Siri ask callers their reason before the user picks up — processed on-device. Google's **Pixel Scam Detection** (announced at I/O 2024, stable from March 2025) runs **Gemini Nano on-device** to analyse live call audio for scam patterns like \"bank representative asking for gift cards\", and has since expanded to **WhatsApp, Instagram, Signal, Messenger, KakaoTalk, Line, and X**. **Samsung Smart Call** uses Hiya's cloud to power caller ID on Galaxy devices (31 billion blocked fraud attempts in 2024).

**Weaknesses.** Apple's tools do not semantically reason about scams — iOS 26 Call Screening still admits any scammer willing to state a reason. Pixel Scam Detection is **Pixel-only and English-only**, with Gemini Nano's roughly 4 K context and 1.8–3.25 B parameters limiting multi-turn reasoning. Samsung's reliance on Hiya's cloud breaks offline use and raises privacy questions. **Apple Intelligence's Foundation Models framework (WWDC 2025) requires iPhone 15 Pro or later**, excluding the hundreds of millions of iPhone 14-and-below devices where the vulnerable are most likely to live.

### 2.3 Third-party consumer apps

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

**Truecaller serves 450 million monthly active users on Android** and works by aggregating uploaded address books into a crowdsourced database — an approach that has drawn 2025 privacy-regulator probes in Nigeria and Sweden. **Norton Genie has 1 million+ installs and claims 90 %+ accuracy**, but sends message content to AWS. **McAfee Scam Detector — launched at CES January 2025 with on-device text analysis (>99 % accuracy) and deepfake-video detection (96 %) — is the closest current analogue to ScamGuard**, but lives behind McAfee+ subscriptions and supports only three English locales. **Bitdefender Scamio** accepts multilingual input but answers English-only, crippling its utility for LEP users.

### 2.4 AI-based detectors at the frontier (2024–2026)

Beyond Pixel and McAfee, **Norton Genie Scam Protection Pro** (Feb 2025) added Safe Call, Safe Email OAuth linkage, and NPU-accelerated deepfake detection on AI PCs. **Microsoft Defender SmartScreen's Enhanced Phishing Protection** (Windows 11 22H2+) alerts when work passwords are typed into SmartScreen-flagged sites but only covers credential entry. **Google's Gmail** blocks >99.9 % of spam/phishing/malware across 15 billion unwanted messages daily, with RETVec text vectoring improving spam detection by **38 %** and reducing false positives by **19.4 %**. Despite these wins, **0.1 % miss rate at Gmail's scale still means roughly 15 million malicious emails per day slip through.**

### 2.5 Government and NGO resources

**FTC ReportFraud, FBI IC3, UK Action Fraud, Scamwatch Australia, AARP Fraud Watch Network (877-908-3360), and Stop Scams UK's 159 service** all play valuable policy and post-hoc roles, but are **overwhelmingly reactive** — recording fraud after victimisation, pursuing macro-level enforcement, producing English-dominant educational material. AARP's human-operated helpline is one of the few proactive channels, yet it is US-only and English-centric.

### 2.6 Academic research trajectory

Academic literature shows a clear arc. **URLTran (Maneriker et al. MILCOM 2021)**, **SpamBERT variants (Sahmoud & Mikki 2022; Tida & Hsu 2022)**, and **BERT-G3CN (Shen et al. 2025)** established 98–99 % transformer-based accuracy on classical phishing/spam benchmarks. **KnowPhish (Li et al. USENIX Security 2024)** fused a 20,000-brand multimodal knowledge graph with LLM brand-intent extraction to catch **2× more phishing pages** at **5× lower latency** than DynaPhish. **PhishAgent (Wang & Hooi 2024)** and **MultiPhishGuard (Chataut et al. 2025, arXiv 2505.23803)** proved that multi-agent LLM committees outperform single classifiers, especially under adversarial prompts; **PhishDebate (2506.15656)** and **PhishLumos (2509.21772)** extend this to debate-style adjudication.

Work on smishing and scam-conversation modelling — **Salman et al. (2022, 2025), SmishX (Mehdi et al. SOUPS 2024), SpaLLM-Guard (2501.04985), ElZemity's Agentic Knowledge Distillation (2602.10869)** — demonstrated that distilled on-device student models can reach **94 % accuracy and 96 % recall** on SMS threats. On the inference side, **GPTQ (Frantar et al. ICLR 2023)**, **AWQ (Lin et al. MLSys 2024)**, **SmoothQuant (Xiao et al. ICML 2023)**, **MobileLLM (Liu et al. ICML 2024)**, and the Gemma technical reports establish that **sub-4 B models with 4-bit weight-only quantisation match or exceed the cloud 7–13 B baselines of just eighteen months earlier**. Deepfake detection work — **AudioSeal (San Roman et al. ICML 2024)**, **ASVspoof 5 (Wang et al. 2024)**, **DeepSpeak v1.0 (Barrington et al. 2024)**, **Lin et al. CVPR 2024 on fairness** — provides robust pipelines the application layer can call as tools.

### 2.7 Gap analysis: what no current solution does well

Ten capability gaps persist:

1. **True on-device multi-modal reasoning** — only Pixel (English) and McAfee (subscription, three locales) ship it; no product unifies call audio, SMS, email, images, QR codes, and browser context under one offline model.
2. **Context-aware agentic protection** across multi-turn conversations (romance and pig-butchering campaigns unfold over weeks).
3. **Proactive inoculation and personalised education** in the user's native language.
4. **Deep multi-language support** — Norton Genie and Gemini Nano are English-only; Scamio takes multilingual input but replies in English.
5. **Real-time deepfake detection during live calls** — existing products detect file uploads, not streams.
6. **Unified cross-channel policy** across calls, SMS, email, DMs, web, and in-app.
7. **Privacy-preserving architecture** — nearly every competitor sends content to the cloud.
8. **Elderly-accessible UX** — voice-first interaction, high-contrast warnings, trusted-contact escalation.
9. **Banking-API integration** that can pause a transfer mid-scam conversation.
10. **Adversarial robustness** against prompt injection and novel TTS/voice-clone engines.

**ScamGuard is designed to close all ten.**

---

## Section 3 — Proposed solution: ScamGuard

### 3.1 System architecture overview

ScamGuard is a **Next.js-plus-Capacitor iOS application** that bundles a **Gemma-based agentic core** (two models, six specialist agents) with a set of **in-process MCP servers** and **A2A-mediated inter-agent communication**, all running entirely on the user's iPhone. A single shared Swift package, **GemmaKit**, is linked by the main app target and by four iOS extensions (Message Filter, Call Directory, Share, App Intents), so the same inference pipeline powers every entry point.

```
 ┌──────────────────────────────────────────────────────────────┐
 │                 ScamGuard (iOS, Capacitor shell)             │
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

### 3.2 Model allocation: E2B always-on, E4B deep analysis

**Gemma 4 E2B (2.3 B effective / 5.1 B with embeddings, 128 K context, text+image+audio)** runs as the **always-on screening tier** quantised to **Q4_K_M (~1.5–1.8 GB RAM)**. It handles fast binary classification on SMS, call-screen transcripts, incoming notifications, and clipboard URLs. On Qualcomm Dragonwing IQ8 NPUs, Google cites **3,700 prefill / 31 decode tok/s** for E2B; projected to the **A15 Bionic's 15.8 TOPS ANE + 5-core GPU on iPhone 14 (6 GB RAM)**, the target is **15–25 decode tok/s and ≤ 400 ms first-token latency** via MLX Swift GPU inference, with **peak RSS ≤ 2.3 GB including KV cache**.

**Gemma 4 E4B (4.5 B effective / 8 B total)** is the **deep-reasoning tier** quantised to **Q4_K_M (~2.8–3.2 GB)**, loaded on demand when E2B's confidence is below a threshold or the user explicitly requests analysis. E4B runs agentic planning, multi-turn reasoning, multimodal screenshot analysis, and audio-deepfake scoring. Because of its 6 GB RAM floor, E4B is opportunistic on iPhone 14 (6 GB) and fully resident on iPhone 14 Pro / 15 / 16 (6–8 GB). Gemma 4 E2B already outperforms **Gemma 3 27B on Tau2 agentic benchmarks (24.5 % vs 16.2 %)** — the first time an on-phone model surpasses last year's cloud flagship on multi-turn tool use — which directly validates the on-device agentic thesis.

### 3.3 Quantisation and runtime stack

ScamGuard will ship **four model artifacts** via the Hugging Face Hub:

- `scamguard/gemma-4-e2b-it-scamguard-q4km.gguf` — LoRA-merged and quantised (~1.5 GB)
- `scamguard/gemma-4-e4b-it-scamguard-q4km.gguf` — LoRA-merged and quantised (~3.0 GB)
- `scamguard/gemma-4-e2b-it-scamguard-mlx-4bit` — MLX native for Apple Silicon
- `scamguard/gemma-4-e4b-it-scamguard-mlx-4bit` — MLX native with TurboQuant KV-cache compression

Runtime priority on iOS is **MLX Swift** (via `mlx-swift-examples`'s `LLMModelFactory`) with Metal GPU backend. Core ML conversion via `coremltools` is attempted but deprioritised due to **known PyTorch-to-MIL conversion bugs on Gemma 3/4** (coremltools issue #2560); ExecuTorch's Core ML backend is the fallback path for ANE targeting once those bugs clear. **We deliberately do not rely on Apple's Foundation Models framework**, because it requires Apple Intelligence hardware (iPhone 15 Pro+) and excludes the iPhone 14 baseline.

### 3.4 Multi-modal capabilities

Gemma 4 E2B and E4B are the **first open on-device models with native audio input** — the family ships a **USM-style Conformer audio encoder** enabling speech-to-text, audio reasoning, and emotional-tone analysis without an external ASR step. This permits one-shot voice-scam screening: the audio stream of an answered call can be fed directly to E4B, which emits both a transcript and a scam-risk verdict. The vision encoder supports **native-aspect-ratio images with configurable token budgets (70/140/280/560/1120 tokens)**, enabling rapid screenshot analysis for fake TikTok Shop listings, phishing emails, and QR-code phishing images.

### 3.5 Multi-agent architecture over MCP and A2A

Six agents share the inference runtime and communicate over an **in-process A2A bus** using the canonical JSON-RPC 2.0 envelope and Agent Card discovery defined in **A2A v1.0** (hosted at `/.well-known/agent-card.json` even for local agents). Each agent exposes its skills (e.g., `classify_sms`, `score_voice_deepfake`, `analyse_screenshot`) through an Agent Card at launch, letting the Orchestrator route tasks dynamically.

- **Orchestrator Agent (E4B)** — intent classification, tool routing, task decomposition, final verdict aggregation.
- **Text Agent (E2B)** — SMS, email, DM, and notification content classification with queries to `scam_patterns` and `sqlite-vec` MCP servers.
- **URL Agent (E2B)** — URL extraction, Safe-Browsing hash-prefix lookup, WHOIS domain-age check, brand-impersonation detection.
- **Voice Agent (E4B + ASR)** — live call audio transcription, voice-cloning artifact scoring (pitch, cadence, spectral), AudioSeal watermark check.
- **Image Agent (E4B VLM)** — screenshot OCR, logo and brand detection, reverse-image lookup, QR-code decoding, deepfake-still detection.
- **Judge/Explainer Agent (E4B)** — aggregates specialist verdicts via weighted voting or structured debate (PhishDebate pattern) and produces a user-facing explanation in the user's native language and dialect.

This hybrid **orchestrator-worker plus debate** topology maximises interpretability (a requirement for elderly and LEP users) while bounding latency.

### 3.6 MCP server layer

Every external-world capability is exposed as an **MCP server running in-process over in-memory pipes**. Because iOS sandboxing disallows arbitrary subprocess spawning, each MCP server is a Swift class conforming to the **official Anthropic Swift SDK** (`modelcontextprotocol/swift-sdk`), registered at app launch.

| MCP server | Tools | iOS surface |
|---|---|---|
| `scam_patterns` | `search_patterns`, `match_pattern` | Local SQLite of curated scam regex/templates |
| `sqlite_vec` | `semantic_search`, `nearest_known_scams` | On-device vector DB (ObjectBox or sqlite-vec) over labelled scam corpus |
| `contacts` | `is_known_contact`, `contact_reputation` | `CNContactStore` |
| `url_reputation` | `check_url`, `safe_browsing_lookup` | Google Safe Browsing v4 hash prefix (local DB, k-anonymous) |
| `whois` | `whois_lookup`, `domain_age` | Public RDAP over HTTPS |
| `reverse_image` | `reverse_image_search` | On-device CLIP embedding similarity against curated known-scam-image DB |
| `phone_reputation` | `phone_reputation`, `is_voip` | Local heuristics + hashed reputation DB |
| `message_filter` | `enqueue_sms_for_analysis` | `ILMessageFilterExtension` bridge via App Group |
| `clipboard_watcher` | `scan_clipboard_url` | `UIPasteboard` (with system pill) |
| `screen_time` | `child_device_policy` | `FamilyControls` / `ManagedSettings` |

All servers are scoped by **least-privilege permission tokens** derived from MCP's 2025-06-18 OAuth 2.1 update, so that (for example) the `message_filter` server cannot call network tools.

### 3.7 A2A as the inter-agent glue — and a future federation point

At MVP, A2A runs entirely locally. The principled reason to use A2A rather than direct function calls is **optionality**: any agent can be *promoted* to a cloud agent in the future without changing its callers. A user worried about deepfake-laden corporate video calls could, for example, opt in to a cloud-side **threat-intelligence consensus agent** that cross-votes with the on-device Judge. A2A's Agent Card signatures and OAuth scopes give us a clean trust boundary when that day comes.

### 3.8 Tool use and function calling

Gemma 4 ships **first-class JSON-schema function calling** via `processor.apply_chat_template(messages, tools=...)`. ScamGuard wraps every agent call and every MCP tool invocation in **grammar-constrained decoding** using **llama.cpp GBNF** (converted from JSON Schema) to guarantee syntactically valid tool outputs even from quantised E2B. Apple **App Intents** are enumerated at launch and presented to the agent as additional tools — `BlockSenderIntent`, `ReportSpamIntent`, `ReadLastNotificationIntent`, `CallTrustedContactIntent` — so system-level actions become first-class members of the agent's toolbox.

### 3.9 Privacy-first architecture

By default, **no message content, call audio, screenshot, or contact record ever leaves the device**. Network calls are restricted to three narrow endpoints: (a) **Safe Browsing hash-prefix queries** (k-anonymous), (b) **RDAP WHOIS** over HTTPS, and (c) **optional, user-initiated escalation** to a cloud A2A agent. Vector-DB keys are sealed in the **Secure Enclave**. An **encrypted iCloud sync** option lets users restore their scam-report history across devices; the key never leaves local hardware. **Federated learning with local DP noise (DP-FedAvg)** is the long-term path for improving the shared model without ever collecting raw messages.

### 3.10 Accessibility for elders and non-native speakers

Gemma 4's **140+-language support** is the linchpin of ScamGuard's accessibility plan. The UI launches with **voice-first interaction** in the user's OS language, a **high-contrast large-type visual mode**, and **single-button \"Check this for me\"** affordance invoked via Siri Shortcut, Share Sheet, or a lock-screen widget. When E4B produces a verdict, the Explainer Agent renders the reasoning in the user's native language at a sixth-grade reading level, with **culturally-aware warnings** (e.g., the Judge knows that an \"RBI call\" impersonation has a different shape in Hindi than a \"CBI digital arrest\" framing, and that the Japanese ore-ore pattern differs from the US grandparent scam). A **Trusted Contact Escalation** feature lets the user nominate an adult child or grandchild who receives a push notification when a high-risk event is detected, closing the social-proof loop that scammers deliberately isolate.

### 3.11 iOS extension integration points

ScamGuard ships four extensions, each linking **GemmaKit**:

1. **Message Filter Extension (`ILMessageFilterExtension`)** — triggered only on SMS from non-contacts. Because the extension has a **~50 MB memory ceiling**, it cannot run E2B; it instead uses a **distilled DistilBERT Core ML classifier ≤ 5 MB** for the real-time allow/junk/promotion/transaction decision, and hands flagged messages to the main app via App Group for full E2B/E4B re-analysis.
2. **Call Directory Extension (`CXCallDirectoryExtension`)** — periodically regenerates a blocked-number list from the `phone_reputation` MCP server.
3. **Share Extension** — users can share any URL, message, or screenshot to ScamGuard; the extension defers to the main app via `NSFileCoordinator`.
4. **App Intents Extension** — exposes `CheckWithScamGuardIntent`, `ReportScamIntent`, `BlockSenderIntent` to Siri, Shortcuts, and the system Action Button.

A **Safari Content Blocker** extension consumes declarative JSON rules generated by the main app from the user's flagged URLs.

### 3.12 Real-time vs on-demand modes

ScamGuard has three screening modes. **Passive mode** runs the Message Filter extension and Call Directory only — zero main-app battery draw. **Active mode** keeps E2B resident for fast on-demand analysis of user-shared content. **Guardian mode** (requires user consent and is intended for elders or teens) additionally monitors inbound notifications via the **Focus/Notification Content Extension**, answers unknown calls with Siri-powered screening, and pre-scores clipboard URLs — while still never transmitting content off-device.

---

## Section 4 — Methodology

### 4.1 Hackathon execution timeline

| Week | Milestone |
|---|---|
| 1 | Fetch Gemma 4 E2B/E4B weights from Kaggle; build baseline MLX Swift inference on iPhone 14 simulator and a loaner device; benchmark raw throughput. |
| 2 | Stand up Capacitor + Next.js shell; implement `GemmaPlugin` with streaming token notifications; smoke-test end-to-end prompt → token stream in the WebView UI. |
| 3 | Assemble training corpus (see §4.2); fine-tune E2B and E4B with Unsloth + QLoRA; merge and export GGUF + MLX 4-bit artifacts; spot-check accuracy on held-out test set. |
| 4 | Implement six MCP servers in Swift; wire Orchestrator Agent to route tasks via local A2A; integrate grammar-constrained decoding via llama.cpp GBNF. |
| 5 | Build iOS extensions (Message Filter distilled classifier, Call Directory, Share, App Intents); implement voice-first accessibility UI and multi-language Explainer. |
| 6 | User testing with ≥ 10 elders (mean age 70+) and ≥ 10 non-native speakers across at least 3 languages; iterate on UX and thresholds. |
| 7 | Benchmarking, adversarial testing, hackathon submission video, TestFlight beta, final thesis edit. |

### 4.2 Data collection and fine-tuning corpus

We will fine-tune on a **composite dataset of approximately 30,000–50,000 labelled examples** assembled from:

- **Enron Email Corpus** (spam labels) — classical phishing baselines.
- **SMS Spam Collection (UCI)** — 5,574 labelled SMS.
- **PhishTank** and **Nazario Phishing Corpus** — verified phishing URLs and emails.
- **APWG eCrime Exchange** — multimodal phishing samples.
- **FTC Consumer Sentinel 2022–2024 narrative text** (public portions).
- **Synthetic data distilled from a larger teacher (Gemini 2.5 Pro or Claude Opus 4.5)** following the **Agentic Knowledge Distillation recipe (ElZemity 2026, arXiv 2602.10869)**, which reached 94 % accuracy / 96 % recall distilling into sub-billion-parameter students.
- **Multilingual augmentations** generated per region: Spanish (Smart Business Corp patterns), Hindi (digital-arrest templates), Japanese (ore-ore scripts), Mandarin (fake-consulate and pig-butchering openers).
- **Audio-deepfake evaluation only** — ASVspoof 5 (Wang et al. 2024) + DeepSpeak v1.0 (Barrington et al. 2024).
- **Image-deepfake evaluation only** — OpenForensics, FaceForensics++, curated scam-screenshot corpus.

Each example carries `{sender, body, metadata, label, rationale, language, region, vulnerable_group}`. We mix **75 % reasoning-style chain-of-thought examples** with 25 % direct classification to preserve Gemma 4's agentic capability; unmixed supervised fine-tuning is known to collapse planning skill.

### 4.3 Fine-tuning approach: LoRA/QLoRA with Unsloth

Following Unsloth's published **Gemma 4 Fine-tuning Guide**, we apply **rank-16 LoRA** with `lora_alpha=32`, `dropout=0.05`, targeting `q_proj, k_proj, v_proj, o_proj, gate_proj, up_proj, down_proj`. Training uses `per_device_train_batch_size=4`, `gradient_accumulation_steps=4`, `lr=2e-4`, cosine schedule, `bf16=True`, and 3 epochs. **E2B QLoRA fits on a free Kaggle T4 (16 GB); E4B QLoRA fits on a single A10/A100 40 GB.** Chat-template drift is the single most common post-fine-tune bug; we verify that `tok.apply_chat_template(msgs, tokenize=False, add_generation_prompt=True)` in Python matches the MLX Swift Tokenizer output byte-for-byte.

### 4.4 Benchmarking protocol

**Accuracy benchmarks.** Precision, recall, F1, and AUROC on held-out sets partitioned by language, region, and vulnerable group. Compare ScamGuard-E2B and -E4B against (a) cloud GPT-4o/Claude Opus 4.5 baselines, (b) Norton Genie and McAfee Scam Detector where APIs allow, and (c) the SpaLLM-Guard (2501.04985) and APOLLO (2502.04759) academic baselines.

**Latency benchmarks.** First-token latency, full-analysis latency (text, URL, image, audio), and end-to-end user-visible response time for the Share Sheet flow, measured on **iPhone 14 (A15, 6 GB)**, iPhone 15 Pro (A17 Pro, 8 GB), and iPhone 16 Pro (A18 Pro, 8 GB).

**Memory benchmarks.** Peak RSS across E2B-only, E4B-only, and multi-agent pipelined modes; verify no OOM on the 6 GB baseline device.

**Battery benchmarks.** Battery drain per hour for Passive, Active, and Guardian modes; thermal-throttling onset time for continuous inference.

**Adversarial robustness.** Replay a suite of **prompt-injection attacks documented by Hou et al. (2503.23278) and Invariant Labs**, plus novel TTS and voice-clone engines held out from training, to measure cross-vocoder generalisation (a published weakness of state-of-the-art detectors per arXiv 2510.21004).

### 4.5 User testing with vulnerable populations

In collaboration with a local senior centre and an immigrant-services non-profit, we will recruit **≥ 10 elders (mean age 70+) and ≥ 10 non-native speakers across at least 3 languages (Spanish, Mandarin, Hindi)**. Each participant completes a structured protocol:

1. Pre-survey on scam concern and digital confidence.
2. Hands-on walkthrough of ScamGuard's Share Sheet, voice-first flow, and Trusted Contact setup.
3. Realistic scam scenario (scripted SMS, deepfake voice memo, fake TikTok Shop screenshot) — does the participant notice the warning, understand the explanation, and choose correctly?
4. Post-survey on trust, perceived clarity of explanation, and willingness to continue using.

Outcome measures include **task success rate, explanation comprehension, Net Promoter Score, and qualitative coding of confusion/delight moments**.

### 4.6 Deployment pipeline and TestFlight

The iOS build is produced by a **GitHub Actions workflow** that runs `next build && next export`, syncs to Capacitor, signs with a developer certificate, and uploads to **TestFlight** via `fastlane pilot`. Model weights are downloaded on first launch (with an Apple-compliant progress UI and user-consent screen) rather than shipped in the IPA, keeping the install footprint under 100 MB.

### 4.7 Open-source strategy and licensing

ScamGuard will be released under the **Apache 2.0 license**, matching Gemma 4's own Apache 2.0 licensing. All code (Swift, TypeScript, fine-tuning scripts) lives on GitHub; weights and GGUF/MLX artifacts live on Hugging Face. Data annotations derived from public datasets inherit their upstream licenses. We will submit the work to the **Gemma 4 Good Hackathon** on Kaggle, accompany the submission with the thesis in this document, and — win or lose — maintain the project as a public good aligned with the hackathon's social-impact framing.

---

## Section 5 — Hypotheses

We formulate five testable hypotheses that together argue the case for ScamGuard.

**H1. On-device accuracy parity.** A LoRA-fine-tuned Gemma 4 E4B running **Q4_K_M on-device** will achieve **≥ 92 % F1 on a composite English scam-detection benchmark** (SMS, email, URL, screenshot), **within 3 points** of a cloud GPT-4o baseline, and **outperform the Salman 2025 SpaLLM-Guard zero-shot baseline by ≥ 10 F1 points**.

**H2. Multi-modal outperforms single-modal.** The six-agent pipeline that jointly analyses text + URL + image + audio will produce **≥ 7 % absolute F1 improvement** over any single-modal baseline on a realistic multi-modal scam corpus (synthetic pig-butchering chains with fake profile photos, deepfake voice memos, and fraudulent investment-app screenshots), reflecting the same trend observed by **PhishAgent (Wang & Hooi 2024)** and **MultiPhishGuard (Chataut et al. 2025)**.

**H3. Agentic MCP/A2A beats static rules.** Against a **multi-turn adversarial scammer corpus** simulating romance and pig-butchering campaigns over 10+ turns, the agentic architecture with MCP tool queries and A2A debate adjudication will reduce **false-negative rate by ≥ 30 %** compared to a static rule-based or single-shot-LLM baseline, consistent with the **PhishDebate (arXiv 2506.15656)** and **ScriptMind (arXiv 2601.13581)** published gains.

**H4. Privacy-first drives adoption.** In the user study, **≥ 80 % of elderly and ≥ 85 % of LEP participants** will report *greater trust* in an on-device solution than in a cloud-based equivalent, and stated willingness-to-continue-using will exceed **70 %** — a threshold above the ~45 % long-term retention reported by Truecaller analytics and comparable consumer-security apps, supported by Koning et al. (2024) findings on fraud-knowledge and self-efficacy.

**H5. Native-language coaching cuts victimisation.** Presenting scam explanations in the user's native language at a sixth-grade reading level will produce a **statistically significant (p < 0.05) reduction in simulated-scam victimisation** in a pre-post design, with effect size **≥ 0.4 (Cohen's d)** against an English-only control — operationalising the LEP-vulnerability findings of **Olivares-Pasillas (Georgetown 2024)** and AARP's multicultural fraud surveys.

---

## Section 6 — Expected results

### 6.1 Quantitative performance targets

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

These targets are grounded in extrapolations from **llama.cpp A-series benchmarks (Mistral-7B Q4 at 5–10 tok/s)** scaled by parameter ratio, corroborated by community reports of Gemma 4 E2B running on iPhone 13 Pro via MLX Swift, and by Google's cited **3,700 prefill / 31 decode tok/s** on Qualcomm Dragonwing IQ8 NPUs.

### 6.2 Qualitative outcomes

In the user study we expect (a) **≥ 80 % elder task-completion rate** on the Share-Sheet flow versus a pre-registered ~40 % baseline with typical iOS security UIs; (b) **≥ 4.2/5 average comprehension rating** for the native-language Explainer output; (c) **Net Promoter Score ≥ +30** from both elder and LEP cohorts; (d) qualitative evidence that the **Trusted Contact Escalation** feature is valued as a \"second opinion\" that breaks the isolation scammers engineer.

### 6.3 Societal-impact projections

If ScamGuard reaches even **1 % of the roughly 800 million iPhone-14-and-earlier users globally** and reduces victimisation in that population by **one-third** — a conservative figure relative to the **30 % false-negative reduction demonstrated by agentic systems in the literature** — the annualised financial-loss prevention is on the order of **$2–4 billion** against GASA's $1.03 trillion global baseline. The mental-health benefit, though harder to quantify, is anchored in peer-reviewed evidence (Button 2014; Lichtenberg FINCHES; Sarriá 2019) that every prevented scam is a prevented depression, anxiety, or — in the sextortion case — suicide risk. For LEP and elderly populations specifically, ScamGuard's multilingual voice-first UI is expected to **close the 2.8× voice-scam vulnerability gap** documented for LEP users and the **38 %-vs-16 % overrepresentation of 65+ adults among voice-scam victims**.

### 6.4 Comparison to existing solutions

| Dimension | Pixel Scam Det. | McAfee SD | Norton Genie | Truecaller | Bitdefender Scamio | **ScamGuard** |
|---|---|---|---|---|---|---|
| Fully on-device | ✔ | ✔ (mostly) | ✘ | ✘ | ✘ | **✔** |
| Multi-modal (text+URL+image+audio) | partial | ✔ | ✔ | partial | ✔ | **✔** |
| Multi-language reasoning | ✘ English | ✘ 3 locales | ✘ English | UI only | input only | **✔ 140+** |
| Agentic (MCP + A2A) | ✘ | ✘ | ✘ | ✘ | ✘ | **✔** |
| Works on iPhone 14 | ✘ Pixel only | ✔ | ✔ | ✔ | ✔ | **✔** |
| Explanations in user's native language | ✘ | partial | ✘ | ✘ | ✘ | **✔** |
| Trusted-contact escalation | ✘ | ✘ | ✘ | ✘ | ✘ | **✔** |
| Open-source weights + code | ✘ | ✘ | ✘ | ✘ | ✘ | **✔** |

### 6.5 Path to production and scaling

Post-hackathon, the roadmap is four-fold. **Production (months 1–3):** TestFlight public beta, App Store submission, hardening of MCP permission scopes, App Store privacy-manifest compliance. **Cross-platform (months 3–9):** Capacitor Android build targeting LiteRT-LM / MediaPipe LLM Inference runtime; Progressive Web App fallback for desktop review use cases; desktop Electron build for caregivers. **Federation (months 9–18):** Optional cloud A2A threat-intelligence agent; DP-FedAvg federated learning for continual model improvement; partnerships with carrier scam-reporting APIs (T-Mobile Scam Shield, BT Call Protect) and banking APIs for mid-scam transaction pausing. **Research (continuous):** Collaboration with AARP Fraud Watch, Thorn, and LEP immigrant-services non-profits to release anonymised, consented scam corpora as public goods, and to co-author peer-reviewed evaluation studies following the benchmarking protocol of §4.4.

---

## Conclusion

**Three forces have converged in 2024–2026: scams have become a trillion-dollar transnational industry, generative AI has trivialised their production, and open on-device models have matured enough to fight back.** Gemma 4 E2B and E4B — 2.3 B and 4.5 B effective parameters, multi-modal text+image+audio, 128 K context, 140+ languages, Apache 2.0 licensed, and empirically outperforming Gemma 3 27B on agentic tool-use tasks while fitting on an iPhone 14 — represent the first moment at which a privacy-first, multilingual, voice-first, agentic consumer scam-defence app is technically viable on a mainstream budget device.

ScamGuard is the concrete realisation of that opportunity. By combining (i) a two-model tiered architecture, (ii) a six-agent MCP+A2A orchestration, (iii) native-language explanations and trusted-contact escalation, and (iv) a strict on-device privacy posture, it closes the ten capability gaps that existing commercial and academic solutions collectively leave open. The hypotheses in §5 are rigorous and falsifiable; the methodology in §4 is executable within a hackathon timeline; the expected results in §6 are bold but grounded in extrapolations from published benchmarks. If validated, ScamGuard would establish a new class of **on-device protective agents** — ones that belong *to* and run *for* their user, not a cloud vendor — and demonstrate that the most vulnerable populations globally can finally receive first-class, equitable, culturally competent protection from the fastest-growing crime on Earth.

*The twenty-first-century scammer has an AI. Until now, the twenty-first-century grandmother has not. ScamGuard changes that.*

---

## References

1. Federal Trade Commission. *Consumer Sentinel Network Data Book 2024.* 2025. https://www.ftc.gov/system/files/ftc_gov/pdf/csn-annual-data-book-2024.pdf
2. FTC Press Release. \"New FTC Data Show Big Jump in Reported Losses to Fraud to $12.5 Billion in 2024.\" March 2025. https://www.ftc.gov/news-events/news/press-releases/2025/03/new-ftc-data-show-big-jump-reported-losses-fraud-125-billion-2024
3. FTC. \"Protecting Older Consumers 2024-2025 Report to Congress.\" December 2025. https://www.ftc.gov/news-events/news/press-releases/2025/12/ftc-issues-annual-report-congress-agencys-actions-protect-older-adults
4. FTC. \"Paying to Get Paid: Gamified Job Scams Drive Record Losses.\" December 2024. https://www.ftc.gov/news-events/data-visualizations/data-spotlight/2024/12/paying-get-paid-gamified-job-scams-drive-record-losses
5. Federal Bureau of Investigation, Internet Crime Complaint Center. *2024 Internet Crime Report.* April 2025. https://www.ic3.gov/AnnualReport/Reports/2024_IC3Report.pdf
6. FBI IC3. *2023 Internet Crime Report.* 2024. https://www.aha.org/system/files/media/file/2024/03/fbi-internet-crime-report-2023.pdf
7. FBI IC3. *Elder Fraud Tri-Fold 2025.* https://www.ic3.gov/Outreach/Brochures/elder_fraud_tri-fold.pdf
8. FBI. \"Chinese Police Imposter Scam PSA.\" IC3 PSA 240103, January 2024. https://www.ic3.gov/PSA/2024/PSA240103
9. UK Finance. *Annual Fraud Report 2025.* May 2025. https://www.ukfinance.org.uk/system/files/2025-05/UK%20Finance%20Annual%20Fraud%20report%202025.pdf
10. RSM UK. \"Fraud loss reaches £2.3 billion as fraudsters become increasingly sophisticated.\" 2025. https://www.rsmuk.com/news/fraud-loss-reaches-2-point-3-billion-fraudsters-become-increasingly-sophisticated
11. Cifas / GASA. *State of Scams UK 2024.* https://www.cifas.org.uk/newsroom/gasa-stateofscamsuk2024
12. ACCC / National Anti-Scam Centre. *Targeting Scams Report 2024.* March 2025. https://www.scamwatch.gov.au/system/files/targeting-scams-report-2024.pdf
13. Global Anti-Scam Alliance / Feedzai. *Global State of Scams Report 2024.* 2024. https://www.gasa.org/post/global-state-of-scams-report-2024-1-trillion-stolen-in-12-months-gasa-feedzai
14. Chainalysis. *2025 Crypto Crime Report.* 2025. https://www.chainalysis.com/blog/2025-crypto-crime-report-introduction/
15. Chainalysis. \"2024 Pig Butchering Scam Revenue Grows YoY.\" 2025. https://www.chainalysis.com/blog/2024-pig-butchering-scam-revenue-grows-yoy/
16. U.S.-China Economic and Security Review Commission. *China's Exploitation of Scam Centers in Southeast Asia.* July 2025. https://www.uscc.gov/sites/default/files/2025-07/Chinas_Exploitation_of_Scam_Centers_in_Southeast_Asia.pdf
17. Interpol. \"Operation HAECHI V: Record 5,500 arrests, $400 M seized.\" 2024. https://www.interpol.int/News-and-Events/News/2024/INTERPOL-financial-crime-operation-makes-record-5-500-arrests-seizures-worth-over-USD-400-million
18. CNN. \"Finance Worker Pays Out $25 M in Deepfake Scam.\" May 16, 2024. https://www.cnn.com/2024/05/16/tech/arup-deepfake-scam-loss-hong-kong-intl-hnk
19. Fortune. \"Arup Deepfake Fraud Scam Victim Hong Kong 25 Million CFO.\" May 17, 2024. https://fortune.com/europe/2024/05/17/arup-deepfake-fraud-scam-victim-hong-kong-25-million-cfo/
20. Heiding, F., Schneier, B., Vishwanath, A., Bernstein, J., Park, P. S. \"Devising and Detecting Phishing Emails Using Large Language Models.\" *IEEE Access* 12, 2024. https://ieeexplore.ieee.org/document/10466545
21. Harvard Business Review. \"AI Will Increase the Quantity — and Quality — of Phishing Scams.\" May 2024. https://hbr.org/2024/05/ai-will-increase-the-quantity-and-quality-of-phishing-scams
22. Krebs, B. \"Meet the Brains Behind the Malware-Friendly AI Chat Service WormGPT.\" KrebsOnSecurity, August 2023. https://krebsonsecurity.com/2023/08/meet-the-brains-behind-the-malware-friendly-ai-chat-service-wormgpt/
23. CATO Networks CTRL / CSO Online. \"WormGPT returns: new malicious AI variants built on Grok and Mixtral uncovered.\" March 2025. https://www.csoonline.com/article/4008912/wormgpt-returns-new-malicious-ai-variants-built-on-grok-and-mixtral-uncovered.html
24. LevelBlue. \"WormGPT and FraudGPT: The Rise of Malicious LLMs.\" https://www.levelblue.com/blogs/spiderlabs-blog/wormgpt-and-fraudgpt-the-rise-of-malicious-llms
25. Netenrich. \"FraudGPT: The Villain Avatar of ChatGPT.\" July 2023. https://netenrich.com/blog/fraudgpt-the-villain-avatar-of-chatgpt
26. AARP Public Policy Institute (Gunther, J.). *Scope of Elder Financial Exploitation.* June 2023. https://doi.org/10.26419/ppi.00194.001
27. AARP. \"Vital Voices: Fraud Concerns of Older Adults.\" 2025. https://www.aarp.org/pri/topics/aging-experience/demographics/vital-voices-fraud-concerns-older-adults.html
28. Burnes, D., Henderson, C. R., et al. \"Prevalence of Financial Fraud and Scams Among Older Adults in the United States.\" *American Journal of Public Health*, 2017. https://pmc.ncbi.nlm.nih.gov/articles/PMC5508139/
29. Peterson, J. C., Burnes, D. P., et al. \"Financial Exploitation of Older Adults: A Population-Based Prevalence Study.\" *Journal of General Internal Medicine*, 2014. https://pubmed.ncbi.nlm.nih.gov/25103121/
30. Han, S. D., Boyle, P. A., et al. \"Cognitive and Neuroimaging Correlates of Financial Exploitation Vulnerability in Older Adults.\" *Neuroscience & Biobehavioral Reviews*, 2023. https://pmc.ncbi.nlm.nih.gov/articles/PMC9815424/
31. Lichtenberg et al. \"FINCHES Mental Health Study.\" https://pmc.ncbi.nlm.nih.gov/articles/PMC6933096/
32. Kircanski, K. et al. \"Emotional Arousal May Increase Susceptibility to Fraud.\" https://pmc.ncbi.nlm.nih.gov/articles/PMC6005691/
33. FBI. \"Sextortion: A Growing Threat Targeting Minors.\" https://www.fbi.gov/contact-us/field-offices/nashville/news/sextortion-a-growing-threat-targeting-minors
34. Thorn. *Sexual Extortion & Young People: Navigating Threats in Digital Environments.* June 2025. https://info.thorn.org/hubfs/Research/Thorn_SexualExtortionandYoungPeople_June2025.pdf
35. Thorn & NCMEC. *Trends in Financial Sextortion.* June 2024. https://info.thorn.org/hubfs/Research/Thorn_TrendsInFinancialSextortion_June2024.pdf
36. Olivares-Pasillas, M. C., et al. \"Insurgent Citizenship: How Consumer Complaints on Immigration Scams Inform Policy.\" *Georgetown Immigration Law Journal*, 2024. https://www.law.georgetown.edu/immigration-law-journal/wp-content/uploads/sites/19/2024/03/GT-GILJ230012-1.pdf
37. Barua, R., Koorma, G., Barrington, S., Farid, H. \"Single and Multi-Speaker Cloned Voice Detection.\" arXiv:2307.07683, 2023.
38. San Roman, R., Fernandez, P., et al. \"Proactive Detection of Voice Cloning with Localized Watermarking (AudioSeal).\" ICML 2024. https://arxiv.org/abs/2401.17264
39. Wang, X., Delgado, H., et al. \"ASVspoof 5: Crowdsourced speech data, deepfakes, and adversarial attacks at scale.\" ASVspoof Workshop 2024. https://arxiv.org/abs/2408.08739
40. Lin, L., He, X., et al. \"Preserving Fairness Generalization in Deepfake Detection.\" CVPR 2024.
41. Barrington, S., Bohacek, M., Farid, H. \"DeepSpeak Dataset v1.0.\" arXiv:2408.05366, 2024.
42. Maneriker, P., et al. \"URLTran: Improving Phishing URL Detection Using Transformers.\" MILCOM 2021. https://arxiv.org/abs/2106.05256
43. Sahmoud, T., Mikki, M. \"Spam Detection Using BERT.\" arXiv:2206.02443, 2022.
44. Jamal, S., et al. \"An Improved Transformer-based Model for Detecting Phishing, Spam and Ham Emails.\" *Security and Privacy*, 2024. https://arxiv.org/pdf/2311.04913
45. Shen, L., Wang, Y., Li, Z., Ma, W. \"SMS Spam Detection Using BERT and Multi-Graph Convolutional Networks.\" 2025. https://www.sciencedirect.com/science/article/pii/S2666603025000089
46. Li, Y., et al. \"KnowPhish: Large Language Models Meet Multimodal Knowledge Graphs.\" USENIX Security 2024. https://www.usenix.org/conference/usenixsecurity24/presentation/li-yuexin
47. Lee, J., Xin, P., See-To, M. N., Hooi, B. \"Multimodal Large Language Models for Phishing Webpage Detection and Identification.\" APWG eCrime 2024. https://arxiv.org/abs/2408.05941
48. Wang, Y., Hooi, B. \"PhishAgent: A Robust Multimodal Agent for Phishing Webpage Detection.\" arXiv:2408.10738, 2024.
49. Salman, M., Ikram, M., Basta, N., Kaafar, M. A. \"SpaLLM-Guard: Pairing SMS Spam Detection Using Open-source and Commercial LLMs.\" arXiv:2501.04985, 2025.
50. Nahmias, D., Engelberg, G., Klein, D., Shabtai, A. \"Enhancing Phishing Email Identification with Large Language Models (APOLLO).\" arXiv:2502.04759, 2024.
51. Chataut, R., et al. \"MultiPhishGuard: An LLM-based Multi-Agent System for Phishing Email Detection.\" arXiv:2505.23803, 2025.
52. \"PhishDebate: An LLM-Based Multi-Agent Framework for Phishing Website Detection.\" arXiv:2506.15656, 2025.
53. ElZemity, A. \"Agentic Knowledge Distillation: Autonomous Training of Small Language Models for SMS Threat Detection.\" arXiv:2602.10869, 2026.
54. Mehdi, S., et al. \"SmishX: Explainable SMS Phishing Detection using LLM-Based Agents.\" SOUPS 2024.
55. Frantar, E., Ashkboos, S., Hoefler, T., Alistarh, D. \"GPTQ: Accurate Post-Training Quantization for Generative Pre-trained Transformers.\" ICLR 2023. https://arxiv.org/abs/2210.17323
56. Lin, J., Tang, J., et al. \"AWQ: Activation-aware Weight Quantization for LLM Compression and Acceleration.\" MLSys 2024. https://arxiv.org/abs/2306.00978
57. Xiao, G., Lin, J., et al. \"SmoothQuant: Accurate and Efficient Post-Training Quantization for LLMs.\" ICML 2023. https://arxiv.org/abs/2211.10438
58. Liu, Z., Zhao, C., et al. \"MobileLLM: Optimizing Sub-billion Parameter Language Models for On-Device Use Cases.\" ICML 2024. https://arxiv.org/abs/2402.14905
59. Abdin, M., et al. \"Phi-3 Technical Report: A Highly Capable Language Model Locally on Your Phone.\" arXiv:2404.14219, 2024.
60. Xu, J., Li, Z., et al. \"On-Device Language Models: A Comprehensive Review.\" arXiv:2409.00088, 2024.
61. Yang, H., Zhang, D., et al. \"A First Look at Efficient and Secure On-Device LLM Inference Against KV Leakage.\" ACM MobiArch 2024. https://arxiv.org/abs/2409.04040
62. Ajayi, O. A., Ahmad, I. \"Benchmarking On-Device Machine Learning on Apple Silicon with MLX.\" arXiv:2510.18921, 2024.
63. Gemma Team / Google DeepMind. \"Gemma: Open Models Based on Gemini Research and Technology.\" arXiv:2403.08295, 2024.
64. Gemma Team. \"Gemma 2 Technical Report.\" arXiv:2408.00118, 2024.
65. Gemma Team. \"Gemma 3 Technical Report.\" arXiv:2503.19786, 2025.
66. Google. \"Introducing Gemma 3n: Mobile-First Multimodal AI.\" Developer Blog, 2025. https://developers.googleblog.com/en/introducing-gemma-3n-developer-guide/
67. Google AI Edge Team. \"Bring State-of-the-Art Agentic Skills to the Edge with Gemma 4.\" April 2026. https://developers.googleblog.com/bring-state-of-the-art-agentic-skills-to-the-edge-with-gemma-4/
68. Hugging Face. \"Welcome Gemma 4: Frontier Multimodal Intelligence on Device.\" 2026. https://huggingface.co/blog/gemma4
69. Google. \"Gemma 4: Byte for Byte, the Most Capable Open Models.\" 2026. https://blog.google/innovation-and-ai/technology/developers-tools/gemma-4/
70. Yvinec, E., Culliton, P. \"Gemma 3 QAT Models.\" Google Developers Blog, 2025. https://developers.googleblog.com/en/gemma-3-quantized-aware-trained-state-of-the-art-ai-to-consumer-gpus/
71. Google AI. \"Function Calling with Gemma 4.\" 2026. https://ai.google.dev/gemma/docs/capabilities/text/function-calling-gemma4
72. Unsloth. \"Gemma 4 Fine-tuning Guide.\" 2026. https://unsloth.ai/docs/models/gemma-4/train
73. Apple Machine Learning Research. \"Deploying Transformers on the Apple Neural Engine.\" 2022. https://machinelearning.apple.com/research/neural-engine-transformers
74. Apple. \"Introducing Apple's On-Device and Server Foundation Models.\" 2024. https://machinelearning.apple.com/research/introducing-apple-foundation-models
75. Apple. Core ML Tools Documentation. https://apple.github.io/coremltools/docs-guides/
76. Apple. ExecuTorch Core ML Backend Documentation. https://docs.pytorch.org/executorch/0.7/backends-coreml.html
77. Swift.org. \"On-device ML research with MLX and Swift.\" 2024. https://www.swift.org/blog/mlx-swift/
78. Apple ml-explore. \"mlx-swift.\" https://github.com/ml-explore/mlx-swift
79. MLC AI. \"MLC LLM: Universal LLM Deployment.\" https://llm.mlc.ai/
80. Apple Developer. \"ILMessageFilterExtension.\" https://developer.apple.com/documentation/sms_and_call_reporting/ilmessagefilterextension
81. Capacitor Documentation. \"Custom Native iOS Code.\" https://capacitorjs.com/docs/ios/custom-code
82. Anthropic. \"Introducing the Model Context Protocol.\" November 2024. https://www.anthropic.com/news/model-context-protocol
83. Model Context Protocol Specification (2025-06-18 and November 2025 revisions). https://modelcontextprotocol.io/
84. Model Context Protocol Architecture. https://modelcontextprotocol.io/docs/learn/architecture
85. Model Context Protocol Transports. https://modelcontextprotocol.io/specification/2025-03-26/basic/transports
86. Anthropic. \"MCP Swift SDK.\" https://github.com/modelcontextprotocol/swift-sdk
87. Hou et al. \"MCP Security Analysis.\" arXiv:2503.23278, 2025.
88. Google Developers Blog. \"Announcing the Agent2Agent Protocol (A2A).\" April 2025. https://developers.googleblog.com/en/a2a-a-new-era-of-agent-interoperability/
89. A2A Protocol. Version 1.0 Specification. https://a2a-protocol.org/latest/specification/
90. A2A Project. GitHub Repository. https://github.com/a2aproject/A2A
91. Linux Foundation. \"Linux Foundation Launches the Agent2Agent Protocol Project.\" June 2025. https://www.linuxfoundation.org/press/linux-foundation-launches-the-agent2agent-protocol-project-to-enable-secure-intelligent-communication-between-ai-agents
92. Yao, S., et al. \"ReAct: Synergizing Reasoning and Acting in Language Models.\" ICLR 2023. https://arxiv.org/abs/2210.03629
93. Schick, T., et al. \"Toolformer: Language Models Can Teach Themselves to Use Tools.\" NeurIPS 2023. https://arxiv.org/abs/2302.04761
94. Wu, Q., et al. \"AutoGen: Enabling Next-Gen LLM Applications via Multi-Agent Conversation Framework.\" arXiv:2308.08155, 2023.
95. Hong, S., et al. \"MetaGPT: Meta Programming for A Multi-Agent Collaborative Framework.\" ICLR 2024. https://arxiv.org/abs/2308.00352
96. llama.cpp GBNF Grammars. https://github.com/ggml-org/llama.cpp/blob/master/grammars/README.md
97. ObjectBox. On-Device Vector Search Documentation. https://docs.objectbox.io/on-device-vector-search
98. Google. Safe Browsing API v4 Documentation.
99. AARP. \"Scams Take Toll on Older Asian American Pacific Islanders.\" FCC. https://www.fcc.gov/scams-take-toll-older-asian-american-pacific-islanders
100. FTC. \"Visit FTC.gov/Languages for Fraud & Scam Advice in 12 Languages.\" 2023. https://consumer.ftc.gov/consumer-alerts/2023/02/visit-ftcgovlanguages-fraud-scam-advice-12-languages