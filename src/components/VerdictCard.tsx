'use client'

import { useRef, useEffect } from 'react'
import type { AgentResult } from '@/lib/gemma/types'

interface VerdictCardProps {
  result: AgentResult
  onShare: () => void
  onDismiss: () => void
}

const verdictMap = {
  safe: {
    label: 'Looks safe',
    color: 'var(--safe)',
    bg: 'var(--safe-bg)',
    dismiss: 'Great!',
  },
  suspicious: {
    label: 'Be careful',
    color: 'var(--suspicious)',
    bg: 'var(--suspicious-bg)',
    dismiss: "I'll be careful",
  },
  scam: {
    label: 'This looks like a scam',
    color: 'var(--scam)',
    bg: 'var(--scam-bg)',
    dismiss: "I'll be careful",
  },
} as const

export default function VerdictCard({ result, onShare, onDismiss }: VerdictCardProps) {
  const headingRef = useRef<HTMLHeadingElement>(null)
  const v = verdictMap[result.verdict]
  const pct = Math.round(result.confidence * 100)

  useEffect(() => {
    headingRef.current?.focus()
  }, [])

  return (
    <article
      aria-label={`Verdict: ${v.label}`}
      style={{
        backgroundColor: v.bg,
        padding: 20,
        borderRadius: 'var(--radius-card)',
      }}
    >
      <h1
        ref={headingRef}
        tabIndex={-1}
        className="text-title"
        style={{ color: v.color, outline: 'none' }}
      >
        {v.label}
      </h1>

      <p
        className="text-body"
        style={{ color: 'var(--text-muted)', marginTop: 'var(--gap-element)' }}
      >
        {pct}% confident
      </p>

      <div
        role="meter"
        aria-valuenow={pct}
        aria-valuemin={0}
        aria-valuemax={100}
        aria-label={`Confidence: ${pct}%`}
        style={{
          width: '100%',
          height: 'var(--bar-height)',
          backgroundColor: 'var(--border)',
          marginTop: 'var(--gap-element)',
        }}
      >
        <div
          style={{
            width: `${pct}%`,
            height: '100%',
            backgroundColor: v.color,
          }}
        />
      </div>

      {result.reasoning.length > 0 && (
        <ul style={{ marginTop: 'var(--gap-element)', paddingLeft: 20 }}>
          {result.reasoning.map((r, i) => (
            <li key={i} className="text-body">
              {r}
            </li>
          ))}
        </ul>
      )}

      <div
        style={{
          display: 'flex',
          gap: 'var(--gap-element)',
          marginTop: 'var(--gap-section)',
        }}
      >
        {result.verdict !== 'safe' && (
          <button className="btn-primary" aria-label="Share with contact" onClick={onShare}>
            Share with contact
          </button>
        )}
        <button className="btn-secondary" aria-label={v.dismiss} onClick={onDismiss}>
          {v.dismiss}
        </button>
      </div>

      <p
        className="text-caption"
        style={{
          color: 'var(--text-muted)',
          textAlign: 'center',
          marginTop: 'var(--gap-section)',
        }}
      >
        Analysed on-device · {result.modelTier.toUpperCase()}
      </p>
    </article>
  )
}
