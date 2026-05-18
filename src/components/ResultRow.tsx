'use client'

import type { ScamVerdict } from '@/lib/gemma/types'

interface ResultRowProps {
  input: string
  verdict: ScamVerdict
  /// Unix-ms timestamp when the result was saved. `0` (legacy entries
  /// that pre-date the timestamp feature) or `undefined` renders no
  /// caption — never a placeholder like "Unknown date".
  timestamp?: number
  onClick: () => void
}

const pillMap = {
  safe: { label: 'Safe', color: 'var(--safe)', bg: 'var(--safe-bg)' },
  suspicious: { label: 'Suspicious', color: 'var(--suspicious)', bg: 'var(--suspicious-bg)' },
  scam: { label: 'Scam', color: 'var(--scam)', bg: 'var(--scam-bg)' },
} as const

export default function ResultRow({ input, verdict, timestamp, onClick }: ResultRowProps) {
  const pill = pillMap[verdict]
  const truncated = input.length > 40 ? input.slice(0, 40) + '…' : input
  const timeLabel = timestamp ? formatTimeAgo(timestamp) : ''

  return (
    <button
      onClick={onClick}
      style={{
        width: '100%',
        // Card surface — same tokens used by the Learn-page accordion
        // and the verdict card so every list item reads as a tappable
        // tile rather than a flush row.
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        gap: 'var(--gap-element)',
        backgroundColor: 'var(--surface-alt)',
        border: '1px solid var(--border)',
        borderRadius: 'var(--radius-card)',
        padding: '12px 16px',
        minHeight: 'var(--height-row)',
        cursor: 'pointer',
        color: 'var(--text)',
        textAlign: 'left',
      }}
    >
      <span
        style={{
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'flex-start',
          gap: 2,
          minWidth: 0,
          flex: 1,
          textAlign: 'left',
        }}
      >
        <span className="text-body" style={{ textAlign: 'left' }}>
          {truncated}
        </span>
        {timeLabel && (
          <span className="text-caption" style={{ color: 'var(--text-muted)' }}>
            {timeLabel}
          </span>
        )}
      </span>
      <span
        className="text-caption"
        style={{
          color: pill.color,
          backgroundColor: pill.bg,
          padding: '2px 8px',
          borderRadius: 'var(--radius-button)',
          textTransform: 'capitalize',
          flexShrink: 0,
        }}
      >
        {pill.label}
      </span>
    </button>
  )
}

/// Renders a Unix-ms timestamp as a short relative label suitable for a
/// history row: "Just now", "12 min ago", "3 hr ago", "2 days ago", and
/// then absolute date for anything older than a week. Returns `''` for
/// 0 / negative inputs so legacy entries render no caption.
export function formatTimeAgo(ms: number): string {
  if (!ms || ms <= 0) return ''
  const diff = Date.now() - ms
  if (diff < 0) return 'Just now'
  const seconds = Math.floor(diff / 1000)
  if (seconds < 60) return 'Just now'
  const minutes = Math.floor(seconds / 60)
  if (minutes < 60) return `${minutes} min ago`
  const hours = Math.floor(minutes / 60)
  if (hours < 24) return `${hours} hr${hours === 1 ? '' : 's'} ago`
  const days = Math.floor(hours / 24)
  if (days < 7) return `${days} day${days === 1 ? '' : 's'} ago`
  return new Date(ms).toLocaleDateString(undefined, {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
  })
}
