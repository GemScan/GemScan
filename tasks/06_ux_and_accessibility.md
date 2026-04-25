# Tasks — UI, Accessibility & Guardian Mode

> **Spec:** `specs/06_ux_and_accessibility.md` | **Milestone:** M6 — UI, Accessibility & Guardian Mode | **Depends on:** M5

## Milestone Summary
Implements all user-facing components, pages, and Guardian Mode infrastructure for the GemScan iOS app. Covers React/Next.js UI components (ScamWarningCard, StreamingReasoningView, ModelDownloadProgress, ContactPicker), all six app routes (onboarding, analyse, guardian setup/invite, settings), the GuardianKeyManager Swift Keychain layer, i18n string tables for five locales, global accessibility CSS, and the full test suite for this milestone.

## Prerequisites
- M0 complete: Zustand store, GemScanError types, Capacitor project scaffold
- M1 complete: GemmaPlugin interface defined, pages scaffold in place
- `@capacitor-community/contacts` installed
- `GemmaPlugin` events `tokenStream`, `downloadProgress` implemented in Swift plugin

## Progress Tracker
| Status | Count |
|--------|-------|
| ✅ Done | 0 |
| 🔄 In progress | 0 |
| ⬜ Not started | 21 |

---
## Tasks

#### ⬜ T-06-001 · ScamWarningCard component

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P0 |
| **Spec ref** | §3.1 — ScamWarningCard |
| **Depends on** | None |
| **Estimated effort** | M |
| **Files to create/modify** | `src/components/ScamWarningCard.tsx` |

**What to build:**
Create `src/components/ScamWarningCard.tsx` with props interface `{ result: AgentResult; onShare: () => void; onDismiss: () => void }`. Use `useRef<HTMLHeadingElement>` and `useEffect` to focus the verdict heading on mount so VoiceOver announces the result immediately. Implement `verdictDisplay()` mapping `'safe' | 'suspicious' | 'scam'` to colour variant strings, icon components, and human-readable labels. Render a confidence bar with `role="meter"` and `aria-valuenow`, `aria-valuemin`, `aria-valuemax` attributes set to the numeric confidence value. Action buttons (Share, Dismiss) must carry descriptive `aria-label` strings that vary by verdict (e.g., `aria-label="Share scam warning"` vs `aria-label="Dismiss safe result"`).

**Acceptance criteria:**
- [ ] Verdict heading receives programmatic focus on mount via `useRef<HTMLHeadingElement>` + `useEffect`
- [ ] `verdictDisplay()` returns correct colour variant, icon, and label for each of `safe`, `suspicious`, `scam`
- [ ] Confidence bar has `role="meter"`, `aria-valuenow={result.confidence}`, `aria-valuemin={0}`, `aria-valuemax={1}`
- [ ] Share button is absent (not rendered) when `result.verdict === 'safe'`
- [ ] All buttons have descriptive `aria-label` attributes
- [ ] Component renders without errors for all three verdict values

**Apple compliance (Spec 00 §11):**
- [ ] §11.5 — HIG: tappable buttons meet 44×44 pt minimum touch target
- [ ] §11.7 — Accessibility: focus management implemented via `useRef`/`useEffect`

---

#### ⬜ T-06-002 · StreamingReasoningView component

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P0 |
| **Spec ref** | §3.2 — StreamingReasoningView |
| **Depends on** | None |
| **Estimated effort** | M |
| **Files to create/modify** | `src/components/StreamingReasoningView.tsx` |

**What to build:**
Create `src/components/StreamingReasoningView.tsx` with props `{ taskId: string }`. On mount, call `GemmaPlugin.addListener('tokenStream', handler)` and filter events by `event.taskId === taskId`; append each `event.token` to a `string[]` state array. Render the joined token array as visible text alongside an animated blinking cursor element while `isStreaming` is true. Include an off-screen `<div aria-live="polite" aria-atomic="false">` region that receives a completion message ("Analysis complete") when streaming ends, so screen readers announce the result without re-reading the full text. Clean up the listener handle in the `useEffect` return function to prevent memory leaks.

**Acceptance criteria:**
- [ ] Subscribes to `GemmaPlugin.addListener('tokenStream', ...)` on mount and unsubscribes on unmount
- [ ] Filters events by `taskId` before appending tokens to state
- [ ] Animated cursor is visible while streaming and hidden after completion
- [ ] Off-screen `aria-live="polite"` region announces completion message to screen readers
- [ ] No memory leaks — listener handle is removed in `useEffect` cleanup

**Apple compliance (Spec 00 §11):**
- [ ] §11.7 — Accessibility: `aria-live` region present for screen reader announcements
- [ ] N/A — no native Swift code in this component

