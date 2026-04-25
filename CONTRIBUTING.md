# Contributing to GemScan

This is the single source of truth for contributing to GemScan: how to set
up, how to develop, what code style we use, how PRs and commits are
structured, and what CI expects. For the codebase deep-dive, see
[docs/architecture.md](docs/architecture.md).

---

## 1 · Prerequisites

| Tool | Version | Notes |
| --- | --- | --- |
| Node.js | 20.x | `nvm use 20` recommended |
| npm | 10.x | ships with Node 20 |
| Xcode | 15.3+ | only required for iOS builds; web mock works without it |
| CocoaPods | 1.15+ | `sudo gem install cocoapods` (iOS only) |
| Python | 3.11+ | only for the `notebooks/` model-validation work |

You can do 90% of UI / agent / MCP development with **just Node** — the iOS
shell is loaded with a mock plugin in the browser so the agent flows are
fully exercisable without a phone or simulator.

## 2 · First run (web mock)

```bash
git clone <this-repo> && cd GemScan
npm install
npm run dev
```

Open <http://localhost:3000>. The app loads with a mock `GemmaPlugin` that
returns deterministic fixtures from `src/lib/gemma/__fixtures__/golden.ts`.
Every agent path, every UI screen, every Settings toggle is reachable here.

## 3 · First run (iOS)

```bash
npm run build           # static-export the Next.js app
npx cap sync ios        # copy web build + plugin config into iOS shell
npx cap open ios        # opens Xcode
```

In Xcode:

1. Select an iPhone simulator (iPhone 15 Pro / iPhone 17 Pro both fine) or a
   paired physical device.
2. ⌘R to build + run.
3. The first build will be the **mock-fallback** path — see §6 for what
   that means and how to wire the real native plugin.

Hit a sandbox / signing error? Check
[tasks/99_humantasks.md](tasks/99_humantasks.md) §H1 (signing) and §H2
(Xcode UI wiring) — those are human-only setup steps.

## 4 · Project map

```text
GemScan/
├── src/                   Next.js web app (TypeScript)
│   ├── app/               App Router pages — one folder per route
│   ├── components/        React components (+ co-located unit tests)
│   ├── hooks/             useTokenStream, useModelDownload, useLocale, …
│   └── lib/
│       ├── gemma/         GemmaPlugin interface · mock · native bridge
│       ├── agents/        Mock orchestrator (web-only)
│       ├── mcp/           Mock MCP client (web-only)
│       ├── i18n/          5 locales: en, hi, ja, es, zh-Hans
│       └── store.ts       Zustand store (screening mode, guardian, …)
├── ios/App/
│   ├── App/               Capacitor host app target
│   │   ├── GemmaPlugin.swift            Capacitor 6 bridge
│   │   ├── GemmaPlugin+CallKit.swift    CallKit hooks
│   │   └── GemmaPlugin+MCP.swift        MCP wiring
│   ├── GemmaKit/          Swift package — agents, MCP, inference engine
│   │   └── Sources/
│   │       ├── Inference/   ModelLoader, MLX/llama.cpp backends
│   │       ├── Agents/      6 agent actors + grammars + prompts
│   │       ├── MCP/         10 MCP server actors
│   │       ├── Router/      MessageRouter
│   │       ├── Extensions/  SharedContainerSchema
│   │       ├── Logging/     GemScanLogger, MetricsStore
│   │       └── Guardian/    GuardianKeyManager
│   └── Extensions/        SMS Filter, Call Dir, Share, Siri, Safari
├── docs/                  developer guides (architecture, testing, release, …)
├── notebooks/             Colab notebooks for model-capability validation
├── specs/                 implementation specs (one per milestone)
├── tasks/                 milestone task lists + 99_humantasks.md
├── e2e/                   Playwright E2E tests
└── scripts/               build-and-test.sh + helpers
```

## 5 · Daily dev loop

```bash
# Fast iteration (≈ 3 s)
npm run typecheck
npm run test:unit

# Full pre-push check (≈ 30 s)
./scripts/build-and-test.sh --web

# Format + lint
npm run lint
npm run format       # auto-fix
```

The `scripts/build-and-test.sh` wrapper has flags for every layer:

| Flag | What it runs |
| --- | --- |
| (none) | everything (web + iOS + e2e) |
| `--quick` | typecheck + unit tests only (~3 s) |
| `--web` | full TypeScript pipeline (~15 s) |
| `--ios` | Swift pipeline (needs Xcode) |
| `--e2e` | TypeScript + Playwright E2E |
| `--ci` | full CI-equivalent |

## 6 · The mock-vs-native runtime model (read this once)

GemScan has **two implementations** of `GemmaPlugin`. Knowing which one is
running explains 90% of "why doesn't it work on device?" questions.

