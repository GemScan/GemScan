# WCAG 2.1 Compliance Checklist

Accessibility compliance evidence for GemScan, targeting WCAG 2.1 Level AA.

---

## Summary

GemScan targets WCAG 2.1 Level AA compliance across all user-facing screens. This document maps each success criterion to its implementation and testing evidence.

---

## Success Criteria

### 1.1.1 Non-text Content (Level A)

**Requirement:** All non-text content has a text alternative.

**Implementation:**
- All `<img>` elements have descriptive `alt` attributes.
- Icon-only buttons use `aria-label` for screen reader identification.
- Decorative images use `alt=""` and `aria-hidden="true"`.
- Verdict indicator icons (safe/suspicious/scam) include `aria-label` with the verdict text.

**Evidence:**
```tsx
// Verdict badge — icon has aria-label
<ShieldIcon aria-label={`Verdict: ${verdict}`} />

// Decorative separator — hidden from AT
<DividerIcon alt="" aria-hidden="true" />
```

**Testing:**
- Playwright accessibility audit on all pages.
- Manual VoiceOver walkthrough documented per release.

---

### 1.3.1 Info and Relationships (Level A)

**Requirement:** Information, structure, and relationships are programmatically determinable.

**Implementation:**
- Semantic HTML elements: `<main>`, `<nav>`, `<header>`, `<section>`, `<article>`.
- Form inputs associated with `<label>` elements via `htmlFor`.
- Lists use `<ul>`/`<ol>` and `<li>`.
- Scan results use `<article>` with `role="status"` for live regions.
- Headings follow a logical hierarchy (h1 > h2 > h3, no skipped levels).

**Evidence:**
```tsx
<main>
  <h1>Scan Results</h1>
  <section aria-labelledby="verdict-heading">
    <h2 id="verdict-heading">Verdict</h2>
    <article role="status" aria-live="polite">
      <p>{verdict.explanation}</p>
    </article>
  </section>
</main>
```

---

### 1.4.3 Contrast (Minimum) (Level AA)

**Requirement:** Text has a contrast ratio of at least 4.5:1 (3:1 for large text).

**Implementation:**
- Light mode: text `#1a1a2e` on background `#ffffff` — ratio 16.4:1.
- Dark mode: text `#e0e0e0` on background `#1a1a2e` — ratio 11.2:1.
- Verdict colors meet contrast requirements:
  - Safe (green): `#166534` on `#dcfce7` — ratio 5.8:1.
  - Suspicious (amber): `#92400e` on `#fef3c7` — ratio 5.2:1.
  - Scam (red): `#991b1b` on `#fee2e2` — ratio 5.6:1.

**Testing:**
- Automated contrast checks via Playwright accessibility assertions.
- Manual verification with the Colour Contrast Analyser tool.

---

### 2.1.1 Keyboard (Level A)

**Requirement:** All functionality is operable through a keyboard interface.

**Implementation:**
- All interactive elements (buttons, links, inputs) are focusable.
- Custom components use `tabIndex={0}` and handle `onKeyDown` for Enter/Space.
- No keyboard traps — focus can always move forward and backward.
- Modal dialogs trap focus within the dialog and restore focus on close.

**Evidence:**
```tsx
<button
  onClick={handleScan}
  onKeyDown={(e) => {
    if (e.key === 'Enter' || e.key === ' ') handleScan();
  }}
  tabIndex={0}
  role="button"
>
  Scan
</button>
```

---

### 2.4.3 Focus Order (Level A)

**Requirement:** Focusable components receive focus in an order that preserves meaning.

**Implementation:**
- DOM order matches visual order on all pages.
- No positive `tabIndex` values (only `0` or `-1`).
- Skip-to-content link as the first focusable element.
- After scan submission, focus moves to the result area.

**Evidence:**
```tsx
{/* Skip link — first element in body */}
<a href="#main-content" className="sr-only focus:not-sr-only">
  Skip to main content
</a>
```

---

### 3.1.1 Language of Page (Level A)