---

#### ⬜ T-06-003 · ModelDownloadProgress component

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P0 |
| **Spec ref** | §3.3 — ModelDownloadProgress |
| **Depends on** | None |
| **Estimated effort** | S |
| **Files to create/modify** | `src/components/ModelDownloadProgress.tsx` |

**What to build:**
Create `src/components/ModelDownloadProgress.tsx` subscribing to `GemmaPlugin.addListener('downloadProgress', handler)` on mount. Maintain state for three models: `distilbert` (5 MB total), `e2b` (1,800 MB total), `e4b` (3,200 MB total). For each model render a progress bar element with `role="progressbar"`, `aria-valuenow={pct}`, `aria-valuemin={0}`, `aria-valuemax={100}`, and `aria-valuetext` showing human-readable MB downloaded (e.g., `"450 of 1800 MB"`). Apply `className="transition-all duration-300"` to the inner fill element for smooth animation. Clean up the listener on unmount.

**Acceptance criteria:**
- [ ] Three progress bars rendered for `distilbert`, `e2b`, `e4b` with correct total MB labels
- [ ] Each bar has `role="progressbar"`, `aria-valuenow`, `aria-valuemin=0`, `aria-valuemax=100`, `aria-valuetext`
- [ ] `aria-valuetext` shows MB downloaded (e.g., `"450 of 1800 MB"`)
- [ ] Fill element uses `transition-all duration-300` for smooth animation
- [ ] Listener cleaned up on unmount

**Apple compliance (Spec 00 §11):**
- [ ] §11.7 — Accessibility: all progress bars have complete ARIA attributes
- [ ] N/A — no native Swift code in this component

---

#### ⬜ T-06-004 · ContactPicker component

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P1 |
| **Spec ref** | §3.4 — ContactPicker |
| **Depends on** | None |
| **Estimated effort** | M |
| **Files to create/modify** | `src/components/ContactPicker.tsx` |

**What to build:**
Create `src/components/ContactPicker.tsx` with props `{ selectedId: string | null; onSelect: (id: string) => void }`. On mount, call `Contacts.getContacts()` from `@capacitor-community/contacts`; filter the result to contacts that have a truthy `name.display` field; map each to `{ id: string; displayName: string; phoneOrEmail: string }`. Sort the mapped array with `localeCompare(b.displayName, preferredLanguage, { sensitivity: 'base' })` where `preferredLanguage` comes from the Zustand locale store. Implement `maskContact(value: string): string` that masks email addresses as `us***@domain.com` and phone numbers as `NXX-***-XXXX`. Each contact is a `<button>` with `aria-pressed={selectedId === contact.id}`.

**Acceptance criteria:**
- [ ] Calls `Contacts.getContacts()` and filters out contacts without `name.display`
- [ ] Mapped contacts sorted with `localeCompare` using `preferredLanguage` and `{ sensitivity: 'base' }`
- [ ] `maskContact()` correctly masks email (`us***@domain`) and phone (`NXX-***-XXXX`)
- [ ] Each contact button has `aria-pressed={selectedId === contact.id}`
- [ ] Selecting a contact calls `onSelect(contact.id)`

**Apple compliance (Spec 00 §11):**
- [ ] §11.3 — Contacts permission: usage governed by `NSContactsUsageDescription` in `Info.plist`
- [ ] §11.7 — Accessibility: `aria-pressed` state on toggle buttons

---

#### ⬜ T-06-005 · Onboarding page (`/onboarding`)

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P0 |
| **Spec ref** | §6 — Onboarding strings and flow |
| **Depends on** | T-06-003, T-06-010 |
| **Estimated effort** | S |
| **Files to create/modify** | `src/app/onboarding/page.tsx` |

**What to build:**
Implement `src/app/onboarding/page.tsx` as a client component. On mount, call `GemmaPlugin.downloadModels({ modelIds: ['distilbert', 'e2b'] })`. Render the `ModelDownloadProgress` component to display live download state. Display the consent/welcome copy using the i18n keys `onboarding.title` and `onboarding.subtitle` retrieved via `useLocale()` and the `t()` helper. When all downloads complete (all three `downloadProgress` bars reach 100%), navigate to `/` via `useRouter().push('/')`. No download should be triggered again if models are already present.

**Acceptance criteria:**
- [ ] Calls `GemmaPlugin.downloadModels({ modelIds: ['distilbert', 'e2b'] })` exactly once on mount
- [ ] `ModelDownloadProgress` component visible during download
- [ ] Page displays `onboarding.title` and `onboarding.subtitle` from locale strings via `useLocale()`
- [ ] Navigates to `/` automatically on completion
- [ ] Does not re-trigger download if models already downloaded

