# Spec 01 — App Shell (Capacitor + Next.js)

---

## 1. Overview

The app shell is a **Next.js 14 (App Router) web application** wrapped in a **Capacitor 6** container that compiles to a native iOS binary. The shell owns:

- The complete UI layer (React components, routing, state management)
- The `GemmaPlugin` Capacitor bridge that exposes on-device inference to TypeScript
- A **web mock layer** so the full UI can be developed and tested in a browser without any native hardware

The shell never calls model inference directly — it calls through `GemmaPlugin`, which routes to either the native Swift implementation or the web mock.

---

## 2. Project Bootstrap

```bash
# From repo root
npm install
npx cap init GemScan com.gemscan.app --web-dir=out

# iOS
npx cap add ios
npx cap open ios              # Opens Xcode

# Dev server (web mock mode — no device needed)
npm run dev                   # Next.js dev server at http://localhost:3000

# Production build → sync to native
npm run build                 # next build && next export → out/
npx cap sync ios              # Copies out/ to ios/App/App/public
```

---

## 3. capacitor.config.ts

```typescript
import { CapacitorConfig } from '@capacitor/cli'

const config: CapacitorConfig = {
  appId: 'com.gemscan.app',
  appName: 'GemScan',
  webDir: 'out',
  server: {
    // In development, point to local Next.js server so hot-reload works on device
    // Comment out for production builds
    url: process.env.CAPACITOR_DEV_SERVER ?? undefined,
    cleartext: true,          // Allow localhost HTTP in dev only
  },
  plugins: {
    GemmaPlugin: {
      e2bModelId: 'GemScan/gemma-4-e2b-it-GemScan-q4km',
      e4bModelId: 'GemScan/gemma-4-e4b-it-GemScan-q4km',
      distilbertModelId: 'GemScan/sms-triage-distilbert',
      confidenceThreshold: 0.75,    // E2B → E4B escalation threshold (calibrated in §4.4)
      e4bResidentAboveGB: 8,        // Keep E4B resident if device RAM ≥ this value
    },
    SplashScreen: {
      launchShowDuration: 0,        // No splash delay once models are loaded
    },
  },
}
export default config
```

---

## 4. GemmaPlugin Interface

> **Type cross-reference:** The TypeScript `AgentTask` and `AgentResult` types below are the **bridge serialization contract** — they define the exact JSON shape passed through the Capacitor bridge. The canonical type definitions (including Swift structs and the full TypeScript unions) live in **Spec 00 §4**. Do not duplicate the full type bodies here.

### TypeScript Interface (`src/lib/gemma/types.ts`)

```typescript
export interface GemmaPlugin {
  /** Check if models are downloaded and ready. */
  isReady(): Promise<{ ready: boolean; missingModels: ModelId[] }>

  /** Download model weights. Progress events streamed via addListener. */
  downloadModels(options: { modelIds: ModelId[] }): Promise<void>

  /**
   * Submit an AgentTask and receive a streamed result.
   *
   * **Error handling:** Rejects with a `string` error message (the Swift
   * `error.localizedDescription`) in the following cases:
   * - `task` is missing required fields (bridge rejects with `"Missing task"`)
   * - `AgentTask` decoding fails (`GemScanError.grammarViolation`)
   * - Inference timeout (`GemScanError.inferenceTimeout`)
   * - OOM rejection (`GemScanError.oomRejected`)
   *
   * Callers must wrap in try/catch. On any rejection, display a conservative
   * `suspicious` verdict rather than an error UI.
   */
  analyse(task: AgentTask): Promise<AgentResult>

  /** Stream tokens as they are generated (fires repeatedly until done). */
  addListener(
    event: 'tokenStream',
    handler: (data: { taskId: string; token: string; done: boolean }) => void
  ): Promise<PluginListenerHandle>

  /** Model download progress (0.0–1.0 per model). */
  addListener(
    event: 'downloadProgress',
    handler: (data: { modelId: string; progress: number; bytesDownloaded: number; totalBytes: number }) => void
  ): Promise<PluginListenerHandle>

  /** Guardian mode state change (fired when another device triggers a change). */
  addListener(
    event: 'guardianModeChanged',
    handler: (data: { enabled: boolean; changedBy: 'self' | 'trustedContact' }) => void
  ): Promise<PluginListenerHandle>

  /** Get current memory and thermal status. */
  getDeviceStatus(): Promise<DeviceStatus>
}

export type ModelId = 'e2b' | 'e4b' | 'distilbert'

export interface DeviceStatus {
  availableMemoryBytes: number
  e2bLoaded: boolean
  e4bLoaded: boolean
  thermalState: 'nominal' | 'fair' | 'serious' | 'critical'
  batteryLevel: number          // 0.0–1.0
  screeningMode: 'passive' | 'active' | 'guardian'
}
```

