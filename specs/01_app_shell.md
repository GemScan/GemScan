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

### TypeScript Interface (`src/lib/gemma/types.ts`)

```typescript
export interface GemmaPlugin {
  /** Check if models are downloaded and ready. */
  isReady(): Promise<{ ready: boolean; missingModels: ModelId[] }>

  /** Download model weights. Progress events streamed via addListener. */
  downloadModels(options: { modelIds: ModelId[] }): Promise<void>

  /** Submit an AgentTask and receive a streamed result. */
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
}
```

---

## 6. Next.js Configuration (`next.config.ts`)

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
  trustedContactId: string | null
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
    { name: 'gemscan-store' }
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
