# GemScan

On-device AI safety app that protects elders and youth from scams, sextortion, and fraud — without sending data to the cloud.

## Why this exists

In 2023, a mother in Arizona answered her phone and heard her teenage daughter screaming in terror. A voice — indistinguishable from her daughter's own — begged for help, claiming she'd been kidnapped. A man then demanded a ransom. The daughter was safe at home the entire time. A three-second audio clip scraped from social media was all it took to clone her voice.

That same year, across fourteen months, over 12,600 minors — mostly boys aged 14 to 17 — were financially sextorted after being manipulated into sharing intimate images online. At least 20 of them died by suicide. By 2024, annual sextortion victim counts had reached 54,000.

Meanwhile, a Japanese great-grandmother receives a phone call. Her "grandson" is crying. He's in legal trouble and needs cash — now, before her daughter finds out. The ore ore sagi scam ("it's me, grandma, it's me") has drained Japanese elderly victims of ¥324 billion (~$2.1 billion) in a single year. In the US, 7,500+ seniors each lost more than $100,000 to fraud in 2024 alone — many losing retirement savings accumulated over a lifetime, leaving them dependent on public assistance.

These aren't edge cases. The FBI documented **$16.6 billion in US fraud losses in 2024 (+33% YoY)**, elder victims accounting for $4.885 billion of that. Globally, scams now steal an estimated **$1 trillion per year**, with only 4% of victims recovering any money. Generative AI has industrialised the fraud pipeline: voice cloning requires three seconds of audio, AI-written phishing campaigns achieve 54% click-through rates at 5% of the cost of human-crafted ones, and deepfake video calls now impersonate both loved ones and government officials in real time.

The populations most at risk — elderly adults experiencing early cognitive decline, teenagers navigating social pressure online, non-native speakers unfamiliar with institutional authority signals — are precisely the ones current defences fail. Carrier spam filters use blocklists. OS-level silencers don't understand context. And every third-party "safety" app ships your most sensitive conversations to a cloud server you don't control.

GemScan was built on a simple premise: **the people most targeted by these attacks deserve protection that works in their language, respects their privacy, and runs on the phone they already own.**

## What it does

GemScan analyzes calls, SMS, emails, URLs, screenshots, and voice messages in real time to detect scam patterns. All inference runs locally on-device using open-source Gemma 4 models, so sensitive content never leaves the phone.

## Architecture

A six-agent pipeline built on A2A (Agent-to-Agent) orchestration with MCP (Model Context Protocol) servers:

- **Screening Agent (E2B ~2.3B)** — always-on lightweight triage
- **Reasoning Agent (E4B ~4.5B)** — deeper multi-turn analysis for complex cases
- **MCP Servers** — in-process analyzers for each input modality (call, SMS, email, URL, screenshot, voice)
- **Voice Interface** — primary interaction mode for accessibility

## Tech stack

- Next.js + Capacitor (iOS)
- Apple MLX Swift for on-device inference
- Gemma 4 E2B / E4B models

## Targets

- ≥ 92% F1 on scam-detection benchmarks
- < 3 GB RAM and < 6% hourly battery drain on iPhone 14
- Multilingual, voice-first UX for vulnerable populations