### Native Plugin Registration (`ios/App/Plugins/GemmaPlugin.swift`)

```swift
import Capacitor

@objc(GemmaPlugin)
public class GemmaPlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "GemmaPlugin"
    public let jsName = "GemmaPlugin"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "isReady", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "downloadModels", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "analyse", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "getDeviceStatus", returnType: CAPPluginReturnPromise),
    ]

    private let orchestrator = OrchestratorAgent.shared  // GemmaKit actor

    @objc func analyse(_ call: CAPPluginCall) {
        guard let taskJSON = call.getObject("task") else {
            call.reject("Missing task")
            return
        }
        Task {
            do {
                let task = try AgentTask(from: taskJSON)
                let result = try await orchestrator.handle(task) { [weak self] token in
                    // Stream tokens back to JS
                    self?.notifyListeners("tokenStream", data: [
                        "taskId": task.id,
                        "token": token,
                        "done": false,
                    ])
                }
                call.resolve(result.toJSObject())
            } catch {
                GemScanLogger.plugin.error("analyse failed: \(error)")
                call.reject(error.localizedDescription)
            }
        }
    }
}
```

### Capacitor Bridge Serialization Contract

All values passed through the Capacitor bridge are plain JSON objects (serialized by `JSObject`). The following rules apply:

1. **`AgentTask` → JavaScript → Swift:** TypeScript serializes `AgentTask` to a plain JSON object before passing to `GemmaPlugin.analyse()`. All field names are camelCase. Dates are Unix timestamps (milliseconds, `Int64`). The Swift side decodes with `JSONDecoder()` configured with `.convertFromSnakeCase = false` (camelCase is already the wire format).

2. **`AgentResult` → Swift → JavaScript:** The Swift `AgentResult` is encoded with `JSONEncoder()` and returned as a `JSObject` to the TypeScript `Promise<AgentResult>`.

3. **`thermalState` mapping:** Swift `ProcessInfo.ThermalState` is mapped to the TypeScript string union as follows:

   | Swift enum case | TypeScript string |
   |---|---|
   | `.nominal` | `"nominal"` |
   | `.fair` | `"fair"` |
   | `.serious` | `"serious"` |
   | `.critical` | `"critical"` |

4. **`tokenStream` event — `done` field semantics:** The `done: true` token event is emitted **exactly once** at the end of generation (after all content tokens). Content tokens always have `done: false`. The `StreamingReasoningView` component relies on this: it sets `done` state only once and must not receive multiple `done: true` events.

5. **`AgentTask(from: taskJSON)` error conditions:** The Swift `AgentTask` initializer throws `GemScanError.grammarViolation(raw:)` if:
   - The `type` field contains a value not in `AgentTaskType`
   - The `payload.type` field is missing or unrecognised
   - The `priority` field is missing or not `"realtime"` / `"background"`
   - Any required `Int64` field (e.g., `createdAt`) is absent or not a number

---

## 5. Web Mock Layer (`src/lib/gemma/mock.ts`)

The mock must implement the full `GemmaPlugin` interface so every UI state is reachable in a browser.

