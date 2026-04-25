# Spec 10 — Minimalist GUI for iOS

This specification defines a stripped-down, production-ready visual design for GemScan on iOS. It replaces the functional wireframes in Spec 06 with a cohesive minimalist interface optimised for one-handed use, legibility at arm's length, and calm presentation of safety-critical information.

---

## 1. Design Philosophy

| Principle | Rule |
| --- | --- |
| Minimal chrome | No tab bars, no hamburger menus, no toolbars. Navigation is linear: forward and back. |
| Single-column | Every screen is a single vertical stack. No grids, no side panels. |
| Large type | Body text starts at 17 pt (iOS Dynamic Type `.body`). Headings at 28 pt. |
| Generous whitespace | Minimum 24 pt vertical spacing between sections. 20 pt horizontal padding. |
| Muted palette | White/off-white backgrounds, dark text, colour used only for verdict indicators. |
| No decorations | No gradients, no shadows, no border radii larger than 16 pt, no illustrations. |
| Motion-free | No animations by default. Skeleton loaders use opacity fade only (150 ms). |

---

## 2. Colour System

Three semantic verdict colours plus neutral surface tones. All colours meet WCAG 2.1 AA contrast (4.5:1 minimum) on their respective backgrounds.

```css
:root {
  /* Verdict colours (foreground on white) */
  --safe:        #1A7F37;   /* green — 5.2:1 on white */
  --suspicious:  #9A6700;   /* amber — 4.6:1 on white */
  --scam:        #CF222E;   /* red   — 4.8:1 on white */

  /* Verdict tint backgrounds (light fills behind cards) */
  --safe-bg:        #DAFBE1;
  --suspicious-bg:  #FFF8C5;
  --scam-bg:        #FFEBE9;

  /* Neutral surface */
  --surface:     #FFFFFF;
  --surface-alt: #F6F8FA;   /* alternating sections */
  --text:        #1F2328;
  --text-muted:  #656D76;
  --border:      #D0D7DE;
}

@media (prefers-color-scheme: dark) {
  :root {
    --safe:        #3FB950;
    --suspicious:  #D29922;
    --scam:        #F85149;

    --safe-bg:        #0D1117;
    --suspicious-bg:  #0D1117;
    --scam-bg:        #0D1117;

    --surface:     #0D1117;
    --surface-alt: #161B22;
    --text:        #E6EDF3;
    --text-muted:  #8B949E;
    --border:      #30363D;
  }
}
```

---

## 3. Typography

| Role | Font | Size | Weight | Line height |
| --- | --- | --- | --- | --- |
| Page title | SF Pro Display | 28 pt | Semibold (600) | 34 pt |
| Section heading | SF Pro Text | 20 pt | Medium (500) | 26 pt |
| Body | SF Pro Text | 17 pt | Regular (400) | 24 pt |
| Caption | SF Pro Text | 13 pt | Regular (400) | 18 pt |
| Button label | SF Pro Text | 17 pt | Semibold (600) | 22 pt |

All sizes scale with Dynamic Type. Use `-apple-system` in CSS to inherit the system font.

---

## 4. Screen Specifications

### 4.1 Home (`/`)

The entire screen is a single call-to-action.

```
┌──────────────────────────────┐
│                              │
│                              │
│          GemScan             │  ← 28 pt, centred, text colour
│                              │
│    What would you like       │  ← 17 pt, muted, centred
│    me to check?              │
│                              │
│                              │
│  ┌──────────────────────┐    │
│  │                      │    │  ← Textarea, 120 pt tall
│  │  Paste a message,    │    │    placeholder in muted text
│  │  URL, or describe    │    │
│  │  what happened...    │    │
│  │                      │    │
│  └──────────────────────┘    │
│                              │
│  ┌──────────────────────┐    │
│  │    Check this        │    │  ← Primary button, 50 pt tall
│  └──────────────────────┘    │    filled, rounded 12 pt
│                              │
│  ┌──────────────────────┐    │
│  │   📷  Scan image     │    │  ← Secondary button, outline
│  └──────────────────────┘    │
│                              │
│  ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─   │  ← Hairline divider
│                              │
│  Recent checks               │  ← Section heading, left-aligned
│                              │
│  "Your account is..."  Scam  │  ← Recent result row
│  "Hi, your package..." Safe  │
│  "Congratulations!..." Scam  │
│                              │
└──────────────────────────────┘
```

**Component structure:**

