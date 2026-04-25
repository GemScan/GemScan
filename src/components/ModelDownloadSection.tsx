'use client'

import { useEffect, useRef, useState } from 'react'
import { getGemmaPlugin } from '@/lib/gemma'
import { useModelDownload } from '@/hooks/useModelDownload'
import { useDeviceStatus } from '@/hooks/useDeviceStatus'
import type { ModelId } from '@/lib/gemma/types'

interface ModelMeta {
  id: ModelId
  name: string
  sizeBytes: number
  description: string
}

const MODELS: ModelMeta[] = [
  {
    id: 'distilbert',
    name: 'SMS Triage',
    sizeBytes: 5_000_000,
    description: 'Lightweight SMS pre-classifier',
  },
  {
    id: 'e2b',
    name: 'Gemma 4 E2B',
    sizeBytes: 1_500_000_000,
    description: 'Always-on screening (2.3B params)',
  },
  {
    id: 'e4b',
    name: 'Gemma 4 E4B',
    sizeBytes: 3_000_000_000,
    description: 'Deep reasoning, on demand (4.5B params)',
  },
]

type ModelStatus =
  | { kind: 'unknown' }
  | { kind: 'pending' }
  | { kind: 'downloading'; progress: number }
  | { kind: 'verifying' }
  | { kind: 'verified'; sizeBytes: number }
  | { kind: 'failed'; reason: string }

function formatBytes(bytes: number): string {
  if (bytes < 1_000_000) return `${Math.round(bytes / 1_000)} KB`
  if (bytes < 1_000_000_000) return `${Math.round(bytes / 1_000_000)} MB`
  return `${(bytes / 1_000_000_000).toFixed(1)} GB`
}

function CheckIcon({ size = 18 }: { size?: number }) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      stroke="var(--safe)"
      strokeWidth="2.5"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-label="Verified"
    >
      <polyline points="20 6 9 17 4 12" />
    </svg>
  )
}

function ErrorIcon({ size = 18 }: { size?: number }) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      stroke="var(--scam)"
      strokeWidth="2.5"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-label="Failed"
    >
      <line x1="18" y1="6" x2="6" y2="18" />
      <line x1="6" y1="6" x2="18" y2="18" />
    </svg>
  )
}

function Spinner() {
  return (
    <span
      style={{
        display: 'inline-block',
        width: 16,
        height: 16,
        border: '2px solid var(--border)',
        borderTopColor: 'var(--text)',
        borderRadius: '50%',
        animation: 'spin 800ms linear infinite',
      }}
      aria-hidden="true"
    />
  )
}

