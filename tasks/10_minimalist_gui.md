# Tasks — Minimalist GUI

> **Spec:** `specs/10_minimalist_gui.md` | **Milestone:** M10 — Minimalist GUI | **Depends on:** M0, M1, M6

## Milestone Summary
Replaces the functional wireframes from M6 with a cohesive minimalist production GUI. Implements the colour system, typography scale, spacing constants, six new components (VerdictCard, StreamingText, ProgressRow, InputArea, ResultRow, SettingsRow), refactors all five app pages to match the spec wireframes, and validates accessibility compliance. No new business logic — this milestone is purely visual.

## Prerequisites
- M0 complete: core types, store, GemmaPlugin mock
- M1 complete: App Router pages exist, hooks exist
- M6 complete: existing components functional (this milestone replaces their visuals)

## Progress Tracker
| Status | Count |
|--------|-------|
| ✅ Done | 0 |
| 🔄 In progress | 0 |
| ⬜ Not started | 18 |

Update this table as tasks complete. Each task row also has a status checkbox.

---

## Tasks

### Group: Design Tokens

---

#### ⬜ T-10-001 · Implement colour system and spacing CSS variables

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P0 (blocking) |
| **Spec ref** | §2 — Colour System; §7 — Spacing and Layout Constants |
| **Depends on** | None |
| **Estimated effort** | S (< 1 hr) |
| **Files to create/modify** | `src/styles/globals.css` |

**What to build:**
Replace the existing CSS custom properties in `src/styles/globals.css` with the full colour system from Spec 10 §2: verdict colours (`--safe`, `--suspicious`, `--scam`), verdict tint backgrounds (`--safe-bg`, `--suspicious-bg`, `--scam-bg`), neutral surfaces (`--surface`, `--surface-alt`, `--text`, `--text-muted`, `--border`), and all layout constants from §7 (`--padding-page`, `--gap-section`, `--gap-element`, `--radius-card`, `--radius-button`, `--radius-input`, `--height-button`, `--height-row`, `--height-input`, `--bar-height`). Include the `prefers-color-scheme: dark` media query with the dark-mode overrides. Remove any existing Tailwind colour overrides that conflict.

