# Minimalist GUI — Developer Verification Guide

How to verify the M10 minimalist GUI implementation matches Spec 10.

---

## Quick Check

```bash
./scripts/build-and-test.sh --web
```

This runs all checks: TypeScript, ESLint, Prettier, 175 tests (19 files), 93% coverage, and Next.js static export (7 pages).

---

## Component Tests

Six new components have dedicated test files:

| Component | Test file | Tests |
| --- | --- | --- |
| VerdictCard | `src/components/__tests__/VerdictCard.test.tsx` | 11 tests: headings, focus-on-mount, ARIA, button visibility |
| StreamingText | `src/components/__tests__/StreamingText.test.tsx` | 4 tests: tokens, cursor, aria-live |
| ProgressRow | `src/components/__tests__/ProgressRow.test.tsx` | 4 tests: label, progressbar role, aria-valuetext |
| InputArea | `src/components/__tests__/InputArea.test.tsx` | 4 tests: textarea, disabled state, submit |
| ResultRow | `src/components/__tests__/ResultRow.test.tsx` | 4 tests: truncation, verdict pill, click |
| SettingsRow | `src/components/__tests__/SettingsRow.test.tsx` | 6 tests: label, chevron, click, children |

Run just the component tests:

```bash
npx vitest run src/components/__tests__/
```

---

## Design Token Verification

All design tokens are in `src/styles/globals.css`. To verify:

### Colour System (Spec 10 §2)

Open browser devtools on any page and inspect `:root`:

```
--safe: #1a7f37         (green, 5.2:1 contrast on white)
--suspicious: #9a6700   (amber, 4.6:1 contrast on white)
--scam: #cf222e         (red, 4.8:1 contrast on white)
--safe-bg: #dafbe1
--suspicious-bg: #fff8c5
--scam-bg: #ffebe9
--surface: #ffffff
--surface-alt: #f6f8fa
--text: #1f2328
--text-muted: #656d76
--border: #d0d7de
```

Toggle dark mode in devtools (Rendering > Emulate CSS media feature `prefers-color-scheme: dark`) and verify all variables update.

### Typography Scale (Spec 10 §3)

Inspect elements and verify:

- `.text-title`: 28px (1.647rem), weight 600, line-height 1.214
- `.text-heading`: 20px (1.176rem), weight 500, line-height 1.3
- `.text-body`: 17px (1rem), weight 400, line-height 1.412
- `.text-caption`: 13px (0.765rem), weight 400, line-height 1.385
- `.text-button`: 17px (1rem), weight 600, line-height 1.294

### Spacing Constants (Spec 10 §7)

```
--padding-page: 20px
--gap-section: 24px
--gap-element: 12px
--radius-card: 16px
--radius-button: 12px
--radius-input: 12px
--height-button: 50px
--height-row: 56px
--height-input: 120px
--bar-height: 4px
```

---

## Page-by-Page Verification

### Home (`/`)

1. `npm run dev` and open `http://localhost:3000`
2. Verify:
   - [ ] "GemScan" title centred, 28px
   - [ ] Subtitle in muted colour
   - [ ] Textarea 120px tall with placeholder
   - [ ] "Check this" primary button (50px tall, dark fill)
   - [ ] "Scan image" secondary button (outline)
   - [ ] Hairline divider
   - [ ] "Recent checks" heading appears after submitting at least one check

### Analyse (`/analyse`)

1. Enter text on Home and click "Check this"
2. Verify:
   - [ ] "← Back" plain text in top-left
   - [ ] Streaming cursor appears while analysing (blinks at 150ms)
   - [ ] Verdict card appears with tinted background (no shadow)
   - [ ] Confidence bar is 4px tall
   - [ ] Reasoning bullets in 17px body text
   - [ ] "Share with contact" button visible for scam/suspicious, hidden for safe
   - [ ] Caption "Analysed on-device · E2B" centred below

### Onboarding (`/onboarding`)

1. Navigate to `/onboarding`
2. Verify:
   - [ ] Single scroll page (no carousel)
   - [ ] Three progress rows: DistilBERT (5 MB), Gemma E2B (1.8 GB), Gemma E4B (3.2 GB)
   - [ ] "Download and start" button changes to "Downloading..." when active
   - [ ] Consent caption in 13px text

### Settings (`/settings`)

1. Navigate to `/settings`
2. Verify:
   - [ ] Language row with chevron
   - [ ] Screening mode radio group (3 options)
   - [ ] Guardian mode row with chevron
   - [ ] All rows are 56px tall
   - [ ] Version number in caption text

### Guardian Setup (`/guardian/setup`)

1. Navigate to `/guardian/setup`
2. Verify:
   - [ ] Explanation paragraph
   - [ ] Contact search input with placeholder
   - [ ] "Turn on Guardian" primary button

---

## Accessibility Checklist (Spec 10 §8)

- [ ] **Tap targets**: all buttons ≥ 44x44px — verified by CSS rule in globals.css
- [ ] **VoiceOver focus**: verdict heading auto-focused on mount — verified by VerdictCard test "heading receives focus on mount"
- [ ] **aria-live**: streaming text has `aria-live="polite"` — verified by StreamingText test
- [ ] **Progress bars**: `aria-valuenow` + `aria-valuetext` present — verified by ProgressRow test
- [ ] **No colour-only indicators**: all verdicts have text labels ("Looks safe", "Be careful", "This looks like a scam")
- [ ] **Dynamic Type**: all text uses `rem` units (base 17px) — scales with browser font size
- [ ] **Dark mode**: all colours use CSS variables — toggle in devtools to verify
- [ ] **Reduced motion**: cursor animation disabled — verified by `@media (prefers-reduced-motion: reduce)` in globals.css

---

## No Hard-Coded Colours

Verify no hex colours in component files:

```bash
grep -rn '#[0-9a-fA-F]\{3,8\}' src/components/ --include='*.tsx'
```

This should return zero results. All colours reference CSS variables via inline styles.
