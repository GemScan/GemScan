# Architecture

System overview of GemScan: on-device AI scam detection for iOS.

---

## Architecture Diagram

```
┌──────────────────────────────────────────────────────────────┐
│  Next.js 14 (App Router) + Capacitor 6 — UI Layer           │
│  ┌────────────┐  ┌────────────┐  ┌──────────────────────┐   │
│  │ ScanPage   │  │ HistoryPage│  │ GuardianMode settings│   │
│  └─────┬──────┘  └─────┬──────┘  └──────────┬───────────┘   │
│        │               │                     │               │
│        └───────────────┬┘                    │               │
│                        ▼                     │               │
│              GemmaPlugin Bridge (Capacitor)  │               │
└────────────────────────┬─────────────────────┘               │
                         │                                     │
┌────────────────────────▼─────────────────────────────────────┘
│  Swift Layer — GemmaKit Package                              │
│                                                              │
│  ┌──────────────────┐                                        │
│  │ OrchestratorAgent │◄─── Entry point for all scans        │
│  └──┬───┬───┬───┬───┘                                        │
│     │   │   │   │                                            │
│     ▼   ▼   ▼   ▼                                            │
│  ┌────┐┌───┐┌─────┐┌─────┐                                  │
│  │Text││URL││Image││Voice│  ← Specialist agents              │
│  └──┬─┘└─┬─┘└──┬──┘└──┬──┘                                  │
│     │    │     │      │                                      │
│     └────┴─────┴──────┘                                      │
│              │                                               │
│              ▼                                               │
│        ┌───────────┐                                         │
│        │ JudgeAgent │  ← Final verdict                      │
│        └─────┬─────┘                                         │
│              │                                               │
│              ▼                                               │
│     10 MCP Servers (in-process, no network)                  │
│     ┌──────┬──────┬───────┬───────┬────────┐                 │
│     │URLRep│PhoneDB│ImageML│Regex │Contacts│ ...             │
│     └──────┴──────┴───────┴───────┴────────┘                 │
└──────────────────────────────────────────────────────────────┘
```

---

## Data Flow

1. **User input** — text, URL, image, or voice enters via the UI.
2. **GemmaPlugin bridge** — Capacitor native bridge serializes input into an `AgentTask`.
3. **OrchestratorAgent** — routes the task to the appropriate specialist agent(s).
4. **Specialist agents** (Text, URL, Image, Voice) — run inference and call MCP tools.
5. **MCP tools** — 10 in-process servers provide URL reputation, phone DB lookup, image classification, regex matching, contacts access, etc.
6. **JudgeAgent** — aggregates specialist results, applies escalation logic, produces `AgentResult`.
7. **AgentResult** — serialized back through the bridge and rendered in the UI.

---

## Key Types

```swift
struct AgentTask {
    let id: UUID
    let inputType: InputType        // .text, .url, .image, .voice
    let payload: Data
    let metadata: [String: String]
}

struct AgentResult {
    let taskId: UUID
    let verdict: ScamVerdict
    let confidence: Double          // 0.0 – 1.0
    let explanation: String
    let agentTrail: [AgentTrailEntry]
}

enum ScamVerdict: String, Codable {
    case safe
    case suspicious
    case scam
}
```

---

## Inference Engine

| Backend | Role | Framework |
|---------|------|-----------|
| **MLX** | Primary | MLX Swift — Apple Silicon optimized |
| **llama.cpp** | Fallback | C++ via Swift bridging header |

MLX is used on all Apple Silicon devices. llama.cpp activates only if MLX initialization fails (rare, but possible on older simulators).

### Model Tiers

| Model | Parameters | Size | Use case |
|-------|-----------|------|----------|
| Gemma E2B | 2.3B | ~1.4 GB | Default on-device inference |
| Gemma E4B | 4.5B | ~2.8 GB | Escalation model for ambiguous cases |
| DistilBERT | 66M | ~50 MB | SMS Filter extension (real-time) |

### Escalation Logic

```
if E2B.confidence < 0.75 {
    escalate to E4B
    JudgeAgent merges both results
}
```

The Judge weights the E4B result higher when escalation fires.

---

## Agent Actors (6)

| Actor | Responsibility |
|-------|---------------|
| `OrchestratorAgent` | Routes tasks, manages lifecycle |
| `TextAgent` | Analyzes text messages for scam patterns |
| `URLAgent` | Checks URLs against reputation DBs and heuristics |
| `ImageAgent` | Runs image classification for phishing screenshots |
| `VoiceAgent` | Transcribes and analyzes voice messages |
| `JudgeAgent` | Aggregates results, applies escalation, final verdict |

All agents are Swift actors — concurrency-safe by design.

---

## MCP Servers (10)

All servers run in-process. No network calls leave the device for MCP operations.

| Server | Function |
|--------|----------|
| URLReputation | Domain/URL risk scoring |
| PhoneDB | Known scam number lookup |
| ImageClassifier | Phishing screenshot detection |
| RegexMatcher | Pattern matching for common scam templates |
| ContactsAccess | Verify sender against user contacts |
| SMSParser | Extract structured data from SMS |
| CallMetadata | Enrich call records |
| DeviceContext | Battery, network, locale info |
| UserPreferences | Sensitivity and filter settings |
| AuditLog | Append-only scan history |

---

## iOS Extensions (5)

| Extension | Purpose | Constraints |
|-----------|---------|-------------|
| SMS Filter | Real-time message filtering | 50 MB memory, 5s deadline |
| Call Directory | Block/identify phone numbers | Int64 phone format |
| Share Extension | Accept shared content for scanning | 120 MB memory |
| App Intents | Siri and Shortcuts integration | — |
| Safari Content Blocker | Block known scam domains | JSON rule list |

---

## Milestone Map

| Milestone | Scope |
|-----------|-------|
| **M0** | Project scaffolding, CI, mock infrastructure |
| **M1** | Text agent + basic inference pipeline |
| **M2** | URL agent + MCP URL reputation server |
| **M3** | Image agent + phishing screenshot classifier |
| **M4** | Voice agent + transcription pipeline |
| **M5** | Judge agent + escalation logic |
| **M6** | iOS extensions (SMS Filter, Call Directory) |
| **M7** | Guardian Mode (Ed25519, relay, APNs) |
| **M8** | Safari Blocker + Share Extension + App Intents |
| **M9** | Performance optimization, WCAG audit, release |

---

## Directory Layout

```
GemScan/
├── src/                    # Next.js application
│   ├── app/                # App Router pages
│   ├── components/         # React components
│   ├── hooks/              # Custom React hooks
│   ├── lib/                # Core logic, types, mocks
│   ├── styles/             # Tailwind + global CSS
│   └── test/               # Test utilities
├── ios/
│   └── App/                # Capacitor iOS shell + Swift packages
├── e2e/                    # Playwright E2E tests
├── tests/                  # Additional test suites
├── scripts/                # Build and utility scripts
├── specs/                  # Feature specifications
├── research/               # Research documents
├── tasks/                  # Task tracking
├── docs/                   # Developer documentation (this folder)
├── capacitor.config.ts     # Capacitor configuration
├── next.config.mjs         # Next.js configuration
├── vitest.config.mts       # Vitest configuration
├── playwright.config.ts    # Playwright configuration
└── manifest.json           # Model manifest
```
