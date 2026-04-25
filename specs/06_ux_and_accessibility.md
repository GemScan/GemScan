# Spec 06 — UX and Accessibility

---

## 1. Design Principles

1. **Calm technology** — GemScan surfaces warnings without panic. No red sirens, no alarm tones. Verdicts are phrased as recommendations, not commands.
2. **Voice-first** — every interaction must be completable without reading any text. VoiceOver is first-class.
3. **One-hand operation** — all primary actions reachable within the bottom 40% of the screen on a 6.1-inch display.
4. **Sixth-grade reading level** — reasoning text (Flesch-Kincaid ≤ 70). Never use "malicious", "phishing", "social engineering" in user-facing copy.
5. **Internationalised from day one** — UI strings in `en`, `hi`, `ja`, `es`, `zh-Hans`. Layout adapts to RTL (`ar`, `he`) without code changes.

---

## 2. Screen Inventory

| Route | Purpose | Primary action |
|---|---|---|
| `/` | Home — recent alerts + check button | "Check this for me" |
| `/analyse` | Analysis result — streaming verdict display | "Share with contact" / "I'll be careful" |
| `/onboarding` | First launch — model download + consent | "Download and start" |
| `/guardian/setup` | Self-enrolment into Guardian mode | "Turn on Guardian mode" |
| `/guardian/invite` | Caregiver-assisted invitation acceptance | "Accept invitation" |
| `/settings` | Language, trusted contact, mode toggle | — |

---

## 3. Component Specifications

### 3.1 ScamWarningCard

The primary result display. Appears on `/analyse` after inference completes.

```tsx
// src/components/ScamWarningCard.tsx
'use client'

import { useEffect, useRef } from 'react'
import type { AgentResult } from '@/lib/gemma/types'

interface Props {
  result: AgentResult
  onShare: () => void
  onDismiss: () => void
}

export function ScamWarningCard({ result, onShare, onDismiss }: Props) {
  const headingRef = useRef<HTMLHeadingElement>(null)

  // Move focus to verdict heading as soon as card mounts (accessibility)
  useEffect(() => {
    headingRef.current?.focus()
  }, [])

  const { variant, label, icon } = verdictDisplay(result.verdict)

  return (
    <article
      role="main"
      aria-label={`Scam check result: ${label}`}
      className={`rounded-2xl p-6 ${variant.background} shadow-lg`}
    >
      {/* Verdict heading — receives focus on mount */}
      <h1
        ref={headingRef}
        tabIndex={-1}
        className={`text-2xl font-bold mb-2 ${variant.text}`}
        aria-live="assertive"
      >
        {icon} {label}
      </h1>

      {/* Confidence meter — decorative; screen reader gets plain text equivalent */}
      <div
        role="meter"
        aria-label={`Confidence: ${Math.round(result.confidence * 100)}%`}
        aria-valuenow={result.confidence}
        aria-valuemin={0}
        aria-valuemax={1}
        className="w-full h-2 bg-gray-200 rounded-full my-3"
      >
        <div
          className={`h-2 rounded-full ${variant.bar}`}
          style={{ width: `${result.confidence * 100}%` }}
        />
      </div>

      {/* Reasoning bullets */}
      <ul className="space-y-2 mb-4" aria-label="Why GemScan flagged this">
        {result.reasoning.map((point, i) => (
          <li key={i} className="flex gap-2 text-base leading-relaxed">
            <span aria-hidden="true">•</span>
            <span>{point}</span>
          </li>
        ))}
      </ul>

      {/* Action buttons */}
      <div className="flex flex-col gap-3 mt-4">
        {result.verdict !== 'safe' && (
          <button
            onClick={onShare}
            className="w-full py-3 rounded-xl bg-blue-600 text-white font-semibold text-lg"
            aria-label="Share this alert with your trusted contact"
          >
            Share with trusted contact
          </button>
        )}
        <button
          onClick={onDismiss}
          className="w-full py-3 rounded-xl border border-gray-300 text-gray-700 font-semibold text-lg"
          aria-label={result.verdict === 'safe' ? 'Great, go back to home' : 'I understand, I\'ll be careful'}
        >
          {result.verdict === 'safe' ? 'Great!' : "I'll be careful"}
        </button>
      </div>

      {/* Model tier badge — informational, not critical */}
      <p className="text-xs text-gray-400 text-center mt-3" aria-hidden="true">
        Analysed on-device · {result.modelTier.toUpperCase()} · {result.latencyMs}ms
      </p>
    </article>
  )
}

function verdictDisplay(verdict: AgentResult['verdict']) {
  switch (verdict) {
    case 'safe':
      return {
        variant: { background: 'bg-green-50', text: 'text-green-800', bar: 'bg-green-500' },
        label: 'Looks safe',
        icon: '✓',
      }
    case 'suspicious':
      return {
        variant: { background: 'bg-amber-50', text: 'text-amber-800', bar: 'bg-amber-500' },
        label: 'Be careful',
        icon: '⚠',
      }
    case 'scam':
      return {
        variant: { background: 'bg-red-50', text: 'text-red-800', bar: 'bg-red-600' },
        label: 'This looks like a scam',
        icon: '✕',
      }
  }
}
```

