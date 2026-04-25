'use client'

import { useRouter } from 'next/navigation'

export default function TermsPage() {
  const router = useRouter()

  return (
    <main
      style={{
        display: 'flex',
        flexDirection: 'column',
        padding: 'var(--padding-page)',
        gap: 'var(--gap-element)',
        minHeight: '100vh',
        paddingBottom: 100,
      }}
    >
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
        Terms &amp; Conditions
      </h1>

      <span className="text-caption" style={{ color: 'var(--text-muted)' }}>
        Effective date: 2026-04-25 · Version 1.0
      </span>

      <p className="text-body" style={{ color: 'var(--text)' }}>
        By installing or using GemScan you agree to the terms below. If you do
        not agree, do not use the app.
      </p>

      <Section title="1 · What GemScan does">
        GemScan is an on-device assistant that flags messages, links, images,
        and audio that may be scams, fraud, or social-engineering attempts. It
        is provided as an early-stage tool for personal informational use only.
      </Section>

      <Section title="2 · On-device processing">
        All inference runs locally on your device. The content you submit for
        analysis (SMS bodies, screenshots, audio clips, contacts) is not
        transmitted to GemScan-operated servers. Network requests are limited
        to one-time model downloads and, if you opt in, alerts sent to a
        trusted contact through Guardian Mode.
      </Section>

      <Section title="3 · No guarantee of accuracy">
        Scam-detection models can be wrong. A &ldquo;safe&rdquo; verdict is not
        a guarantee that a message is legitimate, and a &ldquo;scam&rdquo;
        verdict is not a guarantee that it is malicious. Use GemScan as one
        input alongside your own judgment. Do not rely on it as the sole
        defence against fraud, theft, or harm.
      </Section>

      <Section title="4 · No warranty">
        GemScan is provided &ldquo;as is&rdquo; and &ldquo;as available&rdquo;,
        without warranty of any kind, express or implied, including but not
        limited to merchantability, fitness for a particular purpose, and
        non-infringement.
      </Section>

      <Section title="5 · Limitation of liability">
        To the fullest extent permitted by law, the GemScan authors and
        contributors are not liable for any direct, indirect, incidental,
        special, consequential, or exemplary damages arising from your use of
        the app, including financial loss, data loss, or harm resulting from a
        missed or incorrect verdict.
      </Section>

      <Section title="6 · Your responsibilities">
        You agree to use GemScan in compliance with applicable laws, not to
        attempt to reverse-engineer or tamper with the on-device models, and
        not to use the app to harass, defraud, or surveil another person. You
        are responsible for the security of your device and for the contacts
        and messages you choose to make available to the app.
      </Section>

      <Section title="7 · Guardian Mode">
        If you enable Guardian Mode, GemScan may send a high-risk-scam alert
        to the trusted contact you select. You confirm that you have the
        right to share that contact&rsquo;s information for this purpose. You
        can disable Guardian Mode at any time from the Settings screen.
      </Section>

      <Section title="8 · Third-party models and licenses">
        GemScan is built with Gemma 4 (Google) and other open-source models
        and libraries. Use of those components is governed by their
        respective licenses, including the Gemma Terms of Use. Built with
        Gemma.
      </Section>

      <Section title="9 · Changes to these terms">
        We may update these terms as the app evolves. Material changes will
        be reflected by a new effective date at the top of this page.
        Continued use of the app after a change constitutes acceptance of
        the new terms.
      </Section>

      <Section title="10 · Contact">
        Questions or concerns? Open an issue on the project repository or
        reach out via the contact channel listed in the app&rsquo;s store
        listing.
      </Section>
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