- App title: static text, no logo image.
- Textarea: bordered, 1 px `--border`, 12 pt radius, 16 pt inner padding.
- Primary button: `--text` background on light, `--surface` text. Inverts in dark mode.
- Secondary button: transparent background, 1 px `--border` outline.
- Recent checks: a flat list. Each row shows truncated input (40 chars max) and a verdict pill.

### 4.2 Analyse Result (`/analyse`)

Appears after the model produces a verdict. One card, one or two buttons.

```
┌──────────────────────────────┐
│  ←  Back                     │  ← Tappable text, no icon chrome
│                              │
│  ┌ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┐ │
│  │                         │ │
│  │   ✕  This looks like    │ │  ← Verdict heading, 28 pt
│  │      a scam             │ │    colour = --scam
│  │                         │ │
│  │   87% confident         │ │  ← 17 pt, muted
│  │   ━━━━━━━━━━━░░░░       │ │  ← Progress bar, 4 pt tall
│  │                         │ │
│  │   • Sender is not in    │ │  ← Reasoning bullets
│  │     your contacts.      │ │    17 pt, 24 pt line height
│  │                         │ │
│  │   • Message asks you    │ │
│  │     to click a link     │ │
│  │     urgently.           │ │
│  │                         │ │
│  │   • The link goes to    │ │
│  │     a website made      │ │
│  │     3 days ago.         │ │
│  │                         │ │
│  └ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘ │
│                              │
│  ┌──────────────────────┐    │
│  │  Share with contact  │    │  ← Primary button (scam/suspicious only)
│  └──────────────────────┘    │
│                              │
│  ┌──────────────────────┐    │
│  │  I'll be careful     │    │  ← Secondary button
│  └──────────────────────┘    │
│                              │
│  Analysed on-device · E2B    │  ← Caption, centred, muted
│                              │
└──────────────────────────────┘
```

**Verdict card styling:**

- Background: `--scam-bg` / `--suspicious-bg` / `--safe-bg` depending on verdict.
- No border. No shadow. Just the tinted background with 20 pt padding and 16 pt radius.
- Heading auto-focused on mount for VoiceOver.
- If verdict is `safe`: hide the "Share" button, change dismiss to "Great!".

**Streaming state:**

While tokens stream in, show the verdict card frame with reasoning bullets populating line by line. A blinking cursor (opacity pulse, 150 ms) appears at the end of the last token. The cursor respects `prefers-reduced-motion`.

### 4.3 Onboarding (`/onboarding`)

Shown only on first launch. Three vertical sections, no carousel, no pagination dots.

```
┌──────────────────────────────┐
│                              │
│  Welcome to GemScan          │  ← 28 pt heading
│                              │
│  GemScan checks messages     │  ← 17 pt body, max 3 lines
│  and calls for scams.        │
│  Everything stays on         │
│  your phone.                 │
│                              │
│  ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─   │
│                              │
│  Downloading models          │  ← Section heading
│                              │
│  DistilBERT     ━━━━━ 5 MB  │  ← Progress rows
│  Gemma E2B   ━━━░░ 1.8 GB   │
│  Gemma E4B   ░░░░░ 3.2 GB   │
│                              │
│  ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─   │
│                              │
│  By continuing, you agree    │  ← 13 pt caption
│  that GemScan processes      │
│  content locally only.       │
│                              │
│  ┌──────────────────────┐    │
│  │  Download and start  │    │  ← Primary button
│  └──────────────────────┘    │
│                              │
└──────────────────────────────┘
```

- Progress bars: 4 pt tall, `--border` track, `--text` fill.
- Model labels: left-aligned name, right-aligned size in caption text.
- Button disabled while download in progress; text changes to "Downloading..." with no spinner.

### 4.4 Settings (`/settings`)

A flat list of options. No grouped table views.

```
┌──────────────────────────────┐
│  ←  Back                     │
│                              │
│  Settings                    │  ← 28 pt heading
│                              │
│  Language                    │  ← Label, 13 pt muted
│  English                  ▸  │  ← Value + chevron, tappable row
│                              │
│  ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─   │
│                              │
│  Screening mode              │
│  ○ Passive                   │  ← Radio group
│  ● Active                    │
│  ○ Guardian                  │
│                              │
│  ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─   │
│                              │
│  Guardian mode               │
│  Trusted contact: None    ▸  │
│                              │
│  ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─   │
│                              │
│  About                       │
│  Version 1.0.0               │  ← Caption
│  All processing on-device    │
│                              │
└──────────────────────────────┘
```

- Rows: 56 pt minimum height, full-width tappable area.
- No icons. Labels are plain text.
- Chevron `▸` is 13 pt, muted colour, right-aligned.

### 4.5 Guardian Setup (`/guardian/setup`)

