'use client'

import { useState, useCallback } from 'react'
import { getGemmaPlugin } from '@/lib/gemma'
import { useTokenStream } from '@/hooks/useTokenStream'
import { useGemScanStore } from '@/lib/store'
import { useLocale } from '@/lib/i18n/strings'
import type { AgentTask, AgentResult } from '@/lib/gemma/types'
import ScamWarningCard from '@/components/ScamWarningCard'
import StreamingReasoningView from '@/components/StreamingReasoningView'

export default function AnalysePage() {
  const [input, setInput] = useState('')
  const [taskId, setTaskId] = useState<string | null>(null)
  const [result, setResult] = useState<AgentResult | null>(null)
  const [isAnalysing, setIsAnalysing] = useState(false)
  const addResult = useGemScanStore((s) => s.addResult)
  const trustedContactId = useGemScanStore((s) => s.trustedContactId)
  const { t } = useLocale()

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
    setResult(null)
    setTaskId(null)
    setInput('')
  }, [])

  const handleShare = useCallback(() => {
    if (trustedContactId && result) {
      // In a real app this would send to the trusted contact
      console.log(`Sharing result ${result.taskId} with contact ${trustedContactId}`)
    }
  }, [trustedContactId, result])

  return (
    <main className="flex min-h-screen flex-col items-center px-6 py-12">
      <h1 className="text-2xl font-bold mb-6">{t('analyseMessage')}</h1>

      <textarea
        value={input}
        onChange={(e) => setInput(e.target.value)}
        placeholder={t('pastePrompt')}
        className="w-full max-w-md rounded-lg border p-4 text-base resize-none h-32"
        disabled={isAnalysing}
        aria-label={t('pastePrompt')}
      />

      <button
        onClick={handleSubmit}
        disabled={isAnalysing || !input.trim()}
        aria-label={isAnalysing ? t('analysing') : t('analyse')}
        className="mt-4 rounded-xl bg-blue-500 px-8 py-4 text-white font-semibold text-lg disabled:opacity-50 min-h-[44px] min-w-[44px]"
      >
        {isAnalysing ? t('analysing') : t('analyse')}
      </button>

      {(isStreaming || (tokens && !isDone)) && (
        <div className="mt-6 w-full max-w-md">
          <StreamingReasoningView tokens={tokens} isDone={isDone} />
        </div>
      )}

      {result && (
        <div className="mt-6 w-full flex justify-center">
          <ScamWarningCard result={result} onDismiss={handleDismiss} onShare={handleShare} />
        </div>
      )}
    </main>
  )
}
