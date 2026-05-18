'use client'

import { useMemo, useState } from 'react'
import { useGemScanStore, type StoredResult } from '@/lib/store'
import ResultRow, { formatTimeAgo } from '@/components/ResultRow'
import VerdictCard from '@/components/VerdictCard'

export default function HistoryPage() {
  const recentResults = useGemScanStore((s) => s.recentResults)
  const clearResults = useGemScanStore((s) => s.clearResults)
  const trustedContactId = useGemScanStore((s) => s.trustedContactId)

  const [confirmingClear, setConfirmingClear] = useState(false)
  // Detail mode is fully client-side state; we deliberately don't push a
  // URL param for the open result so the tab's deep-link target stays
  // the list view and a Capacitor cold launch / Cmd+R always opens to
  // the same place. Tapping a row swaps the page contents in-place.
  const [detailEntry, setDetailEntry] = useState<StoredResult | null>(null)

  const hasHistory = recentResults.length > 0

  const metrics = useMemo(() => computeMetrics(recentResults), [recentResults])

  const handleConfirmClear = () => {
    clearResults()
    setConfirmingClear(false)
  }

  if (detailEntry) {
    return (
      <DetailView
        entry={detailEntry}
        trustedContactId={trustedContactId}
        onBack={() => setDetailEntry(null)}
      />
    )
  }

  return (
    <main className="page">
      <div
        style={{
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          gap: 'var(--gap-element)',
        }}
      >
        <h1 className="text-title" style={{ color: 'var(--text)' }}>
          History
        </h1>
        {hasHistory && !confirmingClear && (
          <button
            onClick={() => setConfirmingClear(true)}
            aria-label="Clear all history"
            style={{
              background: 'none',
              border: 'none',
              cursor: 'pointer',
              color: 'var(--scam)',
              fontFamily: 'inherit',
              fontSize: '0.882rem',
              fontWeight: 500,
              padding: '6px 4px',
              minHeight: 32,
            }}
          >
            Clear
          </button>
        )}
      </div>

      {confirmingClear && (
        <div
          role="alertdialog"
          aria-labelledby="confirm-clear-title"
          style={{
            display: 'flex',
            flexDirection: 'column',
            gap: 'var(--gap-element)',
            padding: 16,
            borderRadius: 'var(--radius-card)',
            border: '1px solid var(--border)',
            backgroundColor: 'var(--surface-alt)',
          }}
        >
          <div style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
            <span
              id="confirm-clear-title"
              className="text-heading"
              style={{ color: 'var(--text)' }}
            >
              Clear all history?
            </span>
            <span className="text-body" style={{ color: 'var(--text-muted)' }}>
              This removes every check on this device. You can&apos;t undo this.
            </span>
          </div>
          <div style={{ display: 'flex', gap: 'var(--gap-element)' }}>
            <button
              onClick={() => setConfirmingClear(false)}
              style={{
                flex: 1,
                minHeight: 44,
                borderRadius: 'var(--radius-button)',
                border: '1px solid var(--border)',
                backgroundColor: 'var(--surface)',
                color: 'var(--text)',
                fontFamily: 'inherit',
                fontSize: '1rem',
                fontWeight: 500,
                cursor: 'pointer',
              }}
            >
              Cancel
            </button>
            <button
              onClick={handleConfirmClear}
              style={{
                flex: 1,
                minHeight: 44,
                borderRadius: 'var(--radius-button)',
                border: 'none',
                backgroundColor: 'var(--scam)',
                color: '#ffffff',
                fontFamily: 'inherit',
                fontSize: '1rem',
                fontWeight: 600,
                cursor: 'pointer',
              }}
            >
              Delete
            </button>
          </div>
        </div>
      )}

      {hasHistory && (
        <div style={{ display: 'flex', gap: 'var(--gap-element)' }}>
          <MetricCard period="This month" analyses={metrics.month.analyses} scams={metrics.month.scams} />
          <MetricCard period="This year" analyses={metrics.year.analyses} scams={metrics.year.scams} />
        </div>
      )}

      {hasHistory ? (
        <div className="page-scroll" style={{ gap: 'var(--gap-element)' }}>
          {recentResults.map((entry) => (
            <ResultRow
              key={entry.result.taskId}
              input={firstLine(entry.result.reasoning[0]) ?? entry.result.taskId}
              verdict={entry.result.verdict}
              timestamp={entry.savedAt}
              onClick={() => setDetailEntry(entry)}
            />
          ))}
        </div>
      ) : (
        <p className="text-body" style={{ color: 'var(--text-muted)' }}>
          No checks yet. Scan a message to get started.
        </p>
      )}
    </main>
  )
}