### 3.2 StreamingReasoningView

Renders reasoning tokens as they stream from the model. Each token is appended with an `aria-live="polite"` region so screen readers announce updates without interrupting.

```tsx
// src/components/StreamingReasoningView.tsx
'use client'

import { useState, useEffect } from 'react'
import { GemmaPlugin } from '@/lib/gemma'

interface Props {
  taskId: string
}

export function StreamingReasoningView({ taskId }: Props) {
  const [tokens, setTokens] = useState<string[]>([])
  const [done, setDone] = useState(false)

  useEffect(() => {
    let handle: { remove: () => void } | null = null

    GemmaPlugin.addListener('tokenStream', (data) => {
      if (data.taskId !== taskId) return
      setTokens(prev => [...prev, data.token])
      if (data.done) setDone(true)
    }).then(h => { handle = h })

    return () => { handle?.remove() }
  }, [taskId])

  const displayText = tokens.join('')

  return (
    <div className="relative min-h-[80px]">
      {/* Visible text */}
      <p className="text-base leading-relaxed text-gray-700 whitespace-pre-wrap">
        {displayText}
        {!done && <span className="inline-block w-2 h-4 bg-gray-400 ml-1 animate-pulse" aria-hidden="true" />}
      </p>
      {/* Screen reader live region — polite so it doesn't interrupt other announcements */}
      <div
        aria-live="polite"
        aria-atomic="false"
        className="sr-only"
      >
        {done ? displayText : ''}
      </div>
    </div>
  )
}
```

### 3.3 ModelDownloadProgress

Shown during first-launch onboarding while model weights download.

```tsx
// src/components/ModelDownloadProgress.tsx
'use client'

import { useState, useEffect } from 'react'
import { GemmaPlugin } from '@/lib/gemma'
import type { ModelId } from '@/lib/gemma/types'

interface ModelProgress {
  modelId: ModelId
  progress: number
  bytesDownloaded: number
  totalBytes: number
}

export function ModelDownloadProgress() {
  const [progress, setProgress] = useState<Record<ModelId, ModelProgress>>({})

  useEffect(() => {
    let handle: { remove: () => void } | null = null

    GemmaPlugin.addListener('downloadProgress', (data) => {
      setProgress(prev => ({
        ...prev,
        [data.modelId as ModelId]: data,
      }))
    }).then(h => { handle = h })

    return () => { handle?.remove() }
  }, [])

  const models: { id: ModelId; label: string; sizeMB: number }[] = [
    { id: 'distilbert', label: 'Fast Triage (5 MB)', sizeMB: 5 },
    { id: 'e2b', label: 'On-Device AI — Standard (1.8 GB)', sizeMB: 1800 },
    { id: 'e4b', label: 'On-Device AI — Deep Analysis (3.2 GB)', sizeMB: 3200 },
  ]

  return (
    <section aria-label="Model download progress">
      {models.map(model => {
        const p = progress[model.id]
        const pct = p ? Math.round(p.progress * 100) : 0
        const downloadedMB = p ? Math.round(p.bytesDownloaded / 1_000_000) : 0

        return (
          <div key={model.id} className="mb-4">
            <div className="flex justify-between mb-1">
              <span className="text-sm font-medium text-gray-700">{model.label}</span>
              <span className="text-sm text-gray-500" aria-hidden="true">{pct}%</span>
            </div>
            <div
              role="progressbar"
              aria-label={`${model.label} download progress`}
              aria-valuenow={pct}
              aria-valuemin={0}
              aria-valuemax={100}
              aria-valuetext={`${downloadedMB} MB of ${model.sizeMB} MB downloaded`}
              className="w-full h-3 bg-gray-200 rounded-full"
            >
              <div
                className="h-3 rounded-full bg-blue-500 transition-all duration-300"
                style={{ width: `${pct}%` }}
              />
            </div>
          </div>
        )
      })}
    </section>
  )
}
```

