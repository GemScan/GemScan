'use client'

import { useRouter } from 'next/navigation'
import { useGemScanStore } from '@/lib/store'
import { useLocale as useLocaleHook } from '@/hooks/useLocale'
import SettingsRow from '@/components/SettingsRow'

const languages = [
  { code: 'en', label: 'English' },
  { code: 'es', label: 'Espanol' },
  { code: 'hi', label: 'Hindi' },
  { code: 'zh-Hans', label: 'Chinese (Simplified)' },
  { code: 'ja', label: 'Japanese' },
]

const screeningModes = ['passive', 'active', 'guardian'] as const

export default function SettingsPage() {
  const router = useRouter()
  const screeningMode = useGemScanStore((s) => s.screeningMode)
  const setScreeningMode = useGemScanStore((s) => s.setScreeningMode)
  const trustedContactId = useGemScanStore((s) => s.trustedContactId)
  const { locale, setLocale } = useLocaleHook()

  const currentLanguageName = languages.find((l) => l.code === locale)?.label ?? locale

  const cycleLanguage = () => {
    const idx = languages.findIndex((l) => l.code === locale)
    const next = languages[(idx + 1) % languages.length]
    setLocale(next.code)
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
      <h1 className="text-title" style={{ color: 'var(--text)' }}>
        Settings
      </h1>

      <SettingsRow
        label="Language"
        value={currentLanguageName}
        showChevron
        onClick={cycleLanguage}
      />

      <hr className="divider" />

      <span className="text-caption" style={{ color: 'var(--text-muted)' }}>
        Screening mode
      </span>

      <div style={{ display: 'flex', flexDirection: 'column' }}>
        {screeningModes.map((mode) => (
          <label
            key={mode}
            style={{
              display: 'flex',
              alignItems: 'center',
              height: 'var(--height-row)',
              cursor: 'pointer',
              gap: 'var(--gap-element)',
            }}
          >
            <input
              type="radio"
              name="screeningMode"
              value={mode}
              checked={screeningMode === mode}
              onChange={() => setScreeningMode(mode)}
            />
            <span className="text-body" style={{ textTransform: 'capitalize' }}>
              {mode}
            </span>
          </label>
        ))}
      </div>

      <hr className="divider" />

      <SettingsRow
        label="Guardian mode"
        value={trustedContactId ? 'Contact set' : 'None'}
        showChevron
        onClick={() => router.push('/guardian/setup')}
      />

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