```typescript
import type { GemmaPlugin, AgentTask, AgentResult, DeviceStatus } from './types'
import { goldenFixtures } from './__fixtures__/golden'
import { logger } from '../logger'

export const GemmaPluginMock: GemmaPlugin = {
  async isReady() {
    logger.info('[MOCK] isReady → ready')
    return { ready: true, missingModels: [] }
  },

  async downloadModels({ modelIds }) {
    logger.info('[MOCK] downloadModels', modelIds)
    // Simulate progress events
    for (const modelId of modelIds) {
      for (let p = 0; p <= 1; p += 0.1) {
        await sleep(50)
        mockListeners['downloadProgress']?.forEach(h =>
          h({ modelId, progress: p, bytesDownloaded: p * 1_500_000_000, totalBytes: 1_500_000_000 })
        )
      }
    }
  },

  async analyse(task: AgentTask): Promise<AgentResult> {
    logger.info('[MOCK] analyse', { taskId: task.id, type: task.type })
    await sleep(300 + Math.random() * 500)  // Simulate 300–800 ms latency

    // Return golden fixture if available, else generic suspicious verdict
    const fixture = goldenFixtures[task.id] ?? goldenFixtures['default']
    mockListeners['tokenStream']?.forEach(h =>
      h({ taskId: task.id, token: fixture.reasoning[0], done: true })
    )
    return fixture
  },

  async getDeviceStatus(): Promise<DeviceStatus> {
    return {
      availableMemoryBytes: 4_000_000_000,
      e2bLoaded: true,
      e4bLoaded: false,
      thermalState: 'nominal',
      batteryLevel: 0.85,
      screeningMode: 'active',
    }
  },

  async addListener(event, handler) {
    if (!mockListeners[event]) mockListeners[event] = []
    mockListeners[event].push(handler)
    return { remove: () => { mockListeners[event] = mockListeners[event].filter(h => h !== handler) } }
  },
}

const mockListeners: Record<string, Function[]> = {}
const sleep = (ms: number) => new Promise(r => setTimeout(r, ms))
```

### Golden Fixtures (`src/lib/gemma/__fixtures__/golden.ts`)

