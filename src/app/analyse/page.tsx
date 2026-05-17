'use client'

import { useState, useCallback, useEffect, useRef } from 'react'
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

  const { tokens, isDone } = useTokenStream(taskId)

  const isAnalysingRef = useRef(false)

  const runAnalysis = useCallback(
    async (text: string) => {
      if (!text.trim() || isAnalysingRef.current) return

      const id = `task-${Date.now()}`
      setTaskId(id)
      setResult(null)
      setIsAnalysing(true)
      isAnalysingRef.current = true

      try {
        const plugin = await getGemmaPlugin()
        const taskType = detectTaskType(text)
        const task: AgentTask = {
          id,
          type: taskType,
          payload: buildPayload(text, taskType),
          priority: 'realtime',
          createdAt: Date.now(),
          // On-device gen for ~80 tokens at ~10-15 tok/s plus prompt processing
          // can run 10-20s on a warm model, so allow generous headroom.
          timeoutMs: 60000,
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
        isAnalysingRef.current = false
      }
    },
    [addResult]
  )

  const handleSubmit = useCallback(() => {
    void runAnalysis(input)
  }, [input, runAnalysis])

  // Bootstrap from ?q=... when navigating in from the home screen.
  useEffect(() => {
    if (typeof window === 'undefined') return
    const q = new URLSearchParams(window.location.search).get('q')
    if (!q || !q.trim()) return
    setInput(q)
    void runAnalysis(q)
    // Run once on mount; runAnalysis is stable across re-renders.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

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
    <main className="page">
      <textarea
        className="text-body"
        value={input}
        onChange={(e) => setInput(e.target.value)}
        placeholder="Paste a message, URL, or email to check..."
        disabled={isAnalysing}
        aria-label="Content to check"
        style={{
          height: 'var(--height-input)',
          flex: '0 0 auto',
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

      {(tokens || result) && (
        <div className="page-scroll">
          {tokens && !result && <StreamingText tokens={tokens} isDone={isDone} />}
          {result && <VerdictCard result={result} onShare={handleShare} onDismiss={handleDismiss} />}
        </div>
      )}
    </main>
  )
}