---

## 4. Guardian Mode UX

### 4.1 Self-Enrolment Flow (`/guardian/setup`)

```
┌─────────────────────────────────────┐
│  Guardian Mode                      │
│                                     │
│  "Guardian mode sends an alert to   │
│   a trusted person whenever GemScan │
│   detects a high-risk message."     │
│                                     │
│  Trusted Contact: [Pick from        │
│                    contacts]        │
│                                     │
│  Alert on:                          │
│  ◉ High-risk only (scam)            │
│  ○ All warnings                     │
│                                     │
│  [Turn on Guardian Mode]            │
│  [Not now]                          │
└─────────────────────────────────────┘
```

```tsx
// src/app/guardian/setup/page.tsx
'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { useGemScanStore } from '@/lib/store'

export default function GuardianSetupPage() {
  const router = useRouter()
  const { setGuardianMode, setTrustedContact } = useGemScanStore()
  const [contactId, setContactId] = useState<string | null>(null)
  const [alertLevel, setAlertLevel] = useState<'scam_only' | 'all_warnings'>('scam_only')

  async function handleEnable() {
    if (!contactId) return
    setTrustedContact(contactId)
    setGuardianMode(true)
    router.push('/')
  }

  return (
    <main className="flex flex-col gap-6 p-6 max-w-md mx-auto">
      <h1 className="text-2xl font-bold">Guardian Mode</h1>

      <p className="text-base text-gray-700 leading-relaxed">
        Guardian mode sends an alert to a trusted person whenever GemScan detects a high-risk message.
        Your messages are never shared — only the alert.
      </p>

      <section aria-labelledby="contact-label">
        <h2 id="contact-label" className="font-semibold mb-2">Trusted Contact</h2>
        <ContactPicker onSelect={setContactId} selectedId={contactId} />
      </section>

      <fieldset>
        <legend className="font-semibold mb-2">Send alerts for</legend>
        {(['scam_only', 'all_warnings'] as const).map(level => (
          <label key={level} className="flex items-center gap-3 py-2 cursor-pointer">
            <input
              type="radio"
              name="alertLevel"
              value={level}
              checked={alertLevel === level}
              onChange={() => setAlertLevel(level)}
              className="w-5 h-5"
            />
            <span>{level === 'scam_only' ? 'High-risk only (scams)' : 'All warnings'}</span>
          </label>
        ))}
      </fieldset>

      <button
        onClick={handleEnable}
        disabled={!contactId}
        aria-disabled={!contactId}
        className="w-full py-4 rounded-2xl bg-blue-600 text-white font-bold text-lg disabled:opacity-40"
      >
        Turn on Guardian Mode
      </button>

      <button
        onClick={() => router.back()}
        className="w-full py-3 text-gray-600 font-medium"
        aria-label="Skip Guardian Mode setup"
      >
        Not now
      </button>
    </main>
  )
}
```

### 4.2 Caregiver-Assisted Invitation Flow (`/guardian/invite`)