```typescript
import type { AgentResult } from '../types'

export const goldenFixtures: Record<string, AgentResult> = {
  'default': {
    taskId: 'mock-default',
    agentId: 'orchestrator',
    verdict: 'suspicious',
    confidence: 0.71,
    reasoning: [
      'The sender is not in your contacts.',
      'The message contains urgent language and an unusual link.',
      'Recommend: Do not click the link. Share with a trusted contact.',
    ],
    language: 'en',
    toolCallsLog: [],
    latencyMs: 420,
    modelTier: 'e2b',
    escalatedToE4B: false,
  },
  'safe-known-contact': {
    taskId: 'mock-safe',
    agentId: 'orchestrator',
    verdict: 'safe',
    confidence: 0.97,
    reasoning: ['Message is from a verified contact.', 'No suspicious links or patterns detected.'],
    language: 'en',
    toolCallsLog: [],
    latencyMs: 180,
    modelTier: 'e2b',
    escalatedToE4B: false,
  },
  'scam-voice-deepfake': {
    taskId: 'mock-deepfake',
    agentId: 'voice-agent',
    verdict: 'scam',
    confidence: 0.94,
    reasoning: [
      'Voice patterns are consistent with AI synthesis.',
      'AudioSeal watermark not detected — unverified voice clone.',
      'Urgent financial request detected: characteristic of grandparent scam.',
    ],
    language: 'en',
    toolCallsLog: [],
    latencyMs: 2100,
    modelTier: 'e4b',
    escalatedToE4B: true,
  },
  // SMS agent verdicts
  'scam-sms-bank': {
    taskId: 'mock-scam-sms',
    agentId: 'text-agent',
    verdict: 'scam',
    confidence: 0.93,
    reasoning: [
      'Message impersonates a bank with a fake alert.',
      'Link domain registered 3 days ago — high risk.',
      'Recommend: Do not click the link or call the number.',
    ],
    language: 'en',
    toolCallsLog: [{ serverName: 'url_reputation', toolName: 'check_url', inputSummary: '{url}', durationMs: 12, success: true }],
    latencyMs: 510,
    modelTier: 'e2b',
    escalatedToE4B: false,
  },
  'suspicious-sms-promo': {
    taskId: 'mock-suspicious-sms',
    agentId: 'text-agent',
    verdict: 'suspicious',
    confidence: 0.66,
    reasoning: [
      'Promotional offer with an unverified link.',
      'Sender not in contacts.',
      'Recommend: Verify the offer before clicking.',
    ],
    language: 'en',
    toolCallsLog: [],
    latencyMs: 390,
    modelTier: 'e2b',
    escalatedToE4B: false,
  },
  // URL agent verdicts
  'scam-url-phishing': {
    taskId: 'mock-scam-url',
    agentId: 'url-agent',
    verdict: 'scam',
    confidence: 0.88,
    reasoning: [
      'Domain is on the known phishing blocklist.',
      'TLD and path structure match credential-harvesting patterns.',
      'Recommend: Do not visit this URL.',
    ],
    language: 'en',
    toolCallsLog: [{ serverName: 'url_reputation', toolName: 'check_url', inputSummary: '{url}', durationMs: 8, success: true }],
    latencyMs: 290,
    modelTier: 'e2b',
    escalatedToE4B: false,
  },
  'safe-url-known': {
    taskId: 'mock-safe-url',
    agentId: 'url-agent',
    verdict: 'safe',
    confidence: 0.95,
    reasoning: ['Domain is a well-known legitimate service.', 'No blocklist match.'],
    language: 'en',
    toolCallsLog: [],
    latencyMs: 155,
    modelTier: 'e2b',
    escalatedToE4B: false,
  },
  // Screenshot (image) agent
  'scam-screenshot-fake-login': {
    taskId: 'mock-scam-screenshot',
    agentId: 'image-agent',
    verdict: 'scam',
    confidence: 0.91,
    reasoning: [
      'Screenshot shows a fake bank login page with mismatched branding.',
      'QR code detected — leads to an unverified domain.',
      'Recommend: Do not enter any credentials.',
    ],
    language: 'en',
    toolCallsLog: [{ serverName: 'reverse_image', toolName: 'extract_text_urls', inputSummary: '{base64}', durationMs: 45, success: true }],
    latencyMs: 1800,
    modelTier: 'e4b',
    escalatedToE4B: true,
  },
  'safe-screenshot-receipt': {
    taskId: 'mock-safe-screenshot',
    agentId: 'image-agent',
    verdict: 'safe',
    confidence: 0.89,
    reasoning: ['Screenshot shows a standard payment receipt.', 'No suspicious links or QR codes.'],
    language: 'en',
    toolCallsLog: [],
    latencyMs: 950,
    modelTier: 'e4b',
    escalatedToE4B: false,
  },
  // Email classification
  'scam-email-lottery': {
    taskId: 'mock-scam-email',
    agentId: 'text-agent',
    verdict: 'scam',
    confidence: 0.96,
    reasoning: [
      'Classic lottery scam: unsolicited prize with fee-advance request.',
      'Sender domain created recently; not matching the claimed organisation.',
      'Recommend: Delete this email and do not respond.',
    ],
    language: 'en',
    toolCallsLog: [],
    latencyMs: 480,
    modelTier: 'e2b',
    escalatedToE4B: false,
  },
  'safe-email-receipt': {
    taskId: 'mock-safe-email',
    agentId: 'text-agent',
    verdict: 'safe',
    confidence: 0.98,
    reasoning: ['Order confirmation from a known retailer.', 'No suspicious links detected.'],
    language: 'en',
    toolCallsLog: [],
    latencyMs: 160,
    modelTier: 'distilbert',
    escalatedToE4B: false,
  },
}
```

---

## 6. Key Dependencies (`package.json`)

All versions are pinned exactly (no `^` ranges). Renovate Bot handles bump PRs.

```json
{
  "dependencies": {
    "next": "14.2.5",
    "@capacitor/core": "6.1.2",
    "@capacitor/ios": "6.1.2",
    "@capacitor/cli": "6.1.2",
    "@capacitor/preferences": "6.0.2",
    "@capacitor-community/contacts": "6.0.1",
    "@tanstack/react-query": "5.51.1",
    "zustand": "4.5.4",
    "react": "18.3.1",
    "react-dom": "18.3.1"
  },
  "devDependencies": {
    "typescript": "5.5.4",
    "vitest": "2.0.5",
    "@vitejs/plugin-react": "4.3.1",
    "@testing-library/react": "16.0.0",
    "@testing-library/jest-dom": "6.4.6",
    "@playwright/test": "1.46.1",
    "vite-tsconfig-paths": "5.0.1"
  }
}
```

