'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { useGemScanStore } from '@/lib/store'
import InputArea from '@/components/InputArea'
import ResultRow from '@/components/ResultRow'

export default function HomePage() {
  const router = useRouter()
  const recentResults = useGemScanStore((s) => s.recentResults)
  const [input, setInput] = useState('')

  const handleSubmit = () => {
    if (!input.trim()) return
    router.push(`/analyse?q=${encodeURIComponent(input.trim())}`)
  }

  return (
    <main
      style={{
        display: 'flex',
        flexDirection: 'column',
        padding: 'var(--padding-page)',
        gap: 'var(--gap-section)',
        minHeight: '100vh',
      }}
    >
      <div
        style={{
          display: 'flex',
          justifyContent: 'flex-end',
          alignItems: 'center',
          minHeight: 44,
        }}
      >
        <button
          className="text-body"
          onClick={() => router.push('/settings')}
          style={{
            color: 'var(--text-muted)',
            background: 'none',
            border: 'none',
            cursor: 'pointer',
            padding: '8px 0',
          }}
          aria-label="Settings"
        >
          Settings
        </button>
      </div>

      <h1 className="text-title" style={{ color: 'var(--text)', textAlign: 'center' }}>
        GemScan
      </h1>

      <p className="text-body" style={{ color: 'var(--text-muted)', textAlign: 'center' }}>
        What would you like me to check?
      </p>

      <InputArea
        value={input}
        onChange={setInput}
        onSubmit={handleSubmit}
        placeholder="Paste a message to check…"
      />

      <button
        className="btn-secondary"
        onClick={() => {
          /* TODO: scan image */
        }}
      >
        Scan image
      </button>

      <hr className="divider" />

      <h2 className="text-heading" style={{ color: 'var(--text)' }}>
        Recent checks
      </h2>

      {recentResults.length > 0 ? (
        <div style={{ display: 'flex', flexDirection: 'column' }}>
          {recentResults.map((result) => (
            <ResultRow
              key={result.taskId}
              input={result.taskId}
              verdict={result.verdict}
              onClick={() => {
                /* noop for now */
              }}
            />
          ))}
        </div>
      ) : (
        <p className="text-caption" style={{ color: 'var(--text-muted)' }}>
          No checks yet.
        </p>
      )}
    </main>
  )
}