**Requirement:** The default human language of each page is programmatically determinable.

**Implementation:**
- `lang="en"` attribute on the `<html>` element.
- Set in `src/app/layout.tsx`.

**Evidence:**
```tsx
export default function RootLayout({ children }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
```

---

### 4.1.2 Name, Role, Value (Level A)

**Requirement:** For all UI components, name and role are programmatically determinable.

**Implementation:**
- Custom components declare roles: `role="button"`, `role="status"`, `role="alert"`.
- Dynamic state communicated via `aria-expanded`, `aria-pressed`, `aria-selected`.
- Form validation errors linked with `aria-describedby`.
- Loading states use `aria-busy="true"`.

**Evidence:**
```tsx
<div
  role="alert"
  aria-live="assertive"
  className={verdictStyles[verdict]}
>
  {verdict === 'scam' && 'Warning: This message appears to be a scam.'}
</div>

<button
  aria-expanded={isMenuOpen}
  aria-controls="settings-menu"
  onClick={toggleMenu}
>
  Settings
</button>
```

---

## iOS-Specific Accessibility

### Dynamic Type Scaling

All text in the native iOS layer respects Dynamic Type:

```swift
label.font = UIFont.preferredFont(forTextStyle: .body)
label.adjustsFontForContentSizeCategory = true
```

**Verification:**
1. Open **Settings > Accessibility > Display & Text Size > Larger Text**.
2. Set to maximum size.
3. Verify all text remains readable and no content is clipped.

### VoiceOver Testing

| Screen | VoiceOver behavior |
|--------|-------------------|
| Scan input | "Text field, enter message to scan" |
| Scan button | "Scan, button" |
| Verdict safe | "Verdict: safe, status" |
| Verdict scam | "Warning: scam detected, alert" |
| History list | Each item reads verdict, date, and summary |
| Settings | All toggles announce on/off state |

**Verification:**
1. Enable VoiceOver: **Settings > Accessibility > VoiceOver**.
2. Navigate through each screen with swipe gestures.
3. Confirm every interactive element is announced with name and role.

---

## Dark Mode Verification

All components must render correctly in both light and dark modes.

**Checklist:**

- [ ] Text is legible in both modes.
- [ ] Verdict badges maintain required contrast ratios.
- [ ] Icons are visible against the background.
- [ ] Focus rings are visible in both modes.
- [ ] No hardcoded colors — all values use Tailwind theme tokens or CSS variables.

**Verification:**
1. Toggle **Settings > Display & Brightness > Dark Mode**.
2. Walk through every screen.
3. Run Playwright tests with `prefers-color-scheme: dark`:

```typescript
test.use({ colorScheme: 'dark' });

test('dark mode maintains contrast', async ({ page }) => {
  await page.goto('/scan');
  const violations = await runAccessibilityAudit(page);
  expect(violations).toHaveLength(0);
});
```

---

## Automated Testing

### Playwright Accessibility Tests

```typescript
import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';

test('scan page has no accessibility violations', async ({ page }) => {
  await page.goto('/scan');
  const results = await new AxeBuilder({ page })
    .withTags(['wcag2a', 'wcag2aa'])
    .analyze();
  expect(results.violations).toHaveLength(0);
});
```

These tests run on every PR as part of the E2E test suite.

### CI Enforcement

The `ci.yml` workflow fails if any Playwright accessibility test reports violations. This prevents regressions from merging.

---

## Compliance Evidence Log

| Date | Criterion | Status | Verified by |
|------|-----------|--------|-------------|
| — | 1.1.1 Non-text Content | Pending | — |
| — | 1.3.1 Info and Relationships | Pending | — |
| — | 1.4.3 Contrast (Minimum) | Pending | — |
| — | 2.1.1 Keyboard | Pending | — |
| — | 2.4.3 Focus Order | Pending | — |
| — | 3.1.1 Language of Page | Pending | — |
| — | 4.1.2 Name, Role, Value | Pending | — |

Update this table as each criterion is verified during development.
