'use client'

import { useGemScanStore } from '@/lib/store'
import ResultRow from '@/components/ResultRow'

export default function HistoryPage() {
  const recentResults = useGemScanStore((s) => s.recentResults)
  const clearResults = useGemScanStore((s) => s.clearResults)

  return (
    <main className="page">
      <h1 className="text-title" style={{ color: 'var(--text)' }}>
        History
      </h1>

      {recentResults.length > 0 ? (
        <>
          <div
            className="page-scroll"
            style={{ gap: 0 }}
          >
            {recentResults.map((result) => (
              <ResultRow
                key={result.taskId}
                input={result.reasoning[0] ?? result.taskId}
                verdict={result.verdict}
                onClick={() => {
                  /* TODO: show detail */
                }}
              />
            ))}
          </div>

          <button className="btn-secondary" onClick={clearResults} aria-label="Clear all history">
            Clear history
          </button>
        </>
      ) : (
        <p className="text-body" style={{ color: 'var(--text-muted)' }}>
          No checks yet. Scan a message to get started.
        </p>
      )}
    </main>
  )
}
