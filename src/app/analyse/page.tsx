'use client'

import { useState, useCallback } from 'react'
import { useRouter } from 'next/navigation'
import { getGemmaPlugin } from '@/lib/gemma'
import { makeConservativeResult } from '@/lib/gemma/error-handler'
import { useTokenStream } from '@/hooks/useTokenStream'
import { useGemScanStore } from '@/lib/store'
import type { AgentTask, AgentTaskType, AgentResult } from '@/lib/gemma/types'
import VerdictCard from '@/components/VerdictCard'
import StreamingText from '@/components/StreamingText'

const URL_PATTERN = /^https?:\/\/|^www\./i

function detectTaskType(input: string): AgentTaskType {
  if (URL_PATTERN.test(input.trim())) return 'checkURL'
  if (input.includes('@') && input.includes('Subject:')) return 'classifyEmail'
  return 'classifySMS'
}

function buildPayload(input: string, taskType: AgentTaskType) {
  if (taskType === 'checkURL') {
    return { type: 'url' as const, url: input.trim() }
  }
  return { type: 'text' as const, content: input }
}

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
      const taskType = detectTaskType(input)
      const task: AgentTask = {
        id,
        type: taskType,
        payload: buildPayload(input, taskType),
        priority: 'realtime',
        createdAt: Date.now(),
        timeoutMs: 10000,
      }

      const analysisResult = await plugin.analyse(task)
      setResult(analysisResult)
      addResult(analysisResult)
    } catch (err) {
      const fallback = makeConservativeResult(id, err)
      setResult(fallback)
      addResult(fallback)
    } finally {
      setIsAnalysing(false)
    }
  }, [input, isAnalysing, addResult])

  const handleDismiss = useCallback(() => {
    router.push('/')
  }, [router])

  const handleShare = useCallback(() => {
    if (trustedContactId && result) {
      // Native: will invoke Capacitor share plugin
      // Web mock: log to console
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
        paddingBottom: 100,
      }}
    >
      <textarea
        className="text-body"
        value={input}
        onChange={(e) => setInput(e.target.value)}
        placeholder="Paste a message, URL, or email to check..."
        disabled={isAnalysing}
        aria-label="Content to check"
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

      <button className="btn-primary" onClick={handleSubmit} disabled={isAnalysing || !input.trim()}>
        {isAnalysing ? 'Analysing...' : 'Check this'}
      </button>

      {(isStreaming || (tokens && !isDone)) && <StreamingText tokens={tokens} isDone={isDone} />}

      {result && <VerdictCard result={result} onShare={handleShare} onDismiss={handleDismiss} />}
    </main>
  )
}
