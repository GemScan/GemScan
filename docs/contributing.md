# Contributing

Guidelines for contributing to GemScan.

---

## Branch Protection Rules

The `main` branch is protected with the following rules:

- **Required status checks:** `ci` and `e2e` workflows must pass.
- **Required reviewers:** At least 1 approving review.
- **No direct pushes:** All changes must go through a pull request.
- **Up-to-date branches:** PRs must be rebased on latest `main` before merge.

---

## Branch Naming

Use the following prefixes:

| Prefix | Use case | Example |
|--------|----------|---------|
| `feat/` | New feature | `feat/voice-agent` |
| `fix/` | Bug fix | `fix/sms-filter-crash` |
| `refactor/` | Code restructuring | `refactor/agent-protocol` |
| `docs/` | Documentation only | `docs/testing-guide` |
| `test/` | Test additions/changes | `test/url-agent-coverage` |
| `chore/` | Build, CI, dependencies | `chore/update-capacitor` |

---

## PR Process

### Title

- Keep under 70 characters.
- Use imperative mood: "Add voice agent" not "Added voice agent".
- Prefix with type: `feat: Add voice agent`, `fix: Resolve SMS filter timeout`.

### Description

Every PR description must include:

```markdown
## Summary
Brief description of changes.

## Test Plan
How to verify the changes work.

## Apple Compliance Notes
Any notes relevant to App Store review (or "N/A").
```

The **Apple Compliance Notes** section is required for any PR that touches:
- iOS extensions
- Entitlements or capabilities
- Privacy-related code (data collection, tracking)
- In-app purchases or subscriptions

### Review Checklist

Reviewers should verify:

- [ ] Code compiles without warnings.
- [ ] Tests pass locally (`npm run test:unit`, `npm run test:e2e`).
- [ ] New code has tests.
- [ ] No PII in log statements (see `docs/logging.md`).
- [ ] Accessibility requirements met (see `docs/wcag-checklist.md`).
- [ ] No hardcoded secrets or credentials.

---

## Code Style

### TypeScript

- **Linter:** ESLint with `eslint-config-next` and `@typescript-eslint`.
- **Formatter:** Prettier (config in project root).
- **Check:** `npm run lint` and `npm run format:check`.
- **Fix:** `npm run format` to auto-format.

Key rules:
- Strict TypeScript (`strict: true` in tsconfig).
- No `any` types — use `unknown` and type guards.
- Prefer `const` over `let`; never use `var`.
- Named exports only (no default exports except pages).
- Imports sorted: external packages first, then internal (`@/lib/...`).

### Swift

- **Linter:** SwiftLint (config in `.swiftlint.yml`).
- **Run:** `swiftlint` from the `ios/` directory.

Key rules:
- 4-space indentation.
- Max line length: 120 characters.
- Use `guard` for early returns.
- Prefer `let` over `var`.
- Actors for all concurrency-sensitive types.
- Use `os.Logger` for logging (never `print`).

---

## Commit Message Conventions

Format:

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Types

| Type | Description |
|------|-------------|
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
|-------|------|
| `ui` | Next.js / React components |
| `agents` | Swift agent actors |
| `mcp` | MCP servers |
| `extensions` | iOS extensions |
| `inference` | Model loading / inference |
| `guardian` | Guardian Mode |
| `ci` | GitHub Actions workflows |

### Examples

```
feat(agents): add voice agent with transcription pipeline

Implements VoiceAgent actor that uses Whisper for transcription
before passing text to the inference engine.

Closes #42
```

```
fix(extensions): resolve SMS filter memory limit violation

DistilBERT model was not being released after classification,
causing memory to exceed the 50MB ceiling.
```

---

## Testing Requirements per PR

| Change type | Required tests |
|-------------|---------------|
| New TypeScript utility | Unit test with 80%+ coverage |
| New React component | Component test with key interactions |
| New Swift agent/MCP server | XCTest with mock infrastructure |
| UI behavior change | E2E Playwright test |
| iOS extension change | XCTest + manual verification notes |
| Bug fix | Regression test that fails without the fix |

---

## How to Run CI Locally

Before pushing, run the full CI check suite:

```bash
# TypeScript checks
npm run typecheck
npm run lint
npm run format:check
npm run test:unit

# Build and E2E
npm run build
npm run test:e2e

# Swift checks (requires Xcode)
cd ios/App && swiftlint && cd ../..
xcodebuild test \
  -scheme GemmaKitTests \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

### Quick Precommit Check

For fast iteration, run only the checks relevant to your changes:

```bash
# TypeScript changes only
npm run typecheck && npm run lint && npm run test:unit

# Swift changes only
xcodebuild test -scheme GemmaKitTests \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro'

# UI changes
npm run build && npm run test:e2e
```

---

## Getting Help

- Check `docs/getting-started.md` for environment setup.
- Check `docs/testing.md` for test infrastructure details.
- Check `docs/architecture.md` for system design questions.
- Open a draft PR early to get feedback before investing heavily.
