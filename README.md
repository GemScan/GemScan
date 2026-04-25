# GemScan

On-device AI scam detection that protects elders and youth from scams, sextortion, and fraud — without sending data to the cloud.

## Why this exists

In 2023, a mother in Arizona answered her phone and heard her teenage daughter screaming in terror. A voice — indistinguishable from her daughter's own — begged for help, claiming she'd been kidnapped. A man then demanded a ransom. The daughter was safe at home the entire time. A three-second audio clip scraped from social media was all it took to clone her voice.

That same year, over 12,600 minors were financially sextorted after being manipulated into sharing intimate images online. At least 20 died by suicide. Meanwhile, the FBI documented **$16.6 billion in US fraud losses in 2024 (+33% YoY)**, with elder victims accounting for $4.885 billion. Globally, scams now steal an estimated **$1 trillion per year**.

The populations most at risk — elderly adults, teenagers, non-native speakers — are precisely the ones current defences fail. Carrier spam filters use blocklists. OS-level silencers don't understand context. Every third-party "safety" app ships your conversations to a cloud server.

GemScan was built on a simple premise: **the people most targeted by these attacks deserve protection that works in their language, respects their privacy, and runs on the phone they already own.**

## What it does

GemScan analyses SMS, emails, URLs, screenshots, and voice messages to detect scam patterns. All inference runs locally on-device using Gemma 4 models — sensitive content never leaves the phone.

## Architecture at a glance

```mermaid
flowchart TD
    User([User Input])
    User --> UI[Next.js UI + Capacitor Bridge]
    UI --> Orch[OrchestratorAgent]

    Orch --> Text[TextAgent · E2B]
    Orch --> URL[URLAgent · E2B]
    Orch --> Img[ImageAgent · E4B]
    Orch --> Voice[VoiceAgent · E4B]
    Orch -.->|disputed| Judge[JudgeAgent · E4B]

    Text & URL & Img & Voice & Judge --> MCP[10 MCP Servers]
    Text & URL & Img & Voice & Judge --> Inf[Inference Engine\nMLX Swift · llama.cpp · DistilBERT]

    MCP --> Result([AgentResult → Verdict])
    Inf --> Result
    Result --> UI

    Ext[iOS Extensions\nSMS Filter · Call Dir · Share · Siri · Safari] -.-> Inf
```

A six-agent pipeline coordinated by Swift actors. The OrchestratorAgent picks a tier (E2B for cheap text triage, E4B for image / audio / disputed cases) and routes through ten in-process MCP servers for grounding (URL reputation, contacts, scam-pattern recall, and friends).

| Agent | Model | Handles |
|-------|-------|---------|
| TextAgent | E2B (2.3B) | SMS, email classification |
| URLAgent | E2B | URL reputation, WHOIS lookup |
| ImageAgent | E4B (4.5B) | Screenshot analysis, QR detection |
| VoiceAgent | E4B + Whisper | Audio transcription, deepfake detection |
| JudgeAgent | E4B | Adjudication for disputed verdicts |
| OrchestratorAgent | E4B | Routing, escalation (E2B → E4B at confidence < 0.75) |

## Tech stack

| Layer | Technology |
|-------|-----------|
| UI | Next.js 14 (App Router) + Tailwind |
| Bridge | Capacitor 6 (TypeScript ↔ Swift) |
| Inference | MLX Swift (primary) / llama.cpp (fallback) |
| Models | Gemma 4 E2B, E4B, DistilBERT |
| Audio | Whisper-small + AudioSeal |
| State | Zustand + React Query |

## Where to go next

| You are… | Start here |
| --- | --- |
| A developer wanting to run, build, or contribute code | [CONTRIBUTING.md](CONTRIBUTING.md) |
| Curious about system design | [docs/architecture.md](docs/architecture.md) |
| Validating model capabilities (Colab) | [notebooks/README.md](notebooks/README.md) |
| Tracking the non-code work to ship | [tasks/99_humantasks.md](tasks/99_humantasks.md) |
| Looking for any other guide | [docs/](docs/) |

## License

See [LICENSE](LICENSE).