| File | Where it runs | What it does |
| --- | --- | --- |
| `src/lib/gemma/mock.ts` | Web (`npm run dev`) and iOS-without-native | Returns fixture data; simulates download progress; runs unload timers |
| `src/lib/gemma/native.ts` | iOS when the Swift `GemmaPlugin` class is compiled into the App target | Forwards every call across the Capacitor bridge to `ios/App/App/GemmaPlugin.swift` |

`src/lib/gemma/index.ts` picks one at startup. On iOS, it tries `native`
first; if Capacitor reports `PluginNotImplemented`, it logs a warning and
silently falls back to `mock`. **This is intentional**: it keeps the UI
testable on a fresh Xcode checkout before anyone has wired the Swift files
into the App target.

The Xcode wiring step is human-only (drag-and-drop in Xcode UI). It is
documented as task **H2.2** in
[tasks/99_humantasks.md](tasks/99_humantasks.md). Until that's done, expect
the mock to be active even on a physical iPhone.

## 7 · Where to add a feature

| Adding… | Edit | Don't forget |
| --- | --- | --- |
| A new UI screen | `src/app/<route>/page.tsx` (+ link from `TabBar.tsx`) | i18n strings in `src/lib/i18n/strings.ts` for all 5 locales |
| A new React component | `src/components/<Name>.tsx` (+ `__tests__/<Name>.test.tsx`) | Vitest test before the implementation |
| A new agent type | TypeScript: `src/lib/agents/`. Swift: `ios/App/GemmaKit/Sources/Agents/<Name>Agent.swift` | Update `AgentTaskType` in `src/lib/gemma/types.ts` and the matching Swift enum |
| A new MCP server | `ios/App/GemmaKit/Sources/MCP/<Name>Server.swift` | Wire into `GemmaPlugin+MCP.swift` and add a mock in `src/lib/mcp/` |
| A new iOS extension | `ios/App/Extensions/<Name>/` | See [docs/extension-setup.md](docs/extension-setup.md); needs Xcode target work |
| A new locale | `src/lib/i18n/strings.ts` + Settings page languages array | Run `notebooks/13_multilingual.ipynb` to verify model F1 before exposing |

## 8 · Testing

### Where each layer lives

| Layer | Tool | Where | Coverage bar |
| --- | --- | --- | --- |
| TypeScript unit | Vitest | `src/**/__tests__/` | 80% on touched code |
| TypeScript E2E | Playwright | `e2e/` | golden-path per route |
| Swift unit | XCTest | `ios/App/GemmaKit/Tests/` | mocks for I/O |

### Required tests per change type

| Change type | Required tests |
| --- | --- |
| New TypeScript utility | Unit test with 80%+ coverage |
| New React component | Component test with key interactions |
| New Swift agent / MCP server | XCTest with mock infrastructure |
| UI behavior change | E2E Playwright test |
| iOS extension change | XCTest + manual verification notes in PR |
| Bug fix | Regression test that fails without the fix |

Bug-fix regression tests are non-negotiable — they are the cheapest way to
make sure the bug stays gone.

For deeper test infrastructure documentation see
[docs/testing.md](docs/testing.md).

## 9 · Models and validation

GemScan does not ship model weights. Two flavors of work get you there:

- **On a Mac (model prep):** convert Gemma 4 → MLX or GGUF, host on a CDN,
  wire the download URLs into `GemmaPlugin.swift`. Walk-through:
  [tasks/99_humantasks.md](tasks/99_humantasks.md) §H3–H4.
- **In a browser (Colab):** prove the model can do what the spec promises
  before constants harden into runtime code (confidence thresholds, prompt
  templates, supported languages). Workspace + playbook:
  [notebooks/README.md](notebooks/README.md).

Notebook results feed back into runtime symbols by name — every results
file lists which file/line a finding updates, so validation work doesn't
become a dead-end.

## 10 · Code style

### TypeScript

- **Linter:** ESLint with `eslint-config-next` and `@typescript-eslint`.
- **Formatter:** Prettier (config in project root).
- **Check:** `npm run lint` and `npm run format:check`.
- **Fix:** `npm run format` to auto-format.

Key rules:

- Strict TypeScript (`strict: true` in `tsconfig.json`).
- No `any` types — use `unknown` plus type guards.
- Prefer `const` over `let`; never `var`.
- Named exports only (the only default exports are Next.js pages).
- Imports sorted: external packages first, then internal (`@/lib/...`).

### Swift

- **Linter:** SwiftLint (config in `.swiftlint.yml`).
- **Run:** `swiftlint` from the `ios/` directory.

Key rules:

- 4-space indentation.
- Max line length 120 characters.
- Use `guard` for early returns.
- Prefer `let` over `var`.
- Actors for all concurrency-sensitive types.
- Use `os.Logger` for logging — never `print`.