The caregiver scans a QR code generated by the elder's device. The QR code encodes an invitation token. No personal data in the QR code — it's a one-time UUID that resolves via the App Group shared container on the same device (for local setup) or via a push notification channel (for remote setup).

```tsx
// src/app/guardian/invite/page.tsx
'use client'

import { useSearchParams, useRouter } from 'next/navigation'
import { useEffect, useState } from 'react'
import { useGemScanStore } from '@/lib/store'

export default function GuardianInvitePage() {
  const params = useSearchParams()
  const router = useRouter()
  const { setGuardianMode, setTrustedContact } = useGemScanStore()
  const [status, setStatus] = useState<'pending' | 'accepted' | 'error'>('pending')

  const token = params.get('token')

  useEffect(() => {
    if (!token) { setStatus('error'); return }
    // Validate token (local: check App Group defaults; remote: verify push token)
    validateInvitationToken(token)
      .then(contactId => {
        setTrustedContact(contactId)
        setGuardianMode(true)
        setStatus('accepted')
      })
      .catch(() => setStatus('error'))
  }, [token])

  if (status === 'accepted') {
    return (
      <main className="flex flex-col items-center gap-6 p-6 text-center">
        <span className="text-6xl" aria-hidden="true">✓</span>
        <h1 className="text-2xl font-bold">Guardian mode is on</h1>
        <p className="text-gray-700">You will receive alerts from GemScan when needed.</p>
        <button onClick={() => router.push('/')} className="w-full py-4 bg-blue-600 text-white rounded-2xl font-bold text-lg">
          Go to GemScan
        </button>
      </main>
    )
  }

  return (
    <main className="flex flex-col items-center gap-6 p-6 text-center">
      {status === 'pending' && (
        <>
          <div className="w-12 h-12 border-4 border-blue-500 border-t-transparent rounded-full animate-spin" aria-hidden="true" />
          <p className="text-gray-600">Setting up Guardian mode…</p>
        </>
      )}
      {status === 'error' && (
        <>
          <span className="text-6xl" aria-hidden="true">✕</span>
          <h1 className="text-2xl font-bold">Invitation not found</h1>
          <p className="text-gray-600">Ask the person who invited you to generate a new QR code.</p>
          <button onClick={() => router.push('/')} className="w-full py-4 bg-gray-100 text-gray-700 rounded-2xl font-bold text-lg">
            Go back
          </button>
        </>
      )}
    </main>
  )
}

async function validateInvitationToken(token: string): Promise<string> {
  // Web mock: return a placeholder contact ID
  await new Promise(r => setTimeout(r, 800))
  if (token.length < 10) throw new Error('Invalid token')
  return `contact-${token.slice(0, 8)}`
}
```

### 4.3 Guardian Mode Status Bar (Persistent)

Shown on every screen when Guardian mode is active. Provides a one-tap pause.

```tsx
// src/components/GuardianStatusBar.tsx
'use client'

import { useGemScanStore } from '@/lib/store'

export function GuardianStatusBar() {
  const { guardianModeEnabled, setGuardianMode } = useGemScanStore()

  if (!guardianModeEnabled) return null

  return (
    <aside
      role="status"
      aria-label="Guardian mode is active"
      className="w-full bg-blue-600 text-white text-sm flex items-center justify-between px-4 py-2"
    >
      <span className="font-medium">Guardian mode on</span>
      <button
        onClick={() => setGuardianMode(false)}
        aria-label="Pause Guardian mode"
        className="underline text-sm font-medium"
      >
        Pause
      </button>
    </aside>
  )
}
```

---

## 5. Accessibility Requirements

### 5.1 VoiceOver

All interactive elements must have:
- **`aria-label`** if the visible label is not sufficiently descriptive
- **`role`** if the element is not a native semantic HTML element
- **Focus management**: when a screen transition occurs, focus moves to the page `<h1>` or the primary actionable element
- **`aria-live` regions** for dynamically updated content (streaming tokens, download progress, verdict)

### 5.2 Dynamic Type / Font Scaling

