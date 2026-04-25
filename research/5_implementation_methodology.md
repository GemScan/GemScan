# Implementation Methodology

---

## Section 4 — Methodology (Data, Fine-Tuning, Benchmarking, User Testing, Deployment)

### 4.1 Execution Timeline

See `6_planning.md §4.1` for the week-by-week hackathon execution timeline. The methodology sections below (§4.2–§4.7) provide the detailed rationale and specification behind each milestone.

### 4.2 Data Collection and Fine-Tuning Corpus

We will fine-tune on a **composite dataset of approximately 30,000–50,000 labelled examples** assembled from:

- **Enron Email Corpus** (spam labels) — classical phishing baselines.
- **SMS Spam Collection (UCI)** — 5,574 labelled SMS.
- **PhishTank** and **Nazario Phishing Corpus** — verified phishing URLs and emails.
- **APWG eCrime Exchange** — multimodal phishing samples.
- **FTC Consumer Sentinel 2022–2024 narrative text** (public portions) [1].
- **Synthetic data distilled from a larger teacher (Gemini 2.5 Pro or Claude Opus 4.5)** following the **Agentic Knowledge Distillation recipe (ElZemity 2026, arXiv 2602.10869)** [53], which reached 94 % accuracy / 96 % recall distilling into sub-billion-parameter students.
- **Multilingual augmentations** generated per region: Spanish (Smart Business Corp patterns), Hindi (digital-arrest templates), Japanese (ore-ore scripts), Mandarin (fake-consulate and pig-butchering openers).
- **Audio-deepfake evaluation only** — ASVspoof 5 (Wang et al. 2024) [39] + DeepSpeak v1.0 (Barrington et al. 2024) [41].
- **Image-deepfake evaluation only** — OpenForensics, FaceForensics++, curated scam-screenshot corpus.
- **SMS triage classifier (distilled, ≤ 5 MB)** — a separate binary-classification dataset of ~10,000 SMS examples (scam vs. legitimate), drawn from the UCI SMS Spam Collection, PhishTank smishing samples, and synthetic augmentations, used exclusively to train the lightweight DistilBERT classifier that runs inside the memory-constrained SMS Filter extension (see §3.11). This dataset is simpler than the main corpus: binary labels only, no chain-of-thought rationale, English-primary with limited multilingual coverage.

Each example carries `{sender, body, metadata, label, rationale, language, region, vulnerable_group}`. We mix **75 % reasoning-style chain-of-thought examples** with 25 % direct classification to preserve Gemma 4's agentic capability [67]; unmixed supervised fine-tuning is known to collapse planning skill.

### 4.3 Fine-Tuning Approach: LoRA/QLoRA with Unsloth

Following Unsloth's published **Gemma 4 Fine-tuning Guide** [72], we apply **rank-16 LoRA** with `lora_alpha=32`, `dropout=0.05`, targeting `q_proj, k_proj, v_proj, o_proj, gate_proj, up_proj, down_proj`. Training uses `per_device_train_batch_size=4`, `gradient_accumulation_steps=4`, `lr=2e-4`, cosine schedule, `bf16=True`, and 3 epochs. **E2B QLoRA fits on a free Kaggle T4 (16 GB); E4B QLoRA fits on a single A10/A100 40 GB.** Chat-template drift is the single most common post-fine-tune bug; we verify that `tok.apply_chat_template(msgs, tokenize=False, add_generation_prompt=True)` in Python matches the MLX Swift Tokenizer output byte-for-byte.

**SMS triage classifier (distilled).** In parallel with the Gemma 4 fine-tuning, we train the lightweight DistilBERT-based binary classifier required for the SMS Filter extension. Starting from `distilbert-base-uncased`, we fine-tune for 5 epochs on the ~10,000-example triage dataset (§4.2) using standard cross-entropy loss, `lr=2e-5`, batch size 32. The resulting model is exported to Core ML (iOS, via `coremltools`) and TFLite (Android) and verified to fit within the extension's 50 MB memory ceiling at ≤ 5 MB quantised. This step is deliberately separate from the main Gemma fine-tuning to avoid conflating the two training objectives and timelines.

### 4.4 Benchmarking Protocol

**Accuracy benchmarks.** Precision, recall, F1, and AUROC on held-out sets partitioned by language, region, and vulnerable group. Compare GemScan-E2B and -E4B against (a) cloud GPT-4o/Claude Opus 4.5 baselines, (b) Norton Genie and McAfee Scam Detector where APIs allow, and (c) the SpaLLM-Guard [49] and APOLLO [50] academic baselines.

**Latency benchmarks.** First-token latency, full-analysis latency (text, URL, image, audio), and end-to-end user-visible response time for the share-sheet flow, measured on **iPhone 14 (A15, 6 GB)** and a comparable mid-range Android device as the two reference platforms [62].

