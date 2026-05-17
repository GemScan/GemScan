'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { useGemScanStore } from '@/lib/store'
import { useLocale as useLocaleHook } from '@/hooks/useLocale'
import { useDeviceStatus } from '@/hooks/useDeviceStatus'
import { getGemmaPlugin } from '@/lib/gemma'
import ModelDownloadSection from '@/components/ModelDownloadSection'

const languages = [
  { code: 'en', label: 'English' },
  { code: 'es', label: 'Espanol' },
  { code: 'hi', label: 'Hindi' },
  { code: 'zh-Hans', label: 'Chinese (Simplified)' },
  { code: 'ja', label: 'Japanese' },
]

export default function SettingsPage() {
  const router = useRouter()
  const guardianModeEnabled = useGemScanStore((s) => s.guardianModeEnabled)
  const setGuardianModeEnabled = useGemScanStore((s) => s.setGuardianModeEnabled)
  const trustedContactId = useGemScanStore((s) => s.trustedContactId)
  const { locale, setLocale } = useLocaleHook()

  const currentLanguageName = languages.find((l) => l.code === locale)?.label ?? locale

  const cycleLanguage = () => {
    const idx = languages.findIndex((l) => l.code === locale)
    const next = languages[(idx + 1) % languages.length]
    setLocale(next.code)
  }

  const toggleGuardian = () => {
    if (guardianModeEnabled) {
      setGuardianModeEnabled(false)
      return
    }
    if (trustedContactId) {
      setGuardianModeEnabled(true)
    } else {
      router.push('/guardian/setup')
    }
  }

  return (
    <main className="page">
      <div
        style={{
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          gap: 'var(--gap-element)',
        }}
      >
        <h1 className="text-title" style={{ color: 'var(--text)' }}>
          Settings
        </h1>
        <button
          onClick={cycleLanguage}
          aria-label={`Language: ${currentLanguageName}. Tap to change.`}
          style={{
            display: 'inline-flex',
            alignItems: 'center',
            gap: 6,
            height: 32,
            minHeight: 32,
            minWidth: 0,
            padding: '0 12px',
            borderRadius: 16,
            border: '1px solid var(--border)',
            backgroundColor: 'var(--surface-alt)',
            color: 'var(--text)',
            fontFamily: 'inherit',
            fontSize: '0.882rem',
            fontWeight: 500,
            cursor: 'pointer',
            whiteSpace: 'nowrap',
          }}
        >
          {currentLanguageName}
          <span style={{ color: 'var(--text-muted)', fontSize: '0.7rem' }}>▾</span>
        </button>
      </div>

      <div className="page-scroll">
      <ModelDownloadSection />

      <HaikuTestSection />

      <hr className="divider" />

      <div
        style={{
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          gap: 'var(--gap-element)',
        }}
      >
        <div style={{ display: 'flex', flexDirection: 'column', flex: 1, minWidth: 0 }}>
          <span className="text-body" style={{ color: 'var(--text)' }}>
            Allow Guardian
          </span>
          <span className="text-caption" style={{ color: 'var(--text-muted)' }}>
            {guardianModeEnabled && trustedContactId
              ? 'Alerts your trusted contact on high-risk scams.'
              : 'Alert a trusted contact on high-risk scams.'}
          </span>
        </div>
        <button
          role="switch"
          aria-checked={guardianModeEnabled}
          aria-label="Allow Guardian"
          onClick={toggleGuardian}
          style={{
            position: 'relative',
            width: 51,
            height: 31,
            minWidth: 51,
            minHeight: 31,
            borderRadius: 31,
            border: 'none',
            padding: 0,
            backgroundColor: guardianModeEnabled ? 'var(--safe)' : 'var(--disabled-bg)',
            cursor: 'pointer',
            transition: 'background-color 160ms ease',
            flexShrink: 0,
          }}
        >
          <span
            style={{
              position: 'absolute',
              top: 2,
              left: guardianModeEnabled ? 22 : 2,
              width: 27,
              height: 27,
              borderRadius: '50%',
              backgroundColor: '#ffffff',
              boxShadow: '0 2px 4px rgba(0,0,0,0.15), 0 0 1px rgba(0,0,0,0.04)',
              transition: 'left 160ms ease',
            }}
          />
        </button>
      </div>

      {guardianModeEnabled && trustedContactId && (
        <button
          onClick={() => router.push('/guardian/setup')}
          style={{
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            width: '100%',
            height: 'var(--height-row)',
            padding: 0,
            background: 'none',
            border: 'none',
            cursor: 'pointer',
            color: 'var(--text)',
            textAlign: 'left',
            marginTop: -8,
          }}
        >
          <span className="text-body">Trusted contact</span>
          <span
            className="text-body"
            style={{
              color: 'var(--text-muted)',
              display: 'inline-flex',
              alignItems: 'center',
              gap: 6,
            }}
          >
            Change
            <span className="text-caption">▸</span>
          </span>
        </button>
      )}

      <hr className="divider" />

      <span className="text-caption" style={{ color: 'var(--text-muted)' }}>
        About
      </span>

      <button
        onClick={() => router.push('/terms')}
        style={{
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          width: '100%',
          height: 'var(--height-row)',
          padding: 0,
          background: 'none',
          border: 'none',
          cursor: 'pointer',
          color: 'var(--text)',
          textAlign: 'left',
        }}
      >
        <span className="text-body">Terms &amp; Conditions</span>
        <span className="text-caption" style={{ color: 'var(--text-muted)' }}>
          ▸
        </span>
      </button>

      <p className="text-caption" style={{ color: 'var(--text)' }}>
        Version 1.0.0
      </p>
      <p className="text-caption" style={{ color: 'var(--text-muted)' }}>
        All processing on-device
      </p>
      </div>
    </main>
  )
}