**Apple compliance (Spec 00 §11):**
- [ ] §11.7 — Accessibility: consent copy rendered as semantic text, not image
- [ ] N/A — no native Swift code in this page

---

#### ⬜ T-06-006 · Analyse result page (`/analyse`)

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P0 |
| **Spec ref** | §3.1, §3.2 — ScamWarningCard and StreamingReasoningView integration |
| **Depends on** | T-06-001, T-06-002 |
| **Estimated effort** | M |
| **Files to create/modify** | `src/app/analyse/page.tsx` |

**What to build:**
Implement `src/app/analyse/page.tsx` as a client component that reads `taskId` from the URL search params (via `useSearchParams()`). While inference is running, render `<StreamingReasoningView taskId={taskId} />`. When the `AgentResult` arrives (via a store subscription or resolved Promise), switch to rendering `<ScamWarningCard result={result} onShare={handleShare} onDismiss={handleDismiss} />`. The `handleShare` callback calls `GemmaPlugin.sendGuardianAlert({ severity: 'high' })` only when `guardianModeEnabled` is true in the Zustand store. The `handleDismiss` callback calls `router.back()`.

**Acceptance criteria:**
- [ ] `taskId` read from URL search params
- [ ] `StreamingReasoningView` visible during inference, hidden after result arrives
- [ ] `ScamWarningCard` rendered with correct `AgentResult` on completion
- [ ] `handleShare` calls `GemmaPlugin.sendGuardianAlert({ severity: 'high' })` only when Guardian mode is enabled
- [ ] `handleDismiss` navigates back via `router.back()`

**Apple compliance (Spec 00 §11):**
- [ ] §11.7 — Accessibility: focus management from `ScamWarningCard` (heading focused on result)
- [ ] N/A — no native Swift code in this page

---

#### ⬜ T-06-007 · Guardian setup page (`/guardian/setup`)

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P1 |
| **Spec ref** | §4.1 — Guardian setup page |
| **Depends on** | T-06-004 |
| **Estimated effort** | M |
| **Files to create/modify** | `src/app/guardian/setup/page.tsx` |

**What to build:**
Implement `src/app/guardian/setup/page.tsx` as a client component. Render `<ContactPicker>` bound to local `selectedContactId` state. Below the picker, render two `<input type="radio">` options for alert sensitivity: `scam_only` and `all_warnings`, both bound to a `alertLevel` state variable. Implement `handleEnable()` which calls `setTrustedContact(selectedContactId)` then `setGuardianMode(true)` from the Zustand store, then navigates to `/` via `router.push('/')`. The "Turn on Guardian Mode" button must have `disabled={selectedContactId === null}` to prevent enabling without a contact selected.

**Acceptance criteria:**
- [ ] `ContactPicker` rendered and bound to local `selectedContactId` state
- [ ] Radio buttons for `scam_only` and `all_warnings` alert levels present
- [ ] "Turn on Guardian Mode" button is `disabled` when no contact is selected
- [ ] `handleEnable()` calls `setTrustedContact()`, `setGuardianMode(true)`, then navigates to `/`
- [ ] Page renders correctly on first visit with no pre-selected contact

**Apple compliance (Spec 00 §11):**
- [ ] §11.3 — Contacts permission obtained before `ContactPicker` calls `getContacts()`
- [ ] §11.7 — Accessibility: radio buttons have associated `<label>` elements

---

#### ⬜ T-06-008 · Guardian invite page (`/guardian/invite`)

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P1 |
| **Spec ref** | §4.2 — Guardian invite page |
| **Depends on** | T-06-010 |
| **Estimated effort** | M |
| **Files to create/modify** | `src/app/guardian/invite/page.tsx` |

**What to build:**
Implement `src/app/guardian/invite/page.tsx` as a client component. Read `token` from `useSearchParams()`. On mount, call `validateInvitationToken(token)` — in Cycle 1 this is a web mock that delays 800 ms via `setTimeout` then returns a placeholder contact object `{ id: 'mock-guardian-1', displayName: 'Your Guardian' }`. On success, call `setTrustedContact(contact.id)` and `setGuardianMode(true)` from the Zustand store, then render a success state with a confirmation message. On error (token missing or invalid), render an "Invitation not found" error state with retry guidance text directing the user to ask their guardian to re-send the invite link.

**Acceptance criteria:**
- [ ] `token` read from URL search params
- [ ] `validateInvitationToken(token)` called on mount with 800 ms mock delay
- [ ] On success: `setTrustedContact` and `setGuardianMode(true)` called, success UI rendered
- [ ] On error: "Invitation not found" message and retry guidance rendered
- [ ] Missing or short (`< 10` chars) token treated as error