**Threshold calibration.** The confidence score below which E2B escalates to E4B is a tunable parameter — too low wastes battery loading E4B constantly; too high leaves borderline scams unescalated. We will sweep the threshold from 0.5 to 0.9 on the held-out validation set, selecting the value that maximises F1 on the multi-modal adversarial corpus (§H3) subject to the constraint that E4B is loaded in ≤ 15 % of interactions in Passive mode. The calibrated threshold will be reported alongside H1 and H3 results.

**Memory benchmarks.** Peak RSS across E2B-only, E4B-only, and multi-agent pipelined modes; verify no OOM on the 6 GB baseline device [61].

**Battery benchmarks.** Battery drain per hour for Passive, Active, and Guardian modes; thermal-throttling onset time for continuous inference.

**Adversarial robustness.** Replay a suite of **prompt-injection attacks documented by Hou et al. (arXiv 2503.23278)** [87] and **Invariant Labs**, plus novel TTS and voice-clone engines held out from training, to measure cross-vocoder generalisation (a published weakness of state-of-the-art detectors per arXiv 2510.21004).

### 4.5 User Testing with Vulnerable Populations

In collaboration with a local senior centre and an immigrant-services non-profit, we will recruit **≥ 10 elders (mean age 70+) and ≥ 10 non-native speakers across at least 3 languages (Spanish, Mandarin, Hindi)**. Each participant completes a structured protocol:

1. Pre-survey on scam concern and digital confidence.
2. Hands-on walkthrough of GemScan's Share Sheet, voice-first flow, and Trusted Contact setup.
3. Realistic scam scenario (scripted SMS, deepfake voice memo, fake TikTok Shop screenshot) — does the participant notice the warning, understand the explanation, and choose correctly?
4. Post-survey on trust, perceived clarity of explanation, and willingness to continue using.

Outcome measures include **task success rate, explanation comprehension, Net Promoter Score, and qualitative coding of confusion/delight moments**. The participant sample is designed to operationalise the LEP-vulnerability findings of Olivares-Pasillas [36] and AARP's multicultural surveys [27][99], and the cognitive-vulnerability findings of Han et al. [30].

### 4.6 Deployment Pipeline and TestFlight

The build is produced by a **GitHub Actions workflow** that runs `next build && next export`, syncs to Capacitor [81], signs with platform certificates, and uploads to **TestFlight** (iOS) or the **Play Console internal track** (Android) via `fastlane`. Model weights are downloaded on first launch (with a compliant progress UI and user-consent screen) rather than bundled in the app package, keeping the install footprint under 100 MB on both platforms.

### 4.7 Open-Source Strategy and Licensing

GemScan will be released under the **Apache 2.0 license**, matching Gemma 4's own Apache 2.0 licensing [67][68]. All code (Swift, TypeScript, fine-tuning scripts) lives on GitHub; weights and GGUF/MLX artifacts live on Hugging Face [68]. Data annotations derived from public datasets inherit their upstream licenses. We will submit the work to the **Gemma 4 Good Hackathon** on Kaggle, accompany the submission with the thesis in this document, and — win or lose — maintain the project as a public good aligned with the hackathon's social-impact framing.

---

## Section 5 — Hypotheses

We formulate five testable hypotheses that together argue the case for GemScan.

**H1. On-device accuracy parity.** A LoRA-fine-tuned Gemma 4 E4B running **Q4_K_M on-device** [55] will achieve **≥ 92 % F1 on a composite English scam-detection benchmark** (SMS, email, URL, screenshot), **within 3 points** of a cloud GPT-4o baseline, and **outperform the Salman 2025 SpaLLM-Guard zero-shot baseline [49] by ≥ 10 F1 points**.

**H2. Multi-modal outperforms single-modal.** The six-agent pipeline that jointly analyses text + URL + image + audio will produce **≥ 7 % absolute F1 improvement** over any single-modal baseline on a realistic multi-modal scam corpus (synthetic pig-butchering chains with fake profile photos, deepfake voice memos, and fraudulent investment-app screenshots), reflecting the same trend observed by **PhishAgent (Wang & Hooi 2024)** [48] and **MultiPhishGuard (Chataut et al. 2025)** [51].

**H3. Agentic MCP orchestration beats static rules.** Against a **multi-turn adversarial scammer corpus** simulating romance and pig-butchering campaigns over 10+ turns, the agentic architecture with MCP tool queries [82][83] and multi-agent debate adjudication will reduce **false-negative rate by ≥ 30 %** compared to a static rule-based or single-shot-LLM baseline, consistent with the **PhishDebate (arXiv 2506.15656)** [52] and **ScriptMind (arXiv 2601.13581)** published gains.

**H4. Privacy-first drives adoption.** In the user study, **≥ 80 % of elderly and ≥ 85 % of LEP participants** will report *greater trust* in an on-device solution than in a cloud-based equivalent, and stated willingness-to-continue-using will exceed **70 %** — a threshold above the ~45 % long-term retention reported by Truecaller analytics and comparable consumer-security apps, supported by Koning et al. (2024) findings on fraud-knowledge and self-efficacy.