## 11 · Branches and PRs

### Branch protection on `main`

- **Required status checks:** `ci` and `e2e` workflows must pass.
- **Required reviewers:** at least 1 approving review.
- **No direct pushes:** all changes go through a PR.
- **Up-to-date branches:** PRs must rebase on latest `main` before merge.

### Branch naming

| Prefix | Use case | Example |
| --- | --- | --- |
| `feat/` | New feature | `feat/voice-agent` |
| `fix/` | Bug fix | `fix/sms-filter-crash` |
| `refactor/` | Code restructuring | `refactor/agent-protocol` |
| `docs/` | Documentation only | `docs/testing-guide` |
| `test/` | Test additions / changes | `test/url-agent-coverage` |
| `chore/` | Build, CI, dependencies | `chore/update-capacitor` |

### PR title

- Under 70 characters.
- Imperative mood: "Add voice agent" not "Added voice agent".
- Prefix with type: `feat: add voice agent`, `fix: resolve SMS filter timeout`.

### PR description

```markdown
## Summary
Brief description of changes.

## Test Plan
How to verify the changes work.

## Apple Compliance Notes
Any notes relevant to App Store review (or "N/A").
```

The **Apple Compliance Notes** section is required for any PR that touches
iOS extensions, entitlements / capabilities, privacy-related code (data
collection, tracking), or in-app purchases / subscriptions.

### Reviewer checklist

- [ ] Code compiles without warnings.
- [ ] Tests pass locally (`npm run test:unit`, `npm run test:e2e`).
- [ ] New code has tests.
- [ ] No PII in log statements (see [docs/logging.md](docs/logging.md)).
- [ ] Accessibility requirements met (see [docs/wcag-checklist.md](docs/wcag-checklist.md)).
- [ ] No hardcoded secrets or credentials.

## 12 · Commit message conventions

Format:

```text
<type>(<scope>): <subject>

<body>

<footer>
```

### Types

| Type | Description |
| --- | --- |
| `feat` | New feature |
| `fix` | Bug fix |
| `docs` | Documentation |
| `style` | Formatting (no logic change) |
| `refactor` | Code restructuring |
| `test` | Adding or modifying tests |
| `chore` | Build, CI, dependencies |
| `perf` | Performance improvement |

### Scopes

| Scope | Area |
| --- | --- |
| `ui` | Next.js / React components |
| `agents` | Swift agent actors |
| `mcp` | MCP servers |
| `extensions` | iOS extensions |
| `inference` | Model loading / inference |
| `guardian` | Guardian Mode |
| `ci` | GitHub Actions workflows |

### Examples

```text
feat(agents): add voice agent with transcription pipeline

Implements VoiceAgent actor that uses Whisper for transcription
before passing text to the inference engine.

Closes #42
```

```text
fix(extensions): resolve SMS filter memory limit violation

DistilBERT model was not being released after classification,
causing memory to exceed the 50MB ceiling.
```

GPG-signed commits are required on tags matching `v*` (release tags). For
GPG setup see [docs/release.md](docs/release.md).

## 13 · CI

GitHub Actions runs on every PR:

- `ci.yml` — typecheck, lint, format, unit tests, build.
- `e2e.yml` — Playwright on chromium + webkit.
- (Swift CI runs on a self-hosted Mac runner — see [docs/secrets.md](docs/secrets.md).)

### Run the full CI suite locally

```bash
# TypeScript
npm run typecheck
npm run lint
npm run format:check
npm run test:unit

# Build + E2E
npm run build
npm run test:e2e

# Swift (requires Xcode)
cd ios/App && swiftlint && cd ../..
xcodebuild test \
  -scheme GemmaKitTests \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

### Quick precommit subsets

```bash
# TypeScript changes only
npm run typecheck && npm run lint && npm run test:unit

# Swift changes only
xcodebuild test -scheme GemmaKitTests \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro'

# UI changes
npm run build && npm run test:e2e
```

## 14 · Performance targets

These are the engineering bar. Exceed them at your own risk; regress them
and the CI benchmarks will flag it:

| Metric | Target |
| --- | --- |
| E2B first token | ≤ 400 ms |
| E2B decode | 15-25 tok/s |
| E4B first token | ≤ 900 ms |
| E4B decode | 8-15 tok/s |
| DistilBERT inference | ≤ 100 ms |
| False positive rate | < 5% |
| E2B RAM | ≤ 1.8 GB |
| E4B RAM | ≤ 3.2 GB |

## 15 · Getting help

- Setup not working? [docs/getting-started.md](docs/getting-started.md).
- Wondering why a test is structured a certain way? [docs/testing.md](docs/testing.md).
- System design question? [docs/architecture.md](docs/architecture.md).
- Open a draft PR early — feedback before investing heavily is cheaper than
  feedback at the end.