/// Detail view rendered when a history row is tapped. Re-uses the
/// `VerdictCard` the live `/analyse` flow renders so the user sees the
/// exact same layout for a revisited result as they did the first time.
/// Back button + dismiss button both fall back to the list view via
/// the parent's `onBack` callback.
function DetailView({
  entry,
  trustedContactId,
  onBack,
}: {
  entry: StoredResult
  trustedContactId: string | null
  onBack: () => void
}) {
  const handleShare = () => {
    if (trustedContactId) {
      // Same console-log behaviour as the live analyse page until the
      // native share plugin is wired in. Revisited results share the
      // same trusted-contact destination as fresh ones.
      console.log(`Sharing result ${entry.result.taskId} with contact ${trustedContactId}`)
    }
  }

  const timeLabel = formatTimeAgo(entry.savedAt)

  return (
    <main className="page">
      <button
        onClick={onBack}
        aria-label="Back to history"
        style={{
          color: 'var(--text)',
          background: 'none',
          border: 'none',
          padding: '8px 0',
          cursor: 'pointer',
          alignSelf: 'flex-start',
          minHeight: 44,
          minWidth: 44,
          fontFamily: 'inherit',
          fontSize: '1rem',
        }}
      >
        ← Back
      </button>

      <div className="page-scroll">
        {timeLabel && (
          <span
            className="text-caption"
            style={{ color: 'var(--text-muted)', marginBottom: -8 }}
          >
            Analyzed {timeLabel}
          </span>
        )}
        <VerdictCard result={entry.result} onShare={handleShare} onDismiss={onBack} />
      </div>
    </main>
  )
}

/// First line of the reasoning bullet, trimmed. Falls back to `undefined`
/// if the bullet is missing (we let the caller substitute the taskId).
/// Used to keep multi-line reasoning compact in the row preview.
function firstLine(text: string | undefined): string | undefined {
  if (!text) return undefined
  const newlineIndex = text.indexOf('\n')
  return newlineIndex >= 0 ? text.slice(0, newlineIndex).trim() : text.trim()
}

interface PeriodMetrics {
  analyses: number
  scams: number
}

interface HistoryMetrics {
  month: PeriodMetrics
  year: PeriodMetrics
}

/// Computes "this month" and "this year" totals against the local
/// timezone. Entries with `savedAt: 0` (legacy pre-timestamp rows) are
/// excluded from both buckets — we can't place them on a calendar and
/// padding them into the month / year window would inflate the totals.
/// Counts every result as an analysis; "scams" is the strict-`'scam'`
/// verdict subset (suspicious verdicts aren't included because they're
/// flagged-as-uncertain, not detected scams).
function computeMetrics(entries: StoredResult[]): HistoryMetrics {
  const now = new Date()
  const currentMonth = now.getMonth()
  const currentYear = now.getFullYear()

  const month: PeriodMetrics = { analyses: 0, scams: 0 }
  const year: PeriodMetrics = { analyses: 0, scams: 0 }

  for (const entry of entries) {
    if (!entry.savedAt) continue
    const d = new Date(entry.savedAt)
    if (d.getFullYear() !== currentYear) continue

    const isScam = entry.result.verdict === 'scam'
    year.analyses += 1
    if (isScam) year.scams += 1

    if (d.getMonth() === currentMonth) {
      month.analyses += 1
      if (isScam) month.scams += 1
    }
  }

  return { month, year }
}

/// Compact summary tile rendered at the top of the History page. Two
/// instances sit side-by-side ("This month" and "This year"). Each tile
/// shows a period label, then two columns: analyses count and scams
/// count. The scams number turns red whenever it's non-zero so a
/// quick glance signals "there were scams this month/year" without
/// having to read the label.
function MetricCard({
  period,
  analyses,
  scams,
}: {
  period: string
  analyses: number
  scams: number
}) {
  return (
    <div
      style={{
        flex: 1,
        minWidth: 0,
        padding: 12,
        borderRadius: 'var(--radius-card)',
        border: '1px solid var(--border)',
        backgroundColor: 'var(--surface-alt)',
        display: 'flex',
        flexDirection: 'column',
        gap: 8,
      }}
    >
      <span
        className="text-caption"
        style={{
          color: 'var(--text-muted)',
          textTransform: 'uppercase',
          letterSpacing: 0.4,
          fontWeight: 600,
        }}
      >
        {period}
      </span>
      <div style={{ display: 'flex', gap: 'var(--gap-element)' }}>
        <Stat label="Analyses" value={analyses} />
        <Stat label="Scams" value={scams} accent={scams > 0 ? 'var(--scam)' : 'var(--text)'} />
      </div>
    </div>
  )
}

function Stat({
  label,
  value,
  accent = 'var(--text)',
}: {
  label: string
  value: number
  accent?: string
}) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 2, minWidth: 0 }}>
      <span
        className="text-title"
        style={{ color: accent, lineHeight: 1, fontSize: '1.5rem' }}
      >
        {value}
      </span>
      <span className="text-caption" style={{ color: 'var(--text-muted)' }}>
        {label}
      </span>
    </div>
  )
}
