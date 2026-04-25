'use client'

import { useGemScanStore } from '@/lib/store'

export function useLocale() {
  const locale = useGemScanStore((s) => s.preferredLanguage)
  const setLocale = useGemScanStore((s) => s.setPreferredLanguage)

  return { locale, setLocale }
}