All text uses relative units (`rem`, `em`). No fixed `px` font sizes. Test at iOS Dynamic Type sizes: Default, Large, Accessibility Large, Accessibility X-Large.

```css
/* src/styles/globals.css */
:root {
  --text-base: 1rem;      /* 16px at default */
  --text-lg: 1.125rem;
  --text-xl: 1.25rem;
  --text-2xl: 1.5rem;
}

/* Minimum tap target: 44×44 points (Apple HIG) */
button, [role="button"] {
  min-height: 44px;
  min-width: 44px;
}
```

### 5.3 Colour Contrast

| Element | Foreground | Background | Contrast ratio | WCAG level |
|---|---|---|---|---|
| Verdict heading (safe) | `#166534` | `#f0fdf4` | 7.1:1 | AAA |
| Verdict heading (suspicious) | `#92400e` | `#fffbeb` | 7.3:1 | AAA |
| Verdict heading (scam) | `#991b1b` | `#fef2f2` | 7.5:1 | AAA |
| Body text | `#374151` | `#ffffff` | 8.6:1 | AAA |
| Button text | `#ffffff` | `#2563eb` | 4.7:1 | AA |
| Muted caption | `#6b7280` | `#ffffff` | 4.6:1 | AA |

### 5.4 Reduced Motion

```css
@media (prefers-reduced-motion: reduce) {
  .animate-pulse,
  .animate-spin,
  .transition-all {
    animation: none !important;
    transition: none !important;
  }
}
```

### 5.5 WCAG 2.1 Checklist (Pre-Release)

- [ ] 1.1.1 — All images have `alt` text or `aria-hidden="true"` if decorative
- [ ] 1.3.1 — Information is not conveyed by colour alone (verdict uses icon + text + colour)
- [ ] 1.4.1 — No colour-only distinction (badge icons provide non-colour indicator)
- [ ] 1.4.3 — Text contrast ≥ 4.5:1 AA (all passes documented above)
- [ ] 2.1.1 — All functionality reachable via keyboard
- [ ] 2.4.3 — Focus order is logical (top → bottom, consistent with reading order)
- [ ] 2.4.7 — Focus visible on all interactive elements
- [ ] 3.1.1 — Language set on `<html lang="...">` per user preference
- [ ] 4.1.3 — Status messages announced via `aria-live` without focus change

---

## 6. Localisation

### String Management

All user-facing strings live in `src/lib/i18n/strings.ts`. No string literals in component files.

