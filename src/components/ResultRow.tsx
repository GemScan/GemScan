'use client'

import type { ScamVerdict } from '@/lib/gemma/types'

interface ResultRowProps {
  input: string
  verdict: ScamVerdict
  onClick: () => void
}

const pillMap = {
  safe: { label: 'Safe', color: 'var(--safe)', bg: 'var(--safe-bg)' },
  suspicious: { label: 'Suspicious', color: 'var(--suspicious)', bg: 'var(--suspicious-bg)' },
  scam: { label: 'Scam', color: 'var(--scam)', bg: 'var(--scam-bg)' },
} as const

export default function ResultRow({ input, verdict, onClick }: ResultRowProps) {
  const pill = pillMap[verdict]
  const truncated = input.length > 40 ? input.slice(0, 40) + '…' : input

  return (
    <button
      onClick={onClick}
      style={{
        width: '100%',
        height: 'var(--height-row)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        background: 'none',
        border: 'none',
        padding: '0 var(--gap-element)',
        cursor: 'pointer',
        color: 'var(--text)',
      }}
    >
      <span className="text-body" style={{ textAlign: 'left' }}>
        {truncated}
      </span>
      <span
        className="text-caption"
        style={{
          color: pill.color,
          backgroundColor: pill.bg,
          padding: '2px 8px',
          borderRadius: 'var(--radius-button)',
          textTransform: 'capitalize',
        }}
      >
        {pill.label}
      </span>
    </button>
  )
}
