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

        <Section title="What is GemScan?">
          {/* TODO: short product description */}
          GemScan is your private AI advisor who shields you against text scams. GemScan runs the Gemma-4-E2B (4bit) model efficiently on your iOS device to analyze texts and images that you received!
          Since the app runs on your iPhone, you don&apos;t share your private data with us. Our app works even in airplane mode!

          GemScan is open-sourced with MIT license.
        </Section>

        <Section title="How it works">
          {/* TODO: brief technical overview */}
          Brief, non-technical explanation of the on-device pipeline goes here.
        </Section>

        <Section title="Who built it">
          {/* TODO: team / author */}
          Shashank Bangalore Lakshman and Scott Eiers
        </Section>

        <Section title="Why we built it">
          {/* TODO: model + library credits */}
          We love to build AI products for social good!
          We built GemScan as a submission for Kaggle&apos;s Gemma-4-Good Hackathon in 2026!
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
