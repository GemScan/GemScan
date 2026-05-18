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
          GemScan · v1.0
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

        <Section title="Source Code">
          <ExternalLink href="https://github.com/GemScan/GemScan">
            github.com/GemScan/GemScan
          </ExternalLink>
        </Section>

        <Section title="Website">
          <ExternalLink href="https://gemscan.github.io/GemScan/">
            gemscan.github.io/GemScan
          </ExternalLink>
        </Section>
      </div>
    </main>
  )
}

/// Anchor that always escapes the in-app WebView and opens in the
/// system browser (Safari on iOS, the default browser on web). We
/// intercept the click rather than relying on `target="_blank"` alone
/// because Capacitor's WKWebView has historically opened new-window
/// links in a blank in-app frame on some iOS versions. `window.open`
/// with `_blank` is the form Capacitor reliably routes to Safari.
function ExternalLink({ href, children }: { href: string; children: React.ReactNode }) {
  const handleClick = (e: React.MouseEvent<HTMLAnchorElement>) => {
    e.preventDefault()
    window.open(href, '_blank', 'noopener,noreferrer')
  }
  return (
    <a
      href={href}
      onClick={handleClick}
      target="_blank"
      rel="noopener noreferrer"
      style={{
        color: '#004aad',
        textDecoration: 'underline',
        wordBreak: 'break-all',
      }}
    >
      {children}
    </a>
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