```typescript
// src/lib/i18n/strings.ts
export type Locale = 'en' | 'hi' | 'ja' | 'es' | 'zh-Hans'

export const strings: Record<Locale, Record<string, string>> = {
  en: {
    'verdict.safe': 'Looks safe',
    'verdict.suspicious': 'Be careful',
    'verdict.scam': 'This looks like a scam',
    'action.share': 'Share with trusted contact',
    'action.dismiss.safe': 'Great!',
    'action.dismiss.unsafe': "I'll be careful",
    'guardian.on': 'Guardian mode on',
    'guardian.pause': 'Pause',
    'onboarding.download': 'Download and start',
    'onboarding.title': 'Protecting you from scams',
    'onboarding.subtitle': 'GemScan runs entirely on your device. Nothing is ever sent to the cloud.',
  },
  hi: {
    'verdict.safe': 'सुरक्षित लगता है',
    'verdict.suspicious': 'सावधान रहें',
    'verdict.scam': 'यह एक धोखे जैसा लगता है',
    'action.share': 'विश्वसनीय संपर्क के साथ साझा करें',
    'action.dismiss.safe': 'बढ़िया!',
    'action.dismiss.unsafe': 'मैं सावधान रहूँगा',
    'guardian.on': 'गार्जियन मोड चालू है',
    'guardian.pause': 'रोकें',
    'onboarding.download': 'डाउनलोड करें और शुरू करें',
    'onboarding.title': 'धोखे से आपकी सुरक्षा',
    'onboarding.subtitle': 'GemScan पूरी तरह आपके डिवाइस पर चलता है। कुछ भी क्लाउड पर नहीं भेजा जाता।',
  },
  ja: {
    'verdict.safe': '安全そうです',
    'verdict.suspicious': '注意してください',
    'verdict.scam': '詐欺の可能性があります',
    'action.share': '信頼できる連絡先に共有',
    'action.dismiss.safe': 'よかった！',
    'action.dismiss.unsafe': '気をつけます',
    'guardian.on': 'ガーディアンモードがオン',
    'guardian.pause': '一時停止',
    'onboarding.download': 'ダウンロードして開始',
    'onboarding.title': '詐欺からあなたを守る',
    'onboarding.subtitle': 'GemScanはデバイス上でのみ動作します。クラウドには何も送信されません。',
  },
  es: {
    'verdict.safe': 'Parece seguro',
    'verdict.suspicious': 'Ten cuidado',
    'verdict.scam': 'Esto parece una estafa',
    'action.share': 'Compartir con contacto de confianza',
    'action.dismiss.safe': '¡Genial!',
    'action.dismiss.unsafe': 'Tendré cuidado',
    'guardian.on': 'Modo guardián activado',
    'guardian.pause': 'Pausar',
    'onboarding.download': 'Descargar y comenzar',
    'onboarding.title': 'Protegiéndote de las estafas',
    'onboarding.subtitle': 'GemScan funciona completamente en tu dispositivo. Nada se envía a la nube.',
  },
  'zh-Hans': {
    'verdict.safe': '看起来安全',
    'verdict.suspicious': '请小心',
    'verdict.scam': '这看起来像诈骗',
    'action.share': '分享给信任的联系人',
    'action.dismiss.safe': '太好了！',
    'action.dismiss.unsafe': '我会小心的',
    'guardian.on': '守护者模式已开启',
    'guardian.pause': '暂停',
    'onboarding.download': '下载并开始',
    'onboarding.title': '保护您免受诈骗',
    'onboarding.subtitle': 'GemScan完全在您的设备上运行，从不向云端发送任何内容。',
  },
}

export function t(key: string, locale: Locale): string {
  return strings[locale]?.[key] ?? strings['en'][key] ?? key
}
```

### Locale Hook

```typescript
// src/hooks/useLocale.ts
import { useGemScanStore } from '@/lib/store'
import type { Locale } from '@/lib/i18n/strings'

export function useLocale(): Locale {
  const { preferredLanguage } = useGemScanStore()
  const supported: Locale[] = ['en', 'hi', 'ja', 'es', 'zh-Hans']
  return (supported.includes(preferredLanguage as Locale) ? preferredLanguage : 'en') as Locale
}
```

---

## 7. UX Testing Checklist

- [ ] `ScamWarningCard` receives focus on mount (Playwright: check `document.activeElement`)
- [ ] All three verdict states render with correct colour + icon (Playwright visual snapshot)
- [ ] `StreamingReasoningView` announces completion to screen reader (Playwright `aria-live` check)
- [ ] `ModelDownloadProgress` `aria-valuetext` updates correctly at 0%, 50%, 100% (Vitest)
- [ ] Guardian mode status bar visible on all screens when `guardianModeEnabled: true` (Playwright)
- [ ] Guardian setup flow completes in < 5 taps (Playwright: count interaction steps)
- [ ] Caregiver invitation accepted with valid token (Playwright: mock token validation)
- [ ] All strings present for all 5 locales (Vitest: verify `strings` completeness)
- [ ] `useLocale` falls back to `en` for unsupported language (Vitest)
- [ ] Dynamic Type: all text readable at Accessibility XL (XCUITest: contentSizeCategory override)
- [ ] Colour contrast passes AA for all interactive elements (axe-core in Playwright)
- [ ] All buttons have minimum 44×44 pt touch target (XCUITest)
- [ ] VoiceOver reads verdict correctly without raw model tier jargon (manual XCUITest)
- [ ] Reduced motion: no animation when `UIAccessibility.isReduceMotionEnabled` (XCUITest)
