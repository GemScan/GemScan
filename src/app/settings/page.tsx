'use client'

import { useRouter } from 'next/navigation'
import { useGemScanStore } from '@/lib/store'
import { useLocale as useLocaleHook } from '@/hooks/useLocale'
import ModelDownloadSection from '@/components/ModelDownloadSection'

const languages = [
  { code: 'en', label: 'English' },
  { code: 'es', label: 'Espanol' },
  { code: 'hi', label: 'Hindi' },
  { code: 'zh-Hans', label: 'Chinese (Simplified)' },
  { code: 'ja', label: 'Japanese' },
]

const screeningOptions = [
  { value: 'passive', label: 'Passive' },
  { value: 'active', label: 'Active' },
] as const

export default function SettingsPage() {
  const router = useRouter()
  const screeningMode = useGemScanStore((s) => s.screeningMode)
  const setScreeningMode = useGemScanStore((s) => s.setScreeningMode)
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

  // Map UI segmented control to store. The store still accepts 'guardian' as
  // a screening mode for backwards-compat, but the UI no longer surfaces it
  // — guardian is its own independent toggle. If the persisted mode is
  // 'guardian' for some reason, treat it as 'active' for selection purposes.
  const segmentValue: 'passive' | 'active' =
    screeningMode === 'passive' ? 'passive' : 'active'

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
    <main
      style={{
        display: 'flex',
        flexDirection: 'column',
        padding: 'var(--padding-page)',
        gap: 'var(--gap-section)',
        minHeight: '100vh',
        paddingBottom: 100,
      }}
    >
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

      <ModelDownloadSection />

      <hr className="divider" />

      <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--gap-element)' }}>
        <span className="text-caption" style={{ color: 'var(--text-muted)' }}>
          Screening mode
        </span>
        <div
          role="radiogroup"
          aria-label="Screening mode"
          style={{
            display: 'flex',
            padding: 2,
            backgroundColor: 'var(--surface-alt)',
            borderRadius: 9,
            border: '1px solid var(--border)',
          }}
        >
          {screeningOptions.map((opt) => {
            const selected = segmentValue === opt.value
            return (
              <button
                key={opt.value}
                role="radio"
                aria-checked={selected}
                onClick={() => setScreeningMode(opt.value)}
                style={{
                  flex: 1,
                  height: 32,
                  minHeight: 32,
                  minWidth: 0,
                  border: 'none',
                  borderRadius: 7,
                  padding: 0,
                  backgroundColor: selected ? 'var(--surface)' : 'transparent',
                  color: 'var(--text)',
                  fontFamily: 'inherit',
                  fontSize: '0.882rem',
                  fontWeight: selected ? 600 : 500,
                  cursor: 'pointer',
                  boxShadow: selected ? '0 1px 2px rgba(0,0,0,0.08)' : 'none',
                  transition: 'background-color 120ms ease, font-weight 120ms ease',
                }}
              >
                {opt.label}
              </button>
            )
          })}
        </div>
        <span className="text-caption" style={{ color: 'var(--text-muted)' }}>
          {segmentValue === 'passive'
            ? 'Only scan when you ask.'
            : 'Scan incoming messages in the background.'}
        </span>
      </div>

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

      <p className="text-caption" style={{ color: 'var(--text)' }}>
        Version 1.0.0
      </p>
      <p className="text-caption" style={{ color: 'var(--text-muted)' }}>
        All processing on-device
      </p>
    </main>
  )
}
