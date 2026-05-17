'use client'

import { useRouter } from 'next/navigation'

export default function AboutPage() {
  const router = useRouter()

  return (
    <main className="page" style={{ gap: 'var(--gap-element)' }}>
      <button
        className="text-body"
        onClick={() => router.back()}
        style={{
          color: 'var(--text)',
          background: 'none',
          border: 'none',
          padding: '8px 0',
          cursor: 'pointer',
          alignSelf: 'flex-start',
          minHeight: 44,
          minWidth: 44,
        }}
      >
        ← Back
      </button>

      <h1 className="text-title" style={{ color: 'var(--text)' }}>
        About
      </h1>

      <div className="page-scroll" style={{ gap: 'var(--gap-element)' }}>
        <span className="text-caption" style={{ color: 'var(--text-muted)' }}>
          {/* TODO: tagline / version subtitle */}
          GemScan · Version 1.0.0
        </span>

        <Section title="What GemScan is">
          {/* TODO: short product description */}
          One- or two-sentence product description goes here.
        </Section>

        <Section title="How it works">
          {/* TODO: brief technical overview */}
          Brief, non-technical explanation of the on-device pipeline goes here.
        </Section>

        <Section title="Who built it">
          {/* TODO: team / author */}
          Author or team credit goes here.
        </Section>

        <Section title="Acknowledgements">
          {/* TODO: model + library credits */}
          Acknowledgements for Gemma, MLX, Capacitor, Next.js, etc. go here.
        </Section>

        <Section title="Contact">
          {/* TODO: contact info or repo link */}
          Contact email or repository URL goes here.
        </Section>
      </div>
    </main>
  )
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
      <h2 className="text-heading" style={{ color: 'var(--text)' }}>
        {title}
      </h2>
      <p className="text-body" style={{ color: 'var(--text)' }}>
        {children}
      </p>
    </section>
  )
}