function HaikuTestSection() {
  const deviceStatus = useDeviceStatus()
  const loaded = deviceStatus?.e2bLoaded ?? false
  const [haiku, setHaiku] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const handleGenerate = async () => {
    setBusy(true)
    setError(null)
    setHaiku(null)
    try {
      const plugin = await getGemmaPlugin()
      const result = await plugin.generateHaiku()
      setHaiku(result.haiku)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to generate haiku')
    } finally {
      setBusy(false)
    }
  }

  const disabled = !loaded || busy

  return (
    <div
      style={{
        display: 'flex',
        flexDirection: 'column',
        gap: 'var(--gap-element)',
        paddingTop: 8,
      }}
    >
      <span className="text-caption" style={{ color: 'var(--text-muted)' }}>
        Quick test
      </span>

      <button
        onClick={handleGenerate}
        disabled={disabled}
        aria-label="Generate a funny haiku to test the model"
        style={{
          height: 'var(--height-row)',
          minHeight: 'var(--height-row)',
          padding: '0 16px',
          borderRadius: 10,
          border: 'none',
          backgroundColor: disabled ? 'var(--disabled-bg)' : 'var(--text)',
          color: disabled ? 'var(--text-muted)' : 'var(--surface)',
          fontFamily: 'inherit',
          fontSize: '0.95rem',
          fontWeight: 600,
          cursor: disabled ? 'not-allowed' : 'pointer',
          opacity: disabled ? 0.7 : 1,
          transition: 'background-color 120ms ease, opacity 120ms ease',
        }}
      >
        {busy ? 'Generating…' : loaded ? 'Generate funny haiku' : 'Model not active'}
      </button>

      {haiku && (
        <pre
          aria-live="polite"
          style={{
            margin: 0,
            padding: 12,
            backgroundColor: 'var(--surface-alt)',
            borderRadius: 10,
            border: '0.5px solid var(--border)',
            color: 'var(--text)',
            fontFamily: 'inherit',
            fontSize: '0.95rem',
            lineHeight: 1.45,
            whiteSpace: 'pre-wrap',
            wordBreak: 'break-word',
          }}
        >
          {haiku}
        </pre>
      )}

      {error && (
        <span
          role="alert"
          className="text-caption"
          style={{ color: 'var(--scam)' }}
        >
          {error}
        </span>
      )}
    </div>
  )
}
