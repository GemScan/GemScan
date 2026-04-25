'use client'

import { useState, useCallback } from 'react'
import { useRouter } from 'next/navigation'
import { getGemmaPlugin } from '@/lib/gemma'
import { useModelDownload } from '@/hooks/useModelDownload'
import { useLocale } from '@/lib/i18n/strings'
import ModelDownloadProgress from '@/components/ModelDownloadProgress'

export default function OnboardingPage() {
  const router = useRouter()
  const [hasConsented, setHasConsented] = useState(false)
  const [downloadStarted, setDownloadStarted] = useState(false)
  const [downloadComplete, setDownloadComplete] = useState(false)
  const { progress, isDownloading } = useModelDownload()
  const { t } = useLocale()

  const handleDownload = useCallback(async () => {
    setDownloadStarted(true)
    try {
      const plugin = await getGemmaPlugin()
      await plugin.downloadModels({ modelIds: ['e2b', 'e4b'] })
      setDownloadComplete(true)
    } catch {
      // Allow retry
      setDownloadStarted(false)
    }
  }, [])

  return (
    <main className="flex min-h-screen flex-col items-center justify-center px-6 py-12">
      <h1 className="text-3xl font-bold mb-4">{t('onboarding')}</h1>
      <p className="text-center text-gray-600 max-w-sm mb-8">
        GemScan uses on-device AI to detect scams in messages, emails, URLs, and calls. Your data
        never leaves your device.
      </p>

      {!hasConsented && (
        <>
          <p className="text-sm text-gray-500 max-w-sm text-center mb-6">{t('consentMessage')}</p>
          <button
            onClick={() => setHasConsented(true)}
            aria-label={t('iAgree')}
            className="rounded-xl bg-blue-500 px-8 py-4 text-white font-semibold text-lg min-h-[44px] min-w-[44px]"
          >
            {t('iAgree')}
          </button>
        </>
      )}

      {hasConsented && !downloadComplete && (
        <>
          <button
            onClick={handleDownload}
            disabled={isDownloading || downloadStarted}
            aria-label={isDownloading ? t('downloading') : t('downloadModels')}
            className="rounded-xl bg-blue-500 px-8 py-4 text-white font-semibold text-lg disabled:opacity-50 min-h-[44px] min-w-[44px]"
          >
            {isDownloading ? t('downloading') : t('downloadModels')}
          </button>

          {isDownloading && (
            <div className="mt-6 w-full max-w-sm">
              <ModelDownloadProgress progress={progress} isDownloading={isDownloading} />
            </div>
          )}
        </>
      )}

      {downloadComplete && (
        <>
          <p className="text-green-600 font-semibold mb-6">{t('modelsReady')}</p>
          <button
            onClick={() => router.push('/')}
            aria-label={t('getStarted')}
            className="rounded-xl bg-green-500 px-8 py-4 text-white font-semibold text-lg min-h-[44px] min-w-[44px]"
          >
            {t('getStarted')}
          </button>
        </>
      )}
    </main>
  )
}
