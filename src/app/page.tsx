'use client'

import { useRouter } from 'next/navigation'
import { useGemScanStore } from '@/lib/store'
import { useLocale } from '@/lib/i18n/strings'

const verdictColor: Record<string, string> = {
  safe: 'text-green-500',
  suspicious: 'text-amber-500',
  scam: 'text-red-500',
}

export default function HomePage() {
  const router = useRouter()
  const recentResults = useGemScanStore((s) => s.recentResults)
  const { t } = useLocale()

  return (
    <main className="flex min-h-screen flex-col items-center px-6 py-12">
      <h1 className="text-3xl font-bold mb-8">{t('appName')}</h1>

      <button
        onClick={() => router.push('/analyse')}
        aria-label={t('checkButton')}
        className="rounded-xl bg-blue-500 px-8 py-4 text-white font-semibold text-lg min-h-[44px] min-w-[44px]"
      >
        {t('checkButton')}
      </button>

      {recentResults.length > 0 && (
        <section className="mt-12 w-full max-w-md">
          <h2 className="text-xl font-semibold mb-4">{t('recentResults')}</h2>
          <ul className="space-y-3">
            {recentResults.map((result) => (
              <li
                key={result.taskId}
                className="rounded-lg border p-4 flex justify-between items-center"
              >
                <span className="text-sm truncate mr-4">{result.taskId}</span>
                <span className={`font-semibold capitalize ${verdictColor[result.verdict] ?? ''}`}>
                  {result.verdict}
                </span>
              </li>
            ))}
          </ul>
        </section>
      )}
    </main>
  )
}
