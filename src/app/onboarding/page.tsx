'use client'

import { useState, useCallback } from 'react'
import { useRouter } from 'next/navigation'
import { getGemmaPlugin } from '@/lib/gemma'
import { useModelDownload } from '@/hooks/useModelDownload'
import ProgressRow from '@/components/ProgressRow'

const models = [
  { id: 'distilbert', label: 'DistilBERT', size: '5 MB' },
  { id: 'e2b', label: 'Gemma E2B', size: '1.8 GB' },
  { id: 'e4b', label: 'Gemma E4B', size: '3.2 GB' },
] as const

export default function OnboardingPage() {
  const router = useRouter()
  const [downloadStarted, setDownloadStarted] = useState(false)
  const [downloadComplete, setDownloadComplete] = useState(false)
  const { progress, isDownloading } = useModelDownload()

  const handleDownload = useCallback(async () => {
    setDownloadStarted(true)
    try {
      const plugin = await getGemmaPlugin()
      await plugin.downloadModels({ modelIds: ['e2b', 'e4b'] })
      setDownloadComplete(true)
      router.push('/')
    } catch {
      setDownloadStarted(false)
    }
  }, [router])

  const inProgress = isDownloading || (downloadStarted && !downloadComplete)

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
        Welcome to GemScan
      </h1>

      <p className="text-body" style={{ color: 'var(--text)' }}>
        GemScan checks messages and calls for scams. Everything stays on your phone.
      </p>

      <hr className="divider" />

      <h2 className="text-heading" style={{ color: 'var(--text)' }}>
        Downloading models
      </h2>

      <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--gap-element)' }}>
        {models.map((m) => (
          <ProgressRow
            key={m.id}
            label={m.label}
            progress={progress.get(m.id) ?? 0}
            totalSize={m.size}
          />
        ))}
      </div>

      <hr className="divider" />

      <p className="text-caption" style={{ color: 'var(--text-muted)' }}>
        By continuing, you agree that GemScan processes content locally only.
      </p>

      <button className="btn-primary" onClick={handleDownload} disabled={inProgress}>
        {inProgress ? 'Downloading…' : 'Download and start'}
      </button>
    </main>
  )
}
