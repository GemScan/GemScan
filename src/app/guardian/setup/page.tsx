'use client'

import { useGemScanStore } from '@/lib/store'
import { useRouter } from 'next/navigation'
import { useLocale } from '@/lib/i18n/strings'
import ContactPicker from '@/components/ContactPicker'
import GuardianStatusBar from '@/components/GuardianStatusBar'

export default function GuardianSetupPage() {
  const router = useRouter()
  const guardianModeEnabled = useGemScanStore((s) => s.guardianModeEnabled)
  const setGuardianModeEnabled = useGemScanStore((s) => s.setGuardianModeEnabled)
  const setTrustedContactId = useGemScanStore((s) => s.setTrustedContactId)
  const trustedContactId = useGemScanStore((s) => s.trustedContactId)
  const { t } = useLocale()

  const handleContactSelect = (contactId: string) => {
    setTrustedContactId(contactId)
  }

  const handleSave = () => {
    router.push('/')
  }

  return (
    <>
      <GuardianStatusBar />

      <main className="flex min-h-screen flex-col items-center px-6 py-12">
        <h1 className="text-2xl font-bold mb-4">{t('guardianMode')}</h1>

        <p className="text-center text-gray-600 max-w-sm mb-8">{t('guardianDescription')}</p>

        <div className="w-full max-w-sm mb-6">
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
        </div>

        {guardianModeEnabled && (
          <div className="w-full max-w-sm mb-6">
            <h2 className="text-sm font-semibold mb-3">{t('trustedContact')}</h2>
            {trustedContactId && (
              <p className="text-sm text-green-600 mb-3">Selected: {trustedContactId}</p>
            )}
            <ContactPicker onSelect={handleContactSelect} />
          </div>
        )}

        <button
          onClick={handleSave}
          aria-label={t('save')}
          className="rounded-xl bg-blue-500 px-8 py-4 text-white font-semibold text-lg min-h-[44px] min-w-[44px] mt-4"
        >
          {t('save')}
        </button>
      </main>
    </>
  )
}