**Apple compliance (Spec 00 §11):**
- [ ] §11.7 — Accessibility: loading, success, and error states all have appropriate ARIA roles
- [ ] N/A — no native Swift code in this page

---

#### ⬜ T-06-009 · GuardianStatusBar component

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P1 |
| **Spec ref** | §4.3 — GuardianStatusBar |
| **Depends on** | None |
| **Estimated effort** | S |
| **Files to create/modify** | `src/components/GuardianStatusBar.tsx`, `src/app/layout.tsx` |

**What to build:**
Create `src/components/GuardianStatusBar.tsx` which reads `guardianModeEnabled` from the Zustand store. If `guardianModeEnabled` is false, return `null` (render nothing). When active, render a banner with `role="status"` and `aria-label="Guardian mode is active"`. Include a "Pause" button with `aria-label="Pause Guardian mode"` that calls `setGuardianMode(false)` from the store when clicked. Add `<GuardianStatusBar />` to `src/app/layout.tsx` so it appears on every page in the app without duplication.

**Acceptance criteria:**
- [ ] Returns `null` when `guardianModeEnabled` is false
- [ ] Renders banner with `role="status"` and `aria-label="Guardian mode is active"` when active
- [ ] "Pause" button calls `setGuardianMode(false)` and hides the bar
- [ ] Component is mounted in `src/app/layout.tsx` so it appears on every route
- [ ] No duplicate renders — only one instance in the layout

**Apple compliance (Spec 00 §11):**
- [ ] §11.7 — Accessibility: `role="status"` and descriptive `aria-label` present

---

#### ⬜ T-06-010 · i18n strings + locale hook

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P1 |
| **Spec ref** | §6 — i18n string tables |
| **Depends on** | None |
| **Estimated effort** | M |
| **Files to create/modify** | `src/lib/i18n/strings.ts`, `src/hooks/useLocale.ts` |

**What to build:**
Create `src/lib/i18n/strings.ts` exporting a `strings` record keyed by locale code (`en`, `hi`, `ja`, `es`, `zh-Hans`). Each locale entry must contain all 11 required keys: `onboarding.title`, `onboarding.subtitle`, `analyse.title`, `analyse.placeholder`, `verdict.safe`, `verdict.suspicious`, `verdict.scam`, `guardian.status`, `guardian.pause`, `settings.language`, `settings.guardian`. Create `src/hooks/useLocale.ts` exporting a `useLocale()` hook that reads the locale from the Zustand store and falls back to `'en'` if the value is not one of the five supported codes. Export a `setLocale(locale: string)` function that updates the Zustand store and calls `Preferences.set({ key: 'gemscan.userLanguageCode', value: locale })` in a try/catch, logging a non-fatal `console.warn` on failure without throwing.

**Acceptance criteria:**
- [ ] `strings.ts` exports entries for all 5 locales: `en`, `hi`, `ja`, `es`, `zh-Hans`
- [ ] Each locale has all 11 required keys present (no missing keys)
- [ ] `useLocale()` returns `'en'` for an unsupported or null locale value
- [ ] `setLocale()` updates Zustand store and calls `Preferences.set()`
- [ ] `setLocale()` does not throw on `Preferences.set` failure — logs warning only

**Apple compliance (Spec 00 §11):**
- [ ] N/A — no native Swift code in this file

---

#### ⬜ T-06-011 · Global accessibility CSS

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P1 |
| **Spec ref** | §5 — Accessibility CSS |
| **Depends on** | None |
| **Estimated effort** | S |
| **Files to create/modify** | `src/styles/globals.css` |

**What to build:**
Create or update `src/styles/globals.css` with three sections. First, define CSS custom properties for text sizes: `--text-base: 1rem`, `--text-sm: 0.875rem`, `--text-lg: 1.125rem`, `--text-xl: 1.25rem`, `--text-2xl: 1.5rem`. Second, add a minimum tap target rule: `button, [role="button"] { min-height: 44px; min-width: 44px; }` to comply with HIG and WCAG 2.5.8. Third, add a `@media (prefers-reduced-motion: reduce)` block that sets `animation: none !important` and `transition: none !important` for `.animate-pulse`, `.animate-spin`, and `.transition-all` selectors, respecting user motion preferences.