```
┌──────────────────────────────┐
│  ←  Back                     │
│                              │
│  Guardian Mode               │  ← 28 pt heading
│                              │
│  If GemScan detects a        │  ← 17 pt body
│  high-risk scam, it will     │
│  alert your trusted          │
│  contact.                    │
│                              │
│  Trusted contact             │  ← Label
│  ┌──────────────────────┐    │
│  │  Search contacts...  │    │  ← Text input
│  └──────────────────────┘    │
│                              │
│  ┌──────────────────────┐    │
│  │  Turn on Guardian    │    │  ← Primary button
│  └──────────────────────┘    │
│                              │
└──────────────────────────────┘
```

- Contact picker: inline search field. Results appear below as a flat list.
- Contact display: masked phone (`+1 (***) ***-2671`), masked email (`a***@domain`).

---

## 5. Component Inventory

Six components total. No component library. No third-party UI package.

| Component | File | Purpose |
| --- | --- | --- |
| `VerdictCard` | `src/components/VerdictCard.tsx` | Verdict heading + confidence bar + reasoning + actions |
| `StreamingText` | `src/components/StreamingText.tsx` | Token-by-token text reveal with cursor |
| `ProgressRow` | `src/components/ProgressRow.tsx` | Single model download progress bar |
| `InputArea` | `src/components/InputArea.tsx` | Textarea + submit button pair |
| `ResultRow` | `src/components/ResultRow.tsx` | Truncated input + verdict pill for recent list |
| `SettingsRow` | `src/components/SettingsRow.tsx` | Label + value + optional chevron |

---

## 6. Interaction Patterns

### 6.1 Buttons

Two styles only:

- **Primary**: filled background (`--text` on light, `--surface` on dark), white text, 50 pt tall, 12 pt radius, full-width.
- **Secondary**: transparent background, 1 px `--border`, `--text` colour, 50 pt tall, 12 pt radius, full-width.

Both have a pressed state: opacity 0.7. No hover effects (touch device).

### 6.2 Navigation

- **Back**: plain text "← Back" in the top-left, 17 pt. No navigation bar.
- **Forward**: always via a button press, never via swipe gestures.
- History is a simple stack: Home → Analyse → (back to Home). Settings is a side path.

### 6.3 Loading States

- **Inference running**: the `StreamingText` component shows tokens appearing. No spinner, no skeleton.
- **Model downloading**: `ProgressRow` bars fill left to right. Text updates with downloaded MB.
- **Page loading**: blank white screen. No splash, no skeleton. Content appears when ready.

### 6.4 Error States

- Errors never show technical details.
- On any failure, display the verdict card with verdict `suspicious`, confidence `0%`, and a single reasoning bullet: "Something went wrong. For your safety, this has been marked as suspicious."
- A "Try again" secondary button resets to the home screen.

---

## 7. Spacing and Layout Constants

```css
:root {
  --padding-page:    20px;     /* horizontal page padding */
  --gap-section:     24px;     /* vertical gap between sections */
  --gap-element:     12px;     /* vertical gap between related elements */
  --radius-card:     16px;     /* verdict card */
  --radius-button:   12px;
  --radius-input:    12px;
  --height-button:   50px;
  --height-row:      56px;     /* settings rows, recent result rows */
  --height-input:    120px;    /* textarea */
  --bar-height:      4px;      /* progress and confidence bars */
}
```

---

## 8. Accessibility Checklist

Every screen must satisfy these before shipping:

- [ ] All interactive elements ≥ 44 x 44 pt tap target
- [ ] VoiceOver reads verdict heading first on `/analyse`
- [ ] `aria-live="polite"` on streaming text region
- [ ] `aria-valuenow` / `aria-valuetext` on all progress bars
- [ ] No colour used as the sole indicator — verdict label text always accompanies colour
- [ ] All text scales from Dynamic Type XS through Accessibility XXL without truncation
- [ ] Dark mode renders correctly using CSS variables (no hard-coded hex)
- [ ] `prefers-reduced-motion: reduce` disables the cursor blink

---

## 9. What This Spec Excludes

- **Guardian invite QR code** — deferred to Cycle 2; the setup flow uses contact search only.
- **Debug overlay** — dev-only, not part of the production GUI.
- **Onboarding carousel** — replaced by a single scroll page.
- **Tab bar / bottom navigation** — not needed; the app has only 3 user-reachable screens (Home, Settings, Guardian Setup) plus the analysis result.
- **Custom icons / illustrations** — text-only UI. The app icon is handled by Xcode asset catalogue, not this spec.
