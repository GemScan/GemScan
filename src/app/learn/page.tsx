'use client'

import { scamTopics } from './scamTopics'

/// Browsable index of common scam patterns. Lives at `/learn` and is the
/// 2nd tab in the bottom bar. The UI is a vertical list of `<details>`
/// accordions — native HTML, so screen readers announce expand/collapse
/// without us writing any aria state and each card is independently
/// expandable without JS. Tap a card to expand it inline; tap again to
/// collapse. No master/detail navigation, no separate routes — keeps the
/// feature self-contained and deep-linkable via `/learn` alone.
///
/// Content lives in `./scamTopics.ts` so the rendering layer here stays
/// small and so adding a new scam type is a one-object edit.
export default function LearnPage() {
  return (
    <main className="page">
      <h1 className="text-title" style={{ color: 'var(--text)' }}>
        Learn
      </h1>
      <p className="text-body" style={{ color: 'var(--text-muted)' }}>
        Common scam patterns to recognise before you click, reply, or pay.
      </p>

      <div className="page-scroll" style={{ gap: 'var(--gap-element)' }}>
        {scamTopics.map((topic) => (
          <ScamCard key={topic.id} topic={topic} />
        ))}

        <p
          className="text-caption"
          style={{ color: 'var(--text-muted)', marginTop: 8, textAlign: 'center' }}
        >
          Not sure about a specific message? Tap <strong>Analyze</strong> to check it on-device.
        </p>
      </div>
    </main>
  )
}

interface ScamCardProps {
  topic: (typeof scamTopics)[number]
}

function ScamCard({ topic }: ScamCardProps) {
  return (
    <details
      style={{
        backgroundColor: 'var(--surface-alt)',
        border: '1px solid var(--border)',
        borderRadius: 'var(--radius-card)',
        padding: 16,
      }}
    >
      <summary
        style={{
          // `list-style: none` strips the default disclosure triangle
          // (rendered separately on the right via `::after` on the inner
          // span). `cursor: pointer` so the whole row reads as tappable.
          listStyle: 'none',
          cursor: 'pointer',
          display: 'flex',
          alignItems: 'center',
          gap: 12,
        }}
      >
        <span aria-hidden="true" style={{ fontSize: 28, lineHeight: 1 }}>
          {topic.emoji}
        </span>
        <span style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 2 }}>
          <span className="text-heading" style={{ color: 'var(--text)' }}>
            {topic.title}
          </span>
          <span className="text-caption" style={{ color: 'var(--text-muted)' }}>
            {topic.tagline}
          </span>
        </span>
        <span
          className="disclosure"
          aria-hidden="true"
          style={{ color: 'var(--text-muted)', fontSize: 18, lineHeight: 1 }}
        >
          ＋
        </span>
      </summary>

      <div style={{ display: 'flex', flexDirection: 'column', gap: 12, marginTop: 16 }}>
        <Section label="How it works">{topic.howItWorks}</Section>

        <Section label="Red flags">
          <ul
            style={{
              margin: 0,
              paddingLeft: 18,
              display: 'flex',
              flexDirection: 'column',
              gap: 4,
            }}
          >
            {topic.redFlags.map((flag, i) => (
              <li key={i} className="text-body" style={{ color: 'var(--text)' }}>
                {flag}
              </li>
            ))}
          </ul>
        </Section>

        <Section label="What to do">{topic.whatToDo}</Section>
      </div>
    </details>
  )
}

function Section({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
      <span
        className="text-caption"
        style={{
          color: 'var(--text-muted)',
          textTransform: 'uppercase',
          letterSpacing: 0.4,
          fontWeight: 600,
        }}
      >
        {label}
      </span>
      {typeof children === 'string' ? (
        <p className="text-body" style={{ color: 'var(--text)', margin: 0 }}>
          {children}
        </p>
      ) : (
        children
      )}
    </div>
  )
}