**Acceptance criteria:**
- [ ] All 11 colour variables defined in `:root` and dark-mode override
- [ ] All 10 spacing/layout variables defined in `:root`
- [ ] `--safe` (#1A7F37) passes WCAG AA on white (4.5:1 minimum)
- [ ] Dark mode variables render correctly when toggled in browser devtools

**Apple compliance (Spec 00 §11):**
- [ ] §11.5 — No hard-coded hex colours in component files; all reference CSS variables

---

#### ⬜ T-10-002 · Define typography scale

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P0 (blocking) |
| **Spec ref** | §3 — Typography |
| **Depends on** | T-10-001 |
| **Estimated effort** | S (< 1 hr) |
| **Files to create/modify** | `src/styles/globals.css` |

**What to build:**
Add CSS utility classes for the five typography roles from Spec 10 §3: `.text-title` (28 pt / semibold / 34 pt line height), `.text-heading` (20 pt / medium / 26 pt), `.text-body` (17 pt / regular / 24 pt), `.text-caption` (13 pt / regular / 18 pt), `.text-button` (17 pt / semibold / 22 pt). All use `font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif`. Ensure body text defaults to `.text-body`. All sizes must scale with Dynamic Type — use `rem` units with a base of `1rem = 17px`.

**Acceptance criteria:**
- [ ] Five typography utility classes exist in `globals.css`
- [ ] `body` element defaults to 17 pt / regular / 24 pt line height
- [ ] Text scales correctly at browser font sizes from 12px to 32px (simulating Dynamic Type)

**Apple compliance (Spec 00 §11):**
- [ ] §11.5 — Dynamic Type scaling verified at XS through Accessibility XXL

---

### Group: Components

---

#### ⬜ T-10-003 · VerdictCard component

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P0 (blocking) |
| **Spec ref** | §4.2 — Analyse Result; §5 — Component Inventory |
| **Depends on** | T-10-001, T-10-002 |
| **Estimated effort** | M (1–3 hr) |
| **Files to create/modify** | `src/components/VerdictCard.tsx` |

**What to build:**
Create `src/components/VerdictCard.tsx` replacing the existing `ScamWarningCard`. Props: `result: AgentResult`, `onShare: () => void`, `onDismiss: () => void`. Verdict heading uses `--safe`/`--suspicious`/`--scam` colour and auto-focuses on mount via ref. Card background uses `--safe-bg`/`--suspicious-bg`/`--scam-bg`, 20 px padding, 16 px radius, no border, no shadow. Confidence bar: 4 px tall, `--border` track, verdict-coloured fill. Reasoning bullets: `.text-body`, 24 pt line height. "Share" button hidden when verdict is `safe`; dismiss text changes to "Great!". Caption line at bottom: "Analysed on-device · {modelTier}".

**Acceptance criteria:**
- [ ] Heading auto-focused on mount (VoiceOver announces verdict first)
- [ ] Card uses `--scam-bg` background for scam verdict, no shadow, 16 px radius
- [ ] "Share" button hidden when verdict is `safe`
- [ ] Confidence bar is exactly 4 px tall with `--border` track colour
- [ ] Both buttons are 50 px tall, full-width, 12 px radius

**Apple compliance (Spec 00 §11):**
- [ ] §11.5 — Minimum 44 x 44 pt tap targets on both action buttons
- [ ] §11.5 — VoiceOver: heading receives focus on mount

---

#### ⬜ T-10-004 · StreamingText component

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P0 (blocking) |
| **Spec ref** | §4.2 — Streaming state; §6.3 — Loading States |
| **Depends on** | T-10-001 |
| **Estimated effort** | S (< 1 hr) |
| **Files to create/modify** | `src/components/StreamingText.tsx` |

**What to build:**
Create `src/components/StreamingText.tsx` replacing the existing `StreamingReasoningView`. Props: `tokens: string`, `isDone: boolean`. Renders tokens as plain text in a `div` with `aria-live="polite"`. Appends a blinking cursor (`|`) via CSS opacity animation (150 ms pulse) when `isDone` is false. Cursor hidden when `isDone` is true. Animation disabled when `prefers-reduced-motion: reduce`.

**Acceptance criteria:**
- [ ] `aria-live="polite"` attribute present on the text container
- [ ] Cursor visible while streaming, hidden when done
- [ ] Cursor animation uses opacity only, 150 ms duration
- [ ] With `prefers-reduced-motion: reduce`, cursor is static (no animation)

**Apple compliance (Spec 00 §11):**
- [ ] §11.5 — VoiceOver announces new text chunks without interrupting

---

#### ⬜ T-10-005 · ProgressRow component

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P1 (high) |
| **Spec ref** | §4.3 — Onboarding; §5 — Component Inventory |
| **Depends on** | T-10-001 |
| **Estimated effort** | S (< 1 hr) |
| **Files to create/modify** | `src/components/ProgressRow.tsx` |

**What to build:**
Create `src/components/ProgressRow.tsx` replacing the existing `ModelDownloadProgress`. Props: `label: string`, `progress: number` (0–1), `totalSize: string` (e.g. "1.8 GB"). Renders a single row: left-aligned model name (`.text-body`), right-aligned size (`.text-caption`, muted), and a 4 px progress bar below. Track colour `--border`, fill colour `--text`. Add `role="progressbar"`, `aria-valuenow`, `aria-valuemin`, `aria-valuemax`, and `aria-valuetext` (e.g. "Gemma E2B: 45% of 1.8 GB").

**Acceptance criteria:**
- [ ] Bar is exactly `--bar-height` (4 px) tall
- [ ] `aria-valuetext` includes model name, percentage, and total size
- [ ] Fill colour is `--text`, track colour is `--border`

**Apple compliance (Spec 00 §11):**
- [ ] §11.5 — VoiceOver reads progress via `aria-valuetext`

---

#### ⬜ T-10-006 · InputArea component

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P0 (blocking) |
| **Spec ref** | §4.1 — Home; §5 — Component Inventory |
| **Depends on** | T-10-001, T-10-002 |
| **Estimated effort** | S (< 1 hr) |
| **Files to create/modify** | `src/components/InputArea.tsx` |

**What to build:**
Create `src/components/InputArea.tsx`. Props: `value: string`, `onChange: (value: string) => void`, `onSubmit: () => void`, `placeholder?: string`, `disabled?: boolean`. Renders a `textarea` (120 px tall, 1 px `--border`, 12 px radius, 16 px padding, `.text-body` font) above a primary submit button ("Check this"). Button disabled when `value` is empty or `disabled` is true.

**Acceptance criteria:**
- [ ] Textarea is `--height-input` (120 px) tall
- [ ] Border uses `--border` colour, radius is `--radius-input` (12 px)
- [ ] Submit button is primary style: 50 px tall, full-width, 12 px radius
- [ ] Button disabled state has opacity 0.5

**Apple compliance (Spec 00 §11):**
- [ ] §11.5 — Textarea has accessible label via `aria-label` or visible `<label>`

---

#### ⬜ T-10-007 · ResultRow component

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P1 (high) |
| **Spec ref** | §4.1 — Home (Recent checks); §5 — Component Inventory |
| **Depends on** | T-10-001 |
| **Estimated effort** | S (< 1 hr) |
| **Files to create/modify** | `src/components/ResultRow.tsx` |

**What to build:**
Create `src/components/ResultRow.tsx`. Props: `input: string`, `verdict: ScamVerdict`, `onClick: () => void`. Renders a row (56 px tall, full-width tappable) with truncated input text (40 chars max, ellipsis) on the left and a verdict pill on the right. Pill uses verdict colour as text with a light tint background. No icons.

**Acceptance criteria:**
- [ ] Row height is `--height-row` (56 px)
- [ ] Input text truncated at 40 characters with ellipsis
- [ ] Verdict pill text colour matches `--safe`/`--suspicious`/`--scam`
- [ ] Entire row is tappable (button or link role)

**Apple compliance (Spec 00 §11):**
- [ ] §11.5 — Minimum 44 x 44 pt tap target

---

#### ⬜ T-10-008 · SettingsRow component

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P1 (high) |
| **Spec ref** | §4.4 — Settings; §5 — Component Inventory |
| **Depends on** | T-10-001 |
| **Estimated effort** | S (< 1 hr) |
| **Files to create/modify** | `src/components/SettingsRow.tsx` |

**What to build:**
Create `src/components/SettingsRow.tsx`. Props: `label: string`, `value?: string`, `showChevron?: boolean`, `onClick?: () => void`. Renders a row (56 px tall): label in `.text-caption` muted, value in `.text-body`, optional chevron `▸` in 13 pt muted right-aligned. Full-width tappable area when `onClick` provided.

**Acceptance criteria:**
- [ ] Row height is `--height-row` (56 px)
- [ ] Label is `.text-caption` in `--text-muted`
- [ ] Chevron `▸` shown only when `showChevron` is true
- [ ] Full-width tappable when `onClick` is provided

**Apple compliance (Spec 00 §11):**
- [ ] §11.5 — Minimum 44 x 44 pt tap target

---

### Group: Pages

---

#### ⬜ T-10-009 · Refactor Home page (`/`)

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P0 (blocking) |
| **Spec ref** | §4.1 — Home |
| **Depends on** | T-10-003, T-10-006, T-10-007 |
| **Estimated effort** | M (1–3 hr) |
| **Files to create/modify** | `src/app/page.tsx` |

**What to build:**
Refactor the Home page to match the Spec 10 §4.1 wireframe. Single-column layout with `--padding-page` horizontal padding. Centred "GemScan" title (`.text-title`), subtitle "What would you like me to check?" (`.text-body`, `--text-muted`). `InputArea` component for text input. Secondary "Scan image" button below. Hairline divider (`1px --border`). "Recent checks" section heading (`.text-heading`) with `ResultRow` list from `useGemScanStore().recentResults`. All spacing uses `--gap-section` between sections and `--gap-element` between related items.

**Acceptance criteria:**
- [ ] Title centred, 28 pt, `--text` colour
- [ ] InputArea textarea with placeholder text
- [ ] Primary "Check this" and secondary "Scan image" buttons present
- [ ] Recent checks list renders `ResultRow` for each recent result
- [ ] All spacing matches `--gap-section` (24 px) and `--gap-element` (12 px)

**Apple compliance (Spec 00 §11):**
- [ ] §11.5 — All buttons ≥ 44 x 44 pt

---

#### ⬜ T-10-010 · Refactor Analyse page (`/analyse`)

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P0 (blocking) |
| **Spec ref** | §4.2 — Analyse Result |
| **Depends on** | T-10-003, T-10-004 |
| **Estimated effort** | M (1–3 hr) |
| **Files to create/modify** | `src/app/analyse/page.tsx` |

**What to build:**
Refactor the Analyse page to match the Spec 10 §4.2 wireframe. "← Back" text link in top-left (17 pt, tappable, navigates to `/`). `StreamingText` component shown while inference is running. `VerdictCard` component shown once result is available. Caption "Analysed on-device · {tier}" in `.text-caption` centred below the card. No navigation bar, no toolbar.

**Acceptance criteria:**
- [ ] "← Back" is plain text in top-left, no icon chrome
- [ ] StreamingText shows during inference with blinking cursor
- [ ] VerdictCard displayed after result arrives
- [ ] Caption line present below card

**Apple compliance (Spec 00 §11):**
- [ ] §11.5 — "← Back" is ≥ 44 x 44 pt tap target

---

#### ⬜ T-10-011 · Refactor Onboarding page (`/onboarding`)

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P1 (high) |
| **Spec ref** | §4.3 — Onboarding |
| **Depends on** | T-10-005 |
| **Estimated effort** | M (1–3 hr) |
| **Files to create/modify** | `src/app/onboarding/page.tsx` |

**What to build:**
Refactor Onboarding to match the Spec 10 §4.3 wireframe. Single scroll page (no carousel). Three sections separated by hairline dividers: (1) Welcome heading + privacy description, (2) Three `ProgressRow` components (DistilBERT 5 MB, E2B 1.8 GB, E4B 3.2 GB), (3) consent caption + "Download and start" primary button. Button disabled during download, text changes to "Downloading...". No spinner.

**Acceptance criteria:**
- [ ] No carousel, no pagination dots — single scroll
- [ ] Three `ProgressRow` instances with correct labels and sizes
- [ ] Button text changes to "Downloading..." while in progress
- [ ] Consent caption uses `.text-caption`

**Apple compliance (Spec 00 §11):**
- [ ] N/A — no native code changes

---

#### ⬜ T-10-012 · Refactor Settings page (`/settings`)

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P1 (high) |
| **Spec ref** | §4.4 — Settings |
| **Depends on** | T-10-008 |
| **Estimated effort** | M (1–3 hr) |
| **Files to create/modify** | `src/app/settings/page.tsx` |

**What to build:**
Refactor Settings to match the Spec 10 §4.4 wireframe. "← Back" top-left. "Settings" heading (`.text-title`). Flat list using `SettingsRow` components: Language row (value + chevron), Screening mode radio group, Guardian mode row (trusted contact + chevron), About section (version + caption). Sections separated by hairline dividers. No grouped table views, no icons.

**Acceptance criteria:**
- [ ] Language row shows current language with chevron
- [ ] Screening mode renders as radio group (3 options)
- [ ] Version displayed in `.text-caption`
- [ ] All rows are 56 px tall, full-width tappable

**Apple compliance (Spec 00 §11):**
- [ ] §11.5 — All rows ≥ 44 x 44 pt tap targets

---

#### ⬜ T-10-013 · Refactor Guardian Setup page (`/guardian/setup`)

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P1 (high) |
| **Spec ref** | §4.5 — Guardian Setup |
| **Depends on** | T-10-001, T-10-002 |
| **Estimated effort** | M (1–3 hr) |
| **Files to create/modify** | `src/app/guardian/setup/page.tsx` |

**What to build:**
Refactor Guardian Setup to match the Spec 10 §4.5 wireframe. "← Back" top-left. "Guardian Mode" heading. Explanation paragraph (`.text-body`). "Trusted contact" label with inline search input field. Contact results as flat list with masked phone/email. "Turn on Guardian" primary button.

**Acceptance criteria:**
- [ ] Contact search input present with placeholder "Search contacts..."
- [ ] Contact display uses masked format (`+1 (***) ***-2671`)
- [ ] Primary button is 50 px tall, full-width
- [ ] Layout matches single-column, `--padding-page` spacing

**Apple compliance (Spec 00 §11):**
- [ ] §11.3 — No raw contact data displayed; phone/email masked

---

### Group: Button Styles

---

#### ⬜ T-10-014 · Implement primary and secondary button styles

| Field | Value |
|---|---|
| **Type** | IMPLEMENT |
| **Priority** | P0 (blocking) |
| **Spec ref** | §6.1 — Buttons |
| **Depends on** | T-10-001 |
| **Estimated effort** | S (< 1 hr) |
| **Files to create/modify** | `src/styles/globals.css` |

**What to build:**
Add CSS classes `.btn-primary` and `.btn-secondary` matching Spec 10 §6.1. Primary: `--text` background, white text, 50 px tall, 12 px radius, full-width, `.text-button` font. Secondary: transparent background, 1 px `--border`, `--text` colour, same dimensions. Both: pressed state `opacity: 0.7` via `:active`, disabled state `opacity: 0.5`. No hover effects. Dark mode: primary inverts to `--surface` background with `--text` text.

**Acceptance criteria:**
- [ ] `.btn-primary` is 50 px tall with `--text` background on light mode
- [ ] `.btn-secondary` has transparent background with 1 px `--border`
- [ ] `:active` state shows `opacity: 0.7`
- [ ] Disabled state shows `opacity: 0.5`
- [ ] Dark mode inverts primary button colours correctly

**Apple compliance (Spec 00 §11):**
- [ ] §11.5 — Both buttons ≥ 44 x 44 pt (50 px exceeds minimum)

---

### Group: Tests

---

#### ⬜ T-10-015 · VerdictCard component tests

| Field | Value |
|---|---|
| **Type** | TEST |
| **Priority** | P1 (high) |
| **Spec ref** | §4.2, §8 — Accessibility Checklist |
| **Depends on** | T-10-003 |
| **Estimated effort** | M (1–3 hr) |
| **Files to create/modify** | `src/components/__tests__/VerdictCard.test.tsx` |

**What to build:**
Vitest + @testing-library/react tests for VerdictCard: (1) renders correct heading text for each verdict, (2) heading receives focus on mount, (3) confidence bar has correct `aria-valuenow`, (4) "Share" button hidden for safe verdict, (5) dismiss button text is "Great!" for safe, "I'll be careful" for scam/suspicious, (6) dark mode class application via CSS variable check.

**Acceptance criteria:**
- [ ] All 6 test cases pass
- [ ] Focus-on-mount test verifies `document.activeElement` is the heading

---

#### ⬜ T-10-016 · StreamingText and ProgressRow tests

| Field | Value |
|---|---|
| **Type** | TEST |
| **Priority** | P1 (high) |
| **Spec ref** | §4.2, §4.3, §8 |
| **Depends on** | T-10-004, T-10-005 |
| **Estimated effort** | S (< 1 hr) |
| **Files to create/modify** | `src/components/__tests__/StreamingText.test.tsx`, `src/components/__tests__/ProgressRow.test.tsx` |

**What to build:**
StreamingText tests: (1) renders tokens as text, (2) cursor visible when `isDone` is false, (3) cursor hidden when `isDone` is true, (4) `aria-live="polite"` present. ProgressRow tests: (1) renders label and size, (2) bar fill width matches progress prop, (3) `aria-valuetext` includes label, percentage, and size.

**Acceptance criteria:**
- [ ] All 7 test cases pass
- [ ] ARIA attributes verified via `getByRole` queries

---

#### ⬜ T-10-017 · InputArea, ResultRow, SettingsRow tests

| Field | Value |
|---|---|
| **Type** | TEST |
| **Priority** | P1 (high) |
| **Spec ref** | §4.1, §4.4, §8 |
| **Depends on** | T-10-006, T-10-007, T-10-008 |
| **Estimated effort** | S (< 1 hr) |
| **Files to create/modify** | `src/components/__tests__/InputArea.test.tsx`, `src/components/__tests__/ResultRow.test.tsx`, `src/components/__tests__/SettingsRow.test.tsx` |

**What to build:**
InputArea tests: (1) renders textarea and button, (2) button disabled when input empty, (3) calls onSubmit on click. ResultRow tests: (1) truncates text at 40 chars, (2) shows correct verdict pill colour. SettingsRow tests: (1) renders label and value, (2) chevron shown when `showChevron` is true, (3) row is clickable when `onClick` provided.

**Acceptance criteria:**
- [ ] All 8 test cases pass

---

### Group: Validation

---

#### ⬜ T-10-018 · Accessibility audit for all screens

| Field | Value |
|---|---|
| **Type** | VALIDATE |
| **Priority** | P0 (blocking) |
| **Spec ref** | §8 — Accessibility Checklist |
| **Depends on** | T-10-009, T-10-010, T-10-011, T-10-012, T-10-013 |
| **Estimated effort** | M (1–3 hr) |
| **Files to create/modify** | `docs/wcag-checklist.md` (update) |

**What to build:**
Run the full accessibility checklist from Spec 10 §8 against all five screens. Verify: (1) all interactive elements ≥ 44 x 44 pt, (2) VoiceOver reads verdict heading first on `/analyse`, (3) `aria-live="polite"` on streaming text, (4) `aria-valuenow`/`aria-valuetext` on progress bars, (5) no colour-only indicators, (6) Dynamic Type scaling from XS to Accessibility XXL without truncation, (7) dark mode renders correctly via CSS variables, (8) `prefers-reduced-motion: reduce` disables cursor animation. Update `docs/wcag-checklist.md` with evidence for each check.

**Acceptance criteria:**
- [ ] All 8 accessibility checklist items verified and documented
- [ ] `docs/wcag-checklist.md` updated with Spec 10 evidence
- [ ] No hard-coded hex colours found in any component file

**Apple compliance (Spec 00 §11):**
- [ ] §11.5 — Full HIG compliance verified across all five screens
