'use client'

interface ProgressRowProps {
  label: string
  progress: number
  totalSize: string
}

export default function ProgressRow({ label, progress, totalSize }: ProgressRowProps) {
  const pct = Math.round(progress * 100)

  return (
    <div>
      <div
        style={{
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
        }}
      >
        <span className="text-body">{label}</span>
        <span className="text-caption" style={{ color: 'var(--text-muted)' }}>
          {totalSize}
        </span>
      </div>

      <div
        role="progressbar"
        aria-valuenow={pct}
        aria-valuemin={0}
        aria-valuemax={100}
        aria-valuetext={`${label}: ${pct}% of ${totalSize}`}
        style={{
          width: '100%',
          height: 'var(--bar-height)',
          backgroundColor: 'var(--border)',
          borderRadius: 'var(--radius-card)',
          marginTop: 'var(--gap-element)',
        }}
      >
        <div
          style={{
            width: `${pct}%`,
            height: '100%',
            backgroundColor: 'var(--text)',
            borderRadius: 'var(--radius-card)',
          }}
        />
      </div>
    </div>
  )
}