**Acceptance criteria:**
- [ ] CSS custom properties for all 5 text size variables defined
- [ ] `button, [role="button"]` rule enforces `min-height: 44px; min-width: 44px`
- [ ] `@media (prefers-reduced-motion: reduce)` block disables `.animate-pulse`, `.animate-spin`, `.transition-all`
- [ ] File is imported in the Next.js app (via `layout.tsx` or `_app.tsx`)
- [ ] No existing styles are broken by the additions

**Apple compliance (Spec 00 §11):**
- [ ] §11.5 — HIG: 44×44 pt minimum tap target enforced globally
- [ ] §11.7 — Accessibility: reduced motion media query implemented

---

#### ⬜ T-06-012 · GuardianKeyManager Swift

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P1 |
| **Spec ref** | §4.4 — GuardianKeyManager |
| **Depends on** | None |
| **Estimated effort** | L |
| **Files to create/modify** | `ios/App/GemmaKit/Sources/Guardian/GuardianKeyManager.swift` |

**What to build:**
Create `ios/App/GemmaKit/Sources/Guardian/GuardianKeyManager.swift` as an `enum` (caseless namespace) with 6 static methods. `generateAndStoreKeypair() throws -> Data` generates a new ed25519 key pair using `SecKeyCreateRandomKey`, stores the private key in the Keychain with `kSecAttrAccessibleAfterFirstUnlock`, and returns the public key as `Data`. `loadPrivateKey() throws -> SecKey` reads the private key from the Keychain. `sign(_ data: Data) throws -> Data` loads the private key and calls `SecKeyCreateSignature` returning a 64-byte ed25519 signature. `storeTrustedContactToken(_ token: String) throws` writes the token to the Keychain under a fixed key. `loadTrustedContactToken() throws -> String` reads it back. `rotateKeypair() throws -> Data` calls `SecItemDelete` on the existing key before calling `generateAndStoreKeypair()` — the delete step must occur before the add. All Keychain items must use `kSecAttrAccessibleAfterFirstUnlock`.

**Acceptance criteria:**
- [ ] `generateAndStoreKeypair()` stores private key with `kSecAttrAccessibleAfterFirstUnlock`
- [ ] `loadPrivateKey()` returns the same key stored by `generateAndStoreKeypair()`
- [ ] `sign(_:)` returns a 64-byte Data value
- [ ] `rotateKeypair()` calls `SecItemDelete` before `SecItemAdd` (no duplicate key error)
- [ ] All 6 static methods implemented and throw typed errors on Keychain failures
- [ ] `storeTrustedContactToken` / `loadTrustedContactToken` round-trip correctly

**Apple compliance (Spec 00 §11):**
- [ ] §11.6 — Keychain: all items use `kSecAttrAccessibleAfterFirstUnlock`
- [ ] §11.6 — Keychain: `SecItemDelete` called before `SecItemAdd` to replace existing entries

---

#### ⬜ T-06-013 · Guardian relay + local fallback

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P2 |
| **Spec ref** | §4.5 — Guardian relay |
| **Depends on** | T-06-012 |
| **Estimated effort** | M |
| **Files to create/modify** | `ios/App/GemmaKit/Sources/Plugin/GemmaPlugin+Guardian.swift` |

**What to build:**
Implement `sendGuardianAlert(severity:)` as a method in `GemmaPlugin+Guardian.swift`. First, read `relayToken` from `UserDefaults.standard.string(forKey: "gemscan.relayToken")`. If `relayToken` is nil or empty, call `GuardianKeyManager.sendLocalTestAlert(severity:)` via `UNUserNotificationCenter.current()` to deliver a local notification, then return `{ "sent": false, "reason": "relay_not_configured" }` as the plugin call result. If `relayToken` is present, construct a POST request to `https://relay.gemscan.app/v1/alert` with a JSON body containing `severity`, `timestamp`, and a `signature` produced by `GuardianKeyManager.sign(payload)`. On HTTP 200, return `{ "sent": true }`. On non-200 or network error, return `{ "sent": false, "reason": "relay_error" }`.

**Acceptance criteria:**
- [ ] Reads `relayToken` from `UserDefaults.standard`
- [ ] When `relayToken` absent: fires local `UNUserNotificationCenter` notification and returns `{sent:false, reason:"relay_not_configured"}`
- [ ] When `relayToken` present: POSTs signed payload to `https://relay.gemscan.app/v1/alert`
- [ ] HTTP 200 response returns `{sent:true}`
- [ ] Non-200 or network error returns `{sent:false, reason:"relay_error"}`

**Apple compliance (Spec 00 §11):**
- [ ] §11.6 — Keychain: relay token signing uses `GuardianKeyManager.sign(_:)`
- [ ] §11.4 — Network: ATS-compliant HTTPS endpoint used

---