> `@capacitor-community/contacts` is used by the `ContactPicker` component (Spec 06 §3.4). It wraps `CNContactStore` on iOS and must be installed before running `npx cap sync ios`.

---

## 7. Next.js Configuration (`next.config.ts`)

```typescript
import type { NextConfig } from 'next'

const nextConfig: NextConfig = {
  output: 'export',             // Static export for Capacitor
  trailingSlash: true,          // Required for Capacitor file:// routing
  images: { unoptimized: true }, // Required for static export
  experimental: {
    typedRoutes: true,
  },
  // Environment variable exposure (non-secret only)
  env: {
    NEXT_PUBLIC_APP_VERSION: process.env.npm_package_version ?? '0.0.0',
    NEXT_PUBLIC_IS_MOCK: process.env.NEXT_PUBLIC_IS_MOCK ?? 'false',
  },
}
export default nextConfig
```

### Environment Variables

| Variable | Purpose | Required in prod |
|---|---|---|
| `NEXT_PUBLIC_IS_MOCK` | Force web-mock mode (for Storybook, Playwright) | No |
| `NEXT_PUBLIC_APP_VERSION` | Displayed in Settings screen | No |
| `CAPACITOR_DEV_SERVER` | Live-reload server URL for device testing | Dev only |

---

## 7. App Router Structure (`src/app/`)

```
src/app/
├── layout.tsx              # Root layout: providers (query client, theme, logger)
├── page.tsx                # Home screen: "Check this for me" button + recent alerts
├── analyse/
│   └── page.tsx            # Analysis screen: shows streaming AgentResult
├── guardian/
│   ├── setup/page.tsx      # Guardian mode self-enrolment flow
│   └── invite/page.tsx     # Caregiver-assisted invitation acceptance flow
├── settings/
│   └── page.tsx            # Settings: language, trusted contact, mode toggle
├── onboarding/
│   └── page.tsx            # First-launch: model download + consent
└── error.tsx               # Global error boundary (shows conservative "suspicious" verdict)
```

---

## 8. State Management

Use **React Query** (`@tanstack/react-query`) for server-state (AgentResult fetches) and **Zustand** for client-state (screening mode, Guardian mode status, trusted contact).

```typescript
// src/lib/store.ts
import { create } from 'zustand'
import { persist } from 'zustand/middleware'

interface GemScanStore {
  screeningMode: 'passive' | 'active' | 'guardian'
  guardianModeEnabled: boolean
  trustedContactId: string | null    // CNContact identifier from CNContact.identifier (iOS persistent UUID)
  preferredLanguage: string      // BCP-47 tag, e.g. 'en', 'hi', 'ja'
  setScreeningMode: (mode: GemScanStore['screeningMode']) => void
  setGuardianMode: (enabled: boolean) => void
  setTrustedContact: (id: string | null) => void
}

export const useGemScanStore = create<GemScanStore>()(
  persist(
    (set) => ({
      screeningMode: 'active',
      guardianModeEnabled: false,
      trustedContactId: null,
      preferredLanguage: navigator.language.split('-')[0] ?? 'en',
      setScreeningMode: (mode) => set({ screeningMode: mode }),
      setGuardianMode: (enabled) => set({ guardianModeEnabled: enabled }),
      setTrustedContact: (id) => set({ trustedContactId: id }),
    }),
    {
      name: 'gemscan-store',
      version: 1,
      // Schema migration: increment version and provide migrate() when adding/renaming fields.
      // Old persisted state that doesn't match the new schema is merged via migrate().
      migrate: (persistedState: unknown, fromVersion: number) => {
        // v0 → v1: no migration needed (initial schema)
        return persistedState as GemScanStore
      },
    }
  )
)
```

---

## 9. Web App Mode Testing Checklist

Run before every PR merge to `main`:

- [ ] `npm run dev` — app loads in browser, no console errors
- [ ] Mock `analyse()` returns a result for a text input
- [ ] Token streaming renders progressively in the UI
- [ ] `downloadModels()` mock fires progress events and completes
- [ ] Guardian mode setup flow completes without native API calls
- [ ] VoiceOver simulation: all interactive elements have accessible labels
- [ ] `npm run build` — static export succeeds with zero TypeScript errors
- [ ] `npx cap sync` — sync succeeds without warnings