**H5. Native-language coaching cuts victimisation.** Presenting scam explanations in the user's native language at a sixth-grade reading level will produce a **statistically significant (p < 0.05) reduction in simulated-scam victimisation** in a pre-post design, with effect size **≥ 0.4 (Cohen's d)** against an English-only control — operationalising the LEP-vulnerability findings of **Olivares-Pasillas (Georgetown 2024)** [36] and AARP's multicultural fraud surveys [27][99].

---

## References

1. Federal Trade Commission. *Consumer Sentinel Network Data Book 2024.* 2025. https://www.ftc.gov/system/files/ftc_gov/pdf/csn-annual-data-book-2024.pdf
27. AARP. "Vital Voices: Fraud Concerns of Older Adults." 2025. https://www.aarp.org/pri/topics/aging-experience/demographics/vital-voices-fraud-concerns-older-adults.html
30. Han, S. D., Boyle, P. A., et al. "Cognitive and Neuroimaging Correlates of Financial Exploitation Vulnerability in Older Adults." *Neuroscience & Biobehavioral Reviews*, 2023. https://pmc.ncbi.nlm.nih.gov/articles/PMC9815424/
36. Olivares-Pasillas, M. C., et al. "Insurgent Citizenship: How Consumer Complaints on Immigration Scams Inform Policy." *Georgetown Immigration Law Journal*, 2024. https://www.law.georgetown.edu/immigration-law-journal/wp-content/uploads/sites/19/2024/03/GT-GILJ230012-1.pdf
39. Wang, X., Delgado, H., et al. "ASVspoof 5: Crowdsourced speech data, deepfakes, and adversarial attacks at scale." ASVspoof Workshop 2024. https://arxiv.org/abs/2408.08739
41. Barrington, S., Bohacek, M., Farid, H. "DeepSpeak Dataset v1.0." arXiv:2408.05366, 2024.
48. Wang, Y., Hooi, B. "PhishAgent: A Robust Multimodal Agent for Phishing Webpage Detection." arXiv:2408.10738, 2024.
49. Salman, M., Ikram, M., Basta, N., Kaafar, M. A. "SpaLLM-Guard: Pairing SMS Spam Detection Using Open-source and Commercial LLMs." arXiv:2501.04985, 2025.
50. Nahmias, D., Engelberg, G., Klein, D., Shabtai, A. "Enhancing Phishing Email Identification with Large Language Models (APOLLO)." arXiv:2502.04759, 2024.
51. Chataut, R., et al. "MultiPhishGuard: An LLM-based Multi-Agent System for Phishing Email Detection." arXiv:2505.23803, 2025.
52. "PhishDebate: An LLM-Based Multi-Agent Framework for Phishing Website Detection." arXiv:2506.15656, 2025.
53. ElZemity, A. "Agentic Knowledge Distillation: Autonomous Training of Small Language Models for SMS Threat Detection." arXiv:2602.10869, 2026.
55. Frantar, E., Ashkboos, S., Hoefler, T., Alistarh, D. "GPTQ: Accurate Post-Training Quantization for Generative Pre-trained Transformers." ICLR 2023. https://arxiv.org/abs/2210.17323
56. Lin, J., Tang, J., et al. "AWQ: Activation-aware Weight Quantization for LLM Compression and Acceleration." MLSys 2024. https://arxiv.org/abs/2306.00978
61. Yang, H., Zhang, D., et al. "A First Look at Efficient and Secure On-Device LLM Inference Against KV Leakage." ACM MobiArch 2024. https://arxiv.org/abs/2409.04040
62. Ajayi, O. A., Ahmad, I. "Benchmarking On-Device Machine Learning on Apple Silicon with MLX." arXiv:2510.18921, 2024.
67. Google AI Edge Team. "Bring State-of-the-Art Agentic Skills to the Edge with Gemma 4." April 2026. https://developers.googleblog.com/bring-state-of-the-art-agentic-skills-to-the-edge-with-gemma-4/
68. Hugging Face. "Welcome Gemma 4: Frontier Multimodal Intelligence on Device." 2026. https://huggingface.co/blog/gemma4
72. Unsloth. "Gemma 4 Fine-tuning Guide." 2026. https://unsloth.ai/docs/models/gemma-4/train
81. Capacitor Documentation. "Custom Native iOS Code." https://capacitorjs.com/docs/ios/custom-code
82. Anthropic. "Introducing the Model Context Protocol." November 2024. https://www.anthropic.com/news/model-context-protocol
83. Model Context Protocol Specification (2025-06-18 and November 2025 revisions). https://modelcontextprotocol.io/
87. Hou et al. "MCP Security Analysis." arXiv:2503.23278, 2025.
88. Google Developers Blog. "Announcing the Agent2Agent Protocol (A2A)." April 2025. https://developers.googleblog.com/en/a2a-a-new-era-of-agent-interoperability/
89. A2A Protocol. Version 1.0 Specification. https://a2a-protocol.org/latest/specification/
99. AARP. "Scams Take Toll on Older Asian American Pacific Islanders." FCC. https://www.fcc.gov/scams-take-toll-older-asian-american-pacific-islanders