#### ⬜ T-06-014 · Settings page

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P2 |
| **Spec ref** | §5 — Settings page |
| **Depends on** | T-06-009, T-06-010 |
| **Estimated effort** | S |
| **Files to create/modify** | `src/app/settings/page.tsx` |

**What to build:**
Implement `src/app/settings/page.tsx` as a client component. Render a `<select>` language picker listing all 5 locale options (`en`, `hi`, `ja`, `es`, `zh-Hans`) with their display names; on change, call `setLocale(newLocale)` which triggers `useLocale` re-render throughout the app. Render a Guardian mode toggle switch bound to `guardianModeEnabled` from the Zustand store; toggling calls `setGuardianMode`. When a trusted contact is set, display their masked name/contact (using the `maskContact()` function from `ContactPicker`) and a "Change contact" link navigating to `/guardian/setup`.

**Acceptance criteria:**
- [ ] Language picker renders all 5 locale options with display names
- [ ] Selecting a locale calls `setLocale(locale)` and the UI re-renders in the new language
- [ ] Guardian mode toggle reflects and updates `guardianModeEnabled` in the store
- [ ] Trusted contact displayed masked when set
- [ ] "Change contact" link present when a trusted contact is configured

**Apple compliance (Spec 00 §11):**
- [ ] §11.7 — Accessibility: `<select>` has associated `<label>`, toggle has `aria-checked`
- [ ] N/A — no native Swift code in this page

---

#### ⬜ T-06-015 · Component tests

| Field | Value |
|---|---|
| **Type** | TEST |
| **Priority** | P1 |
| **Spec ref** | §7 — Component unit tests |
| **Depends on** | T-06-001, T-06-002, T-06-003, T-06-004 |
| **Estimated effort** | M |
| **Files to create/modify** | `src/components/__tests__/ScamWarningCard.test.tsx`, `src/components/__tests__/StreamingReasoningView.test.tsx`, `src/components/__tests__/ModelDownloadProgress.test.tsx`, `src/components/__tests__/ContactPicker.test.tsx` |

**What to build:**
Write Vitest + React Testing Library unit tests for all four components. For `ScamWarningCard`: verify focus moves to the verdict heading on mount; verify correct icon class and text colour class for each of `safe`, `suspicious`, `scam`; verify the share button is not rendered when `verdict === 'safe'`. For `StreamingReasoningView`: fire mock `tokenStream` events and assert tokens are appended to the displayed text. For `ModelDownloadProgress`: fire mock `downloadProgress` events and assert `aria-valuenow` updates correctly. For `ContactPicker`: assert that phone numbers in the rendered list are masked to `NXX-***-XXXX` format.

**Acceptance criteria:**
- [ ] `ScamWarningCard`: heading focused on mount (checked via `document.activeElement`)
- [ ] `ScamWarningCard`: correct colour/icon/label for all three verdicts
- [ ] `ScamWarningCard`: share button absent when `verdict === 'safe'`
- [ ] `StreamingReasoningView`: token append verified on mock event
- [ ] `ModelDownloadProgress`: `aria-valuenow` updates on `downloadProgress` event
- [ ] `ContactPicker`: phone numbers rendered masked

**Apple compliance (Spec 00 §11):**
- [ ] N/A — no native code; covered by XCUITest in T-06-021

---

#### ⬜ T-06-016 · Playwright E2E: analysis flow

| Field | Value |
|---|---|
| **Type** | TEST |
| **Priority** | P1 |
| **Spec ref** | §8.1 — E2E analysis flow |
| **Depends on** | T-06-001, T-06-002, T-06-006 |
| **Estimated effort** | M |
| **Files to create/modify** | `e2e/analyse-sms.spec.ts`, `e2e/accessibility.spec.ts` |

**What to build:**
Create `e2e/analyse-sms.spec.ts` testing the full SMS analysis flow: fill the home page textarea with a scam SMS fixture string, click the "Analyse" button, await the verdict heading to appear (timeout 10 s), assert that `document.activeElement` matches the heading (focus management), and assert at least 2 reasoning bullet list items are visible. Create `e2e/accessibility.spec.ts` using `@axe-core/playwright` to scan all 6 routes (`/`, `/onboarding`, `/analyse`, `/guardian/setup`, `/guardian/invite`, `/settings`) and assert zero critical WCAG 2A + 2AA violations. Also assert that all progress bars on `/onboarding` have `aria-valuenow`, `aria-valuemin`, and `aria-valuemax` attributes. Assert `<GuardianStatusBar>` is visible on all 6 routes when Guardian mode is enabled.

