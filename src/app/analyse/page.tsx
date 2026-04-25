'use client'

import { useState, useCallback } from 'react'
import { useRouter } from 'next/navigation'
import { getGemmaPlugin } from '@/lib/gemma'
import { useTokenStream } from '@/hooks/useTokenStream'
import { useGemScanStore } from '@/lib/store'
import type { AgentTask, AgentResult } from '@/lib/gemma/types'
import VerdictCard from '@/components/VerdictCard'
import StreamingText from '@/components/StreamingText'

export default function AnalysePage() {
  const router = useRouter()

  const [input, setInput] = useState('')
  const [taskId, setTaskId] = useState<string | null>(null)
  const [result, setResult] = useState<AgentResult | null>(null)
  const [isAnalysing, setIsAnalysing] = useState(false)
  const addResult = useGemScanStore((s) => s.addResult)
  const trustedContactId = useGemScanStore((s) => s.trustedContactId)

  const { tokens, isStreaming, isDone } = useTokenStream(taskId)

  const handleSubmit = useCallback(async () => {
    if (!input.trim() || isAnalysing) return

    const id = `task-${Date.now()}`
    setTaskId(id)
    setResult(null)
    setIsAnalysing(true)

    try {
      const plugin = await getGemmaPlugin()
      const task: AgentTask = {
        id,
        type: 'classifySMS',
        payload: { type: 'text', content: input },
        priority: 'realtime',
        createdAt: Date.now(),
        timeoutMs: 10000,
      }

      const analysisResult = await plugin.analyse(task)
      setResult(analysisResult)
      addResult(analysisResult)
    } catch {
      // On error, leave result null so user can retry
    } finally {
      setIsAnalysing(false)
    }
  }, [input, isAnalysing, addResult])

  const handleDismiss = useCallback(() => {
    router.push('/')
  }, [router])

  const handleShare = useCallback(() => {
    if (trustedContactId && result) {
      console.log(`Sharing result ${result.taskId} with contact ${trustedContactId}`)
    }
  }, [trustedContactId, result])

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
      <button
        className="text-body"
        onClick={() => router.back()}
        style={{
          color: 'var(--text)',
          background: 'none',
          border: 'none',
          padding: '8px 0',
          cursor: 'pointer',
          alignSelf: 'flex-start',
          minHeight: 44,
          minWidth: 44,
        }}
      >
        ← Back
      </button>

      <textarea
        className="text-body"
        value={input}
        onChange={(e) => setInput(e.target.value)}
        placeholder="Paste a message to check…"
        disabled={isAnalysing}
        style={{
          height: 'var(--height-input)',
          border: '1px solid var(--border)',
          borderRadius: 'var(--radius-input)',
          padding: 16,
          resize: 'none',
          width: '100%',
          backgroundColor: 'var(--surface)',
          color: 'var(--text)',
        }}
      />

      <button
        className="btn-primary"
        onClick={handleSubmit}
        disabled={isAnalysing || !input.trim()}
      >
        {isAnalysing ? 'Analysing…' : 'Check this'}
      </button>

      {(isStreaming || (tokens && !isDone)) && <StreamingText tokens={tokens} isDone={isDone} />}

      {result && <VerdictCard result={result} onShare={handleShare} onDismiss={handleDismiss} />}
    </main>
  )
}
