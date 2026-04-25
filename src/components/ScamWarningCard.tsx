'use client'

import { useRef, useEffect } from 'react'
import type { AgentResult, ScamVerdict } from '@/lib/gemma/types'
import { useLocale } from '@/lib/i18n/strings'

interface ScamWarningCardProps {
  result: AgentResult
  onDismiss: () => void
  onShare: () => void
}

const verdictColorMap: Record<
  ScamVerdict,
  {
    bg: string
    border: string
    text: string
    bar: string
  }
> = {
  safe: {
    bg: 'bg-green-50 dark:bg-green-950',
    border: 'border-green-300 dark:border-green-700',
    text: 'text-green-800 dark:text-green-200',
    bar: 'bg-green-500',
  },
  suspicious: {
    bg: 'bg-amber-50 dark:bg-amber-950',
    border: 'border-amber-300 dark:border-amber-700',
    text: 'text-amber-800 dark:text-amber-200',
    bar: 'bg-amber-500',
  },
  scam: {
    bg: 'bg-red-50 dark:bg-red-950',
    border: 'border-red-300 dark:border-red-700',
    text: 'text-red-800 dark:text-red-200',
    bar: 'bg-red-500',
  },
}

const verdictKey: Record<ScamVerdict, string> = {
  safe: 'verdictSafe',
  suspicious: 'verdictSuspicious',
  scam: 'verdictScam',
}

export default function ScamWarningCard({ result, onDismiss, onShare }: ScamWarningCardProps) {
  const headingRef = useRef<HTMLHeadingElement>(null)
  const { t } = useLocale()
  const colors = verdictColorMap[result.verdict]
  const confidencePercent = Math.round(result.confidence * 100)

  useEffect(() => {
    headingRef.current?.focus()
  }, [])

  return (
    <div
      className={`w-full max-w-md rounded-xl border-2 p-6 ${colors.bg} ${colors.border}`}
      role="alert"
      aria-label={`${t(verdictKey[result.verdict])} verdict with ${confidencePercent}% confidence`}
    >
      <div className="flex items-center justify-between mb-4">
        <h2 ref={headingRef} tabIndex={-1} className={`text-2xl font-bold ${colors.text}`}>
          {t(verdictKey[result.verdict])}
        </h2>
        <span
          className="inline-flex items-center rounded-full bg-gray-200 dark:bg-gray-700 px-3 py-1 text-xs font-medium uppercase tracking-wide"
          aria-label={`${t('modelTier')}: ${result.modelTier.toUpperCase()}`}
        >
          {result.modelTier.toUpperCase()}
        </span>
      </div>

      <div className="mb-4">
        <div className="flex justify-between text-sm mb-1">
          <span className="font-medium">{t('confidence')}</span>
          <span>{confidencePercent}%</span>
        </div>
        <div
          className="h-3 w-full rounded-full bg-gray-200 dark:bg-gray-700 overflow-hidden"
          role="progressbar"
          aria-valuenow={confidencePercent}
          aria-valuemin={0}
          aria-valuemax={100}
          aria-label={`${t('confidence')}: ${confidencePercent}%`}
        >
          <div
            className={`h-full rounded-full transition-all duration-500 ${colors.bar}`}
            style={{ width: `${confidencePercent}%` }}
          />
        </div>
      </div>

      {result.reasoning.length > 0 && (
        <div className="mb-4">
          <h3 className="text-sm font-semibold mb-2">{t('reasoning')}</h3>
          <ul className="list-disc list-inside space-y-1 text-sm">
            {result.reasoning.map((reason, i) => (
              <li key={i}>{reason}</li>
            ))}
          </ul>
        </div>
      )}

      <div className="flex gap-3 mt-4">
        <button
          onClick={onShare}
          aria-label={t('share')}
          className="flex-1 rounded-xl bg-blue-500 px-4 py-3 text-white font-semibold text-sm min-h-[44px] min-w-[44px]"
        >
          {t('share')}
        </button>
        <button
          onClick={onDismiss}
          aria-label={t('dismiss')}
          className="flex-1 rounded-xl bg-gray-200 dark:bg-gray-700 px-4 py-3 font-semibold text-sm min-h-[44px] min-w-[44px]"
        >
          {t('dismiss')}
        </button>
      </div>
    </div>
  )
}