**Acceptance criteria:**
- [ ] SMS analysis flow completes and verdict heading appears within 10 s
- [ ] Verdict heading receives focus after result renders
- [ ] At least 2 reasoning bullets visible
- [ ] axe-core reports zero critical violations on all 6 routes
- [ ] Progress bars have all required ARIA attributes
- [ ] GuardianStatusBar visible on all routes when enabled

**Apple compliance (Spec 00 §11):**
- [ ] §11.7 — Accessibility: axe-core zero-violation gate enforced in CI

---

#### ⬜ T-06-017 · Playwright E2E: Guardian setup

| Field | Value |
|---|---|
| **Type** | TEST |
| **Priority** | P1 |
| **Spec ref** | §8.2 — E2E Guardian setup |
| **Depends on** | T-06-007, T-06-008, T-06-009 |
| **Estimated effort** | M |
| **Files to create/modify** | `e2e/guardian-setup.spec.ts`, `e2e/guardian-invite.spec.ts` |

**What to build:**
Create `e2e/guardian-setup.spec.ts`: navigate to `/guardian/setup`, select a mock contact from the `ContactPicker`, click "Turn on Guardian Mode", assert redirection to `/`, assert the `GuardianStatusBar` banner is visible (role="status"), assert the whole flow required fewer than 5 clicks/taps. Also assert that clicking the "Pause" button in the status bar hides the bar. Create `e2e/guardian-invite.spec.ts`: navigate to `/guardian/invite?token=valid-token-12345`, await success state (contact name displayed), assert `guardianModeEnabled` store is true. Then navigate with `token=bad`, assert "Invitation not found" error message is visible.

**Acceptance criteria:**
- [ ] Guardian setup completes in fewer than 5 user interactions
- [ ] `GuardianStatusBar` visible on `/` after setup
- [ ] Pause button hides the status bar
- [ ] Valid invite token shows success state and enables Guardian mode
- [ ] Invalid/short token shows "Invitation not found" error

**Apple compliance (Spec 00 §11):**
- [ ] §11.7 — Accessibility: success and error states verified by E2E tests

---

#### ⬜ T-06-018 · i18n completeness tests

| Field | Value |
|---|---|
| **Type** | TEST |
| **Priority** | P2 |
| **Spec ref** | §6 — i18n string tables |
| **Depends on** | T-06-010 |
| **Estimated effort** | S |
| **Files to create/modify** | `src/lib/i18n/__tests__/strings.test.ts` |

**What to build:**
Create `src/lib/i18n/__tests__/strings.test.ts` with three test groups. First, iterate over all 5 locale codes and all 11 required key names, asserting each key is a non-empty string — this catches missing translations at CI time. Second, call a `t(unsupportedLocale, key)` helper with an unsupported locale code (e.g., `'fr'`) and assert the returned string equals the English fallback. Third, render `useLocale()` in a test component using `@testing-library/react`'s `renderHook` with the Zustand store pre-populated with an unsupported locale, and assert the hook returns `'en'`.

**Acceptance criteria:**
- [ ] All 11 keys present for all 5 locales — test fails if any key is missing
- [ ] `t()` returns English fallback for unsupported locale
- [ ] `useLocale()` returns `'en'` for unsupported locale value in store
- [ ] Tests run in under 500 ms total

**Apple compliance (Spec 00 §11):**
- [ ] N/A — no native code in this test file

---

#### ⬜ T-06-019 · GuardianKeyManager tests

| Field | Value |
|---|---|
| **Type** | TEST |
| **Priority** | P2 |
| **Spec ref** | §4.4, §9.2 — GuardianKeyManager and Keychain compliance |
| **Depends on** | T-06-012 |
| **Estimated effort** | M |
| **Files to create/modify** | `ios/App/GemmaKit/Tests/GuardianKeyManagerTests.swift` |

**What to build:**
Create `ios/App/GemmaKit/Tests/GuardianKeyManagerTests.swift` as an `XCTestCase` subclass. `testGenerateAndStoreKeypairReturnsPublicKey()`: call `generateAndStoreKeypair()` and assert the returned `Data` is non-empty. `testLoadPrivateKeyAfterGenerateSucceeds()`: generate then immediately load and assert no throw. `testSignProduces64ByteSignature()`: generate a keypair, call `sign(Data("hello".utf8))`, assert `result.count == 64`. `testRotateKeypairReplacesOldKey()`: generate, save the public key, rotate, generate again, assert the new public key differs from the first. `testGuardianKeychainAccessibility()`: inspect the Keychain item's `kSecAttrAccessible` attribute after `generateAndStoreKeypair()` and assert it equals `kSecAttrAccessibleAfterFirstUnlock`.

