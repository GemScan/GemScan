'use client'

import { useLocale } from '@/lib/i18n/strings'

interface ModelDownloadProgressProps {
  progress: Map<string, number>
  isDownloading: boolean
}

const modelMeta: Record<string, { label: string; sizeMB: number }> = {
  distilbert: { label: 'DistilBERT', sizeMB: 5 },
  e2b: { label: 'Gemma E2B', sizeMB: 1800 },
  e4b: { label: 'Gemma E4B', sizeMB: 3200 },
}

export default function ModelDownloadProgress({
  progress,
  isDownloading,
}: ModelDownloadProgressProps) {
  const { t } = useLocale()

  if (!isDownloading && progress.size === 0) return null

  const models = ['distilbert', 'e2b', 'e4b'] as const

  return (
    <div className="w-full max-w-sm space-y-4" aria-label="Model download progress">
      {models.map((modelId) => {
        const p = progress.get(modelId) ?? 0
        const meta = modelMeta[modelId]
        const downloadedMB = Math.round(p * meta.sizeMB)
        const percent = Math.round(p * 100)
        const isDone = p >= 1

        return (
          <div key={modelId}>
            <div className="flex items-center justify-between text-sm mb-1">
              <span className="font-medium">{meta.label}</span>
              <span className="flex items-center gap-1">
                {isDone ? (
                  <span aria-label={`${meta.label} ${t('complete')}`} className="text-green-500">
                    &#10003;
                  </span>
                ) : (
                  <span>{percent}%</span>
                )}
              </span>
            </div>
            <div
              className="h-3 w-full rounded-full bg-gray-200 dark:bg-gray-700 overflow-hidden"
              role="progressbar"
              aria-valuenow={downloadedMB}
              aria-valuemin={0}
              aria-valuemax={meta.sizeMB}
              aria-valuetext={`${downloadedMB} MB of ${meta.sizeMB} MB`}
              aria-label={`${meta.label} download progress`}
            >
              <div
                className={`h-full rounded-full transition-all duration-300 ${
                  isDone ? 'bg-green-500' : 'bg-blue-500'
                }`}
                style={{ width: `${percent}%` }}
              />
            </div>
            <p className="text-xs text-gray-500 mt-0.5">
              {downloadedMB} MB / {meta.sizeMB} MB
            </p>
          </div>
        )
      })}
    </div>
  )
}