export default function ModelDownloadSection() {
  const [statuses, setStatuses] = useState<Record<ModelId, ModelStatus>>({
    distilbert: { kind: 'unknown' },
    e2b: { kind: 'unknown' },
    e4b: { kind: 'unknown' },
  })
  const inFlight = useRef<Set<ModelId>>(new Set())
  const { progress } = useModelDownload()
  const deviceStatus = useDeviceStatus()

  // Fetch initial ready state on mount.
  useEffect(() => {
    let cancelled = false
    async function check() {
      try {
        const plugin = await getGemmaPlugin()
        const status = await plugin.isReady()
        if (cancelled) return

        setStatuses((prev) => {
          const next = { ...prev }
          for (const model of MODELS) {
            if (status.missingModels.includes(model.id)) {
              next[model.id] = { kind: 'pending' }
            } else {
              // Already on disk — assume verified from previous launch
              next[model.id] = { kind: 'verified', sizeBytes: model.sizeBytes }
            }
          }
          return next
        })
      } catch {
        if (cancelled) return
        setStatuses((prev) => {
          const next = { ...prev }
          for (const model of MODELS) {
            next[model.id] = { kind: 'pending' }
          }
          return next
        })
      }
    }
    check()
    return () => {
      cancelled = true
    }
  }, [])

  // Surface live download progress into per-model status.
  useEffect(() => {
    setStatuses((prev) => {
      const next = { ...prev }
      for (const [id, prog] of progress.entries()) {
        if (!inFlight.current.has(id as ModelId)) continue
        if (prog < 1) {
          next[id as ModelId] = { kind: 'downloading', progress: prog }
        }
      }
      return next
    })
  }, [progress])

  const handleDownload = async (modelId: ModelId) => {
    if (inFlight.current.has(modelId)) return
    inFlight.current.add(modelId)
    setStatuses((s) => ({ ...s, [modelId]: { kind: 'downloading', progress: 0 } }))

    try {
      const plugin = await getGemmaPlugin()
      await plugin.downloadModels({ modelIds: [modelId] })

      setStatuses((s) => ({ ...s, [modelId]: { kind: 'verifying' } }))

      const result = await plugin.verifyModel({ modelId })
      if (result.valid) {
        setStatuses((s) => ({
          ...s,
          [modelId]: { kind: 'verified', sizeBytes: result.sizeBytes },
        }))
      } else {
        setStatuses((s) => ({
          ...s,
          [modelId]: { kind: 'failed', reason: result.reason ?? 'Verification failed' },
        }))
      }
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Download failed'
      setStatuses((s) => ({ ...s, [modelId]: { kind: 'failed', reason: message } }))
    } finally {
      inFlight.current.delete(modelId)
    }
  }

  return (
    <section style={{ display: 'flex', flexDirection: 'column', gap: 'var(--gap-element)' }}>
      <span className="text-caption" style={{ color: 'var(--text-muted)' }}>
        On-device models
      </span>

      {MODELS.map((model) => {
        const status = statuses[model.id]
        const loaded = isLoadedInRAM(model.id, deviceStatus)
        return (
          <ModelRow
            key={model.id}
            meta={model}
            status={status}
            loaded={loaded}
            onDownload={() => handleDownload(model.id)}
            onRetry={() => handleDownload(model.id)}
          />
        )
      })}

      <p className="text-caption" style={{ color: 'var(--text-muted)', marginTop: 8 }}>
        Models run entirely on your device. Each download is verified before use.
        Wi-Fi recommended for first download.
      </p>
    </section>
  )
}

interface ModelRowProps {
  meta: ModelMeta
  status: ModelStatus
  loaded: boolean | null
  onDownload: () => void
  onRetry: () => void
}

function isLoadedInRAM(
  modelId: ModelId,
  status: ReturnType<typeof useDeviceStatus>
): boolean | null {
  if (!status) return null
  if (modelId === 'e2b') return status.e2bLoaded
  if (modelId === 'e4b') return status.e4bLoaded
  // DistilBERT: tiny, lives inside the SMS Filter extension; treat as
  // active whenever the host-app status is reachable.
  return true
}

function StatusPill({ loaded }: { loaded: boolean | null }) {
  // While we don't yet have a status snapshot from the device, render nothing
  // — avoids a flash of "Inactive" before the first poll resolves.
  if (loaded === null) return null

  const palette = loaded
    ? { bg: 'var(--safe-bg)', dot: 'var(--safe)', text: 'var(--safe)' }
    : { bg: 'var(--surface-alt)', dot: 'var(--text-muted)', text: 'var(--text-muted)' }

  return (
    <span
      style={{
        display: 'inline-flex',
        alignItems: 'center',
        gap: 5,
        padding: '2px 8px 2px 7px',
        borderRadius: 999,
        backgroundColor: palette.bg,
        color: palette.text,
        fontSize: 11,
        fontWeight: 600,
        lineHeight: 1.4,
        letterSpacing: 0.1,
        textTransform: 'uppercase',
        verticalAlign: 'middle',
        minWidth: 0,
        minHeight: 0,
      }}
      aria-label={loaded ? 'Loaded in RAM' : 'Not loaded'}
    >
      <span
        aria-hidden="true"
        style={{
          width: 6,
          height: 6,
          borderRadius: '50%',
          backgroundColor: palette.dot,
        }}
      />
      {loaded ? 'Active' : 'Inactive'}
    </span>
  )
}