**Acceptance criteria:**
- [ ] `testGenerateAndStoreKeypairReturnsPublicKey` passes
- [ ] `testLoadPrivateKeyAfterGenerateSucceeds` passes (no throw)
- [ ] `testSignProduces64ByteSignature` asserts `count == 64`
- [ ] `testRotateKeypairReplacesOldKey` verifies new ≠ old public key
- [ ] `testGuardianKeychainAccessibility` verifies `kSecAttrAccessibleAfterFirstUnlock`

**Apple compliance (Spec 00 §11):**
- [ ] §11.6 — Keychain: `kSecAttrAccessibleAfterFirstUnlock` verified by XCTest

---

#### ⬜ T-06-020 · UX component documentation

| Field | Value |
|---|---|
| **Type** | DOCUMENT |
| **Priority** | P2 |
| **Spec ref** | §3 — Component specifications |
| **Depends on** | T-06-001, T-06-002, T-06-003, T-06-004, T-06-010 |
| **Estimated effort** | S |
| **Files to create/modify** | `src/components/ScamWarningCard.tsx`, `src/components/StreamingReasoningView.tsx`, `src/components/ModelDownloadProgress.tsx`, `src/components/ContactPicker.tsx`, `src/hooks/useLocale.ts`, `docs/guardian-mode.md` |

**What to build:**
Add JSDoc block comments to all exported props interfaces in the four component files. Each prop must have a `@param` description. For `ScamWarningCard.Props`, document that `onShare` is not called when `verdict === 'safe'` (the button is not rendered). For `setLocale()` in `useLocale.ts`, document the two side effects: Zustand store update (synchronous) and `Preferences.set()` write (async, non-fatal on failure). Create `docs/guardian-mode.md` explaining: the relay architecture (QR pairing flow, relay server URL, signed JWT payload); the Keychain keypair lifecycle; and the Cycle 1 local notification fallback when relay is not configured.

**Acceptance criteria:**
- [ ] All props interfaces in all four components have JSDoc comments
- [ ] `setLocale()` documents both side effects and failure behaviour
- [ ] `docs/guardian-mode.md` covers relay architecture, QR pairing, and local fallback
- [ ] No TypeScript errors introduced by JSDoc additions

**Apple compliance (Spec 00 §11):**
- [ ] N/A — documentation task

---

#### ⬜ T-06-021 · UX Apple compliance

| Field | Value |
|---|---|
| **Type** | VALIDATE |
| **Priority** | P1 |
| **Spec ref** | §11.5, §11.6, §11.7 — HIG, Keychain, Accessibility |
| **Depends on** | T-06-001, T-06-002, T-06-003, T-06-004, T-06-005, T-06-006, T-06-007, T-06-008, T-06-009, T-06-011, T-06-012 |
| **Estimated effort** | M |
| **Files to create/modify** | `ios/App/Tests/UITests/AccessibilityUITests.swift` |

**What to build:**
Create `ios/App/Tests/UITests/AccessibilityUITests.swift` with four XCUITest methods. `testMinimumTapTargetSize()`: iterate all buttons on each of the 6 screens and assert `frame.width >= 44 && frame.height >= 44`. `testDynamicTypeAccessibilityXXL()`: launch app with `UIContentSizeCategoryAccessibilityExtraExtraExtraLarge`, navigate all 6 screens, assert no label is truncated (check `label.isEqual(to: "...")` is false). `testDarkModeNoHardcodedColours()`: launch in dark mode, screenshot all screens, perform a pixel-level check that no element has a pure white (#FFFFFF) background in dark mode. `testVoiceOverLabelCoverage()`: enable VoiceOver via `XCUIDevice.shared.perform(NSSelectorFromString("toggleVoiceOverEnabled"))`, navigate all 6 screens using swipe gestures, assert no element has `label == "button"` or `label == ""`.

**Acceptance criteria:**
- [ ] All buttons ≥ 44×44 pt on all 6 screens
- [ ] No truncated text at Accessibility-XXL Dynamic Type
- [ ] No hard-coded colours in dark mode (asset catalogue verified)
- [ ] No unlabelled or generically-labelled VoiceOver elements
- [ ] `@media (prefers-reduced-motion)` CSS verified by Playwright `e2e/accessibility.spec.ts`
- [ ] Spec 00 §11.5 (HIG), §11.6 (Keychain), §11.7 (Accessibility) checklist items signed off

**Apple compliance (Spec 00 §11):**
- [ ] §11.5 — HIG: minimum tap target XCUITest gate passes
- [ ] §11.6 — Keychain: tested in T-06-019
- [ ] §11.7 — Accessibility: Dynamic Type, Dark Mode, VoiceOver all verified
