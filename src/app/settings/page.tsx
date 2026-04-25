'use client'

import { useGemScanStore } from '@/lib/store'
import { useLocale } from '@/lib/i18n/strings'
import { useLocale as useLocaleHook } from '@/hooks/useLocale'

const languages = [
  { code: 'en', label: 'English' },
  { code: 'es', label: 'Espanol' },
  { code: 'hi', label: 'Hindi' },
  { code: 'zh-Hans', label: 'Chinese (Simplified)' },
  { code: 'ja', label: 'Japanese' },
]

const screeningModes = ['passive', 'active', 'guardian'] as const

export default function SettingsPage() {
  const screeningMode = useGemScanStore((s) => s.screeningMode)
  const setScreeningMode = useGemScanStore((s) => s.setScreeningMode)
  const guardianModeEnabled = useGemScanStore((s) => s.guardianModeEnabled)
  const setGuardianModeEnabled = useGemScanStore((s) => s.setGuardianModeEnabled)
  const { t } = useLocale()
  const { locale, setLocale } = useLocaleHook()

  return (
    <main className="flex min-h-screen flex-col px-6 py-12 max-w-md mx-auto">
      <h1 className="text-2xl font-bold mb-8">{t('settings')}</h1>

      <section className="mb-8">
        <h2 className="text-sm font-semibold uppercase tracking-wide text-gray-500 mb-3">
          {t('language')}
        </h2>
        <select
          value={locale}
          onChange={(e) => setLocale(e.target.value)}
          className="w-full rounded-lg border p-3 text-base"
          aria-label={t('language')}
        >
          {languages.map((lang) => (
            <option key={lang.code} value={lang.code}>
              {lang.label}
            </option>
          ))}
        </select>
      </section>

      <section className="mb-8">
        <h2 className="text-sm font-semibold uppercase tracking-wide text-gray-500 mb-3">
          {t('screeningMode')}
        </h2>
        <div className="space-y-2">
          {screeningModes.map((mode) => (
            <label
              key={mode}
              className={`flex items-center p-3 rounded-lg border cursor-pointer min-h-[44px] ${
                screeningMode === mode ? 'border-blue-500 bg-blue-50' : ''
              }`}
            >
              <input
                type="radio"
                name="screeningMode"
                value={mode}
                checked={screeningMode === mode}
                onChange={() => setScreeningMode(mode)}
                className="mr-3"
                aria-label={`${t('screeningMode')}: ${mode}`}
              />
              <span className="capitalize">{mode}</span>
            </label>
          ))}
        </div>
      </section>

      <section className="mb-8">
        <h2 className="text-sm font-semibold uppercase tracking-wide text-gray-500 mb-3">
          {t('guardianMode')}
        </h2>
        <label className="flex items-center justify-between p-4 rounded-lg border">
          <span className="font-medium">{t('enableGuardian')}</span>
          <button
            role="switch"
            aria-checked={guardianModeEnabled}
            aria-label={t('enableGuardian')}
            onClick={() => setGuardianModeEnabled(!guardianModeEnabled)}
            className={`relative w-12 h-7 rounded-full transition-colors min-h-[44px] min-w-[44px] ${
              guardianModeEnabled ? 'bg-blue-500' : 'bg-gray-300'
            }`}
          >
            <span
              className={`absolute top-0.5 left-0.5 w-6 h-6 rounded-full bg-white transition-transform ${
                guardianModeEnabled ? 'translate-x-5' : ''
              }`}
            />
          </button>
        </label>
      </section>
    </main>
  )
}