function ModelRow({ meta, status, loaded, onDownload, onRetry }: ModelRowProps) {
  const downloading = status.kind === 'downloading'
  const verifying = status.kind === 'verifying'
  const verified = status.kind === 'verified'
  const failed = status.kind === 'failed'
  const pct = downloading ? Math.round(status.progress * 100) : 0

  return (
    <div
      style={{
        display: 'flex',
        flexDirection: 'column',
        gap: 8,
        padding: '12px 0',
        borderBottom: '0.5px solid var(--border)',
      }}
    >
      <div
        style={{
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          gap: 12,
        }}
      >
        <div style={{ flex: 1, minWidth: 0 }}>
          <div
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: 8,
              flexWrap: 'wrap',
            }}
          >
            <span className="text-body" style={{ color: 'var(--text)', fontWeight: 500 }}>
              {meta.name}
            </span>
            {verified && <StatusPill loaded={loaded} />}
          </div>
          <div className="text-caption" style={{ color: 'var(--text-muted)' }}>
            {formatBytes(meta.sizeBytes)} · {meta.description}
          </div>
        </div>

        <div style={{ flexShrink: 0 }}>
          {verified && (
            <span
              style={{
                display: 'inline-flex',
                alignItems: 'center',
                gap: 4,
                color: 'var(--safe)',
                fontSize: 13,
                fontWeight: 500,
              }}
            >
              <CheckIcon />
              Verified
            </span>
          )}

          {verifying && (
            <span
              style={{
                display: 'inline-flex',
                alignItems: 'center',
                gap: 6,
                color: 'var(--text-muted)',
                fontSize: 13,
              }}
            >
              <Spinner />
              Verifying…
            </span>
          )}

          {downloading && (
            <button
              disabled
              role="progressbar"
              aria-valuenow={pct}
              aria-valuemin={0}
              aria-valuemax={100}
              aria-label={`${meta.name} downloading, ${pct}%`}
              style={{
                position: 'relative',
                overflow: 'hidden',
                width: 110,
                height: 32,
                borderRadius: 999,
                border: 'none',
                backgroundColor: 'var(--surface-alt)',
                padding: 0,
                minWidth: 0,
                cursor: 'default',
                isolation: 'isolate',
              }}
            >
              <span
                aria-hidden="true"
                style={{
                  position: 'absolute',
                  top: 0,
                  bottom: 0,
                  left: 0,
                  width: `${pct}%`,
                  backgroundColor: 'var(--text)',
                  transition: 'width 200ms linear',
                  pointerEvents: 'none',
                }}
              />
              <span
                aria-live="polite"
                style={{
                  position: 'relative',
                  zIndex: 1,
                  fontSize: 15,
                  fontWeight: 600,
                  fontVariantNumeric: 'tabular-nums',
                  color: '#ffffff',
                  mixBlendMode: 'difference',
                }}
              >
                {pct}%
              </span>
            </button>
          )}

          {!verified && !verifying && !downloading && !failed && (
            <button
              onClick={onDownload}
              style={{
                background: 'transparent',
                border: 'none',
                color: 'var(--text)',
                fontSize: 16,
                fontWeight: 600,
                cursor: 'pointer',
                padding: 0,
                borderRadius: 999,
                backgroundColor: 'var(--surface-alt)',
                width: 110,
                height: 32,
                minWidth: 0,
              }}
              aria-label={`Download ${meta.name}`}
            >
              Download
            </button>
          )}

          {failed && (
            <button
              onClick={onRetry}
              style={{
                background: 'transparent',
                border: 'none',
                color: 'var(--scam)',
                fontSize: 16,
                fontWeight: 600,
                cursor: 'pointer',
                padding: 0,
                borderRadius: 999,
                backgroundColor: 'var(--scam-bg)',
                width: 110,
                height: 32,
                minWidth: 0,
              }}
              aria-label={`Retry downloading ${meta.name}`}
            >
              Retry
            </button>
          )}
        </div>
      </div>

      {failed && (
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: 6,
            color: 'var(--scam)',
            fontSize: 13,
          }}
          role="alert"
        >
          <ErrorIcon size={16} />
          <span>{status.reason}</span>
        </div>
      )}
    </div>
  )
}
