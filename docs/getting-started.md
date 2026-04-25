# Getting Started

Developer environment setup for GemScan.

---

## Prerequisites

| Tool | Version | Install |
|------|---------|---------|
| Node.js | 20 LTS | `brew install node@20` or [nvm](https://github.com/nvm-sh/nvm) |
| Xcode | 15.3+ | Mac App Store |
| Swift | 5.9 | Ships with Xcode 15.3 |
| Python | 3.11+ | `brew install python@3.11` (scripts and ML tooling) |
| CocoaPods | latest | `gem install cocoapods` |
| Playwright browsers | — | `npx playwright install` |

Verify:

```bash
node -v   # v20.x.x
xcodebuild -version  # Xcode 15.3+
swift --version  # swift-driver version 5.9+
python3 --version  # 3.11+
```

---

## Clone and Install

```bash
git clone git@github.com:<org>/GemScan.git
cd GemScan
npm install
```

### iOS Dependencies

```bash
npx cap sync ios
cd ios/App && pod install && cd ../..
```

---

## Environment Variables

Create a `.env.local` in the project root (never committed):

```env
# Enable web mock mode — stubs all native Capacitor plugins
NEXT_PUBLIC_IS_MOCK=true

# Capacitor dev server URL (set automatically by `npm run dev`)
CAPACITOR_DEV_SERVER=http://localhost:3000
```

### Web Mock Mode vs Native Mode

| Mode | When to use | How to activate |
|------|-------------|-----------------|
| **Web mock** | UI development without Xcode | `NEXT_PUBLIC_IS_MOCK=true npm run dev` |
| **Native** | Full on-device testing | Build via Xcode with mock flag unset |

In mock mode, every Capacitor plugin call returns deterministic stub data defined in `src/lib/mocks/`. This lets frontend developers iterate without a device.

---

## Run the Dev Server

```bash
npm run dev
```

Open http://localhost:3000 in your browser. Hot-reload is enabled.

### Open in Xcode (Native Mode)

```bash
npx cap open ios
```

Select a simulator or connected device and press **Cmd+R** to build and run.

---

## Verify Your Setup

Run these commands in order — all must pass before you submit a PR:

```bash
# 1. Type checking
npm run typecheck

# 2. Lint
npm run lint

# 3. Unit and component tests
npm run test:unit

# 4. Build the production bundle
npm run build

# 5. E2E tests (requires build output)
npm run test:e2e
```

---

## Troubleshooting

### `Module not found: @capacitor/core`

```bash
rm -rf node_modules package-lock.json
npm install
npx cap sync ios
```

### Xcode build fails with signing errors

- Open Xcode > **Signing & Capabilities** and select your development team.
- Ensure provisioning profiles are installed (see `docs/secrets.md`).

### `pod install` fails

```bash
cd ios/App
pod repo update
pod install --repo-update
```

### Playwright tests time out

```bash
npx playwright install --with-deps chromium webkit
```

### Port 3000 already in use

```bash
lsof -ti:3000 | xargs kill -9
npm run dev
```

### Swift package resolution fails in Xcode

- **File > Packages > Reset Package Caches** in Xcode.
- Ensure you are on a network that does not block GitHub (some VPNs interfere).

---

## Next Steps

- Read `docs/architecture.md` for system overview.
- Read `docs/testing.md` before writing tests.
- Read `CONTRIBUTING.md` (repo root) before opening a PR — it's the single
  source of truth for setup, code style, branch / PR / commit rules, and CI.
