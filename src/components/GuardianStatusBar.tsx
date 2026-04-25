'use client'

import { useGemScanStore } from '@/lib/store'
import { useLocale } from '@/lib/i18n/strings'

function maskContactId(id: string): string {
  if (id.length <= 4) return id
  return `${id.slice(0, 2)}${'*'.repeat(id.length - 4)}${id.slice(-2)}`
}

export default function GuardianStatusBar() {
  const guardianModeEnabled = useGemScanStore((s) => s.guardianModeEnabled)
  const setGuardianModeEnabled = useGemScanStore((s) => s.setGuardianModeEnabled)
  const trustedContactId = useGemScanStore((s) => s.trustedContactId)
  const { t } = useLocale()

  if (!guardianModeEnabled) return null

  return (
    <div
      className="w-full bg-blue-500 text-white px-4 py-3 flex items-center justify-between"
      role="status"
      aria-label={t('guardianActive')}
    >
      <div className="flex items-center gap-2 text-sm">
        <span className="font-semibold">{t('guardianActive')}</span>
        {trustedContactId && (
          <span className="opacity-80">&middot; {maskContactId(trustedContactId)}</span>
        )}
      </div>
      <button
        onClick={() => setGuardianModeEnabled(false)}
        aria-label={t('pause')}
        className="rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium min-h-[44px] min-w-[44px] hover:bg-blue-700 transition-colors"
      >
        {t('pause')}
      </button>
    </div>
  )
}
