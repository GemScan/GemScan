'use client'

import { useState, useCallback, useEffect, useRef } from 'react'
import { useRouter } from 'next/navigation'
import { getGemmaPlugin } from '@/lib/gemma'
import { makeConservativeResult } from '@/lib/gemma/error-handler'
import { useTokenStream } from '@/hooks/useTokenStream'
import { useGemScanStore } from '@/lib/store'
import type {
  AgentTask,
  AgentTaskType,
  AgentResult,
  AgentPayload,
} from '@/lib/gemma/types'
import VerdictCard from '@/components/VerdictCard'
import StreamingText from '@/components/StreamingText'

const URL_PATTERN = /^https?:\/\/|^www\./i
const PENDING_IMAGE_KEY = 'gemscan.pendingImage'

interface PendingImage {
  base64: string
  mimeType: 'image/jpeg' | 'image/png'
  previewDataURL: string
}

function detectTaskType(input: string): AgentTaskType {
  if (URL_PATTERN.test(input.trim())) return 'checkURL'
  if (input.includes('@') && input.includes('Subject:')) return 'classifyEmail'
  return 'classifySMS'
}

function buildTextPayload(input: string, taskType: AgentTaskType): AgentPayload {
  if (taskType === 'checkURL') {
    return { type: 'url', url: input.trim() }
  }
  return { type: 'text', content: input }
}

export default function AnalysePage() {
  const router = useRouter()

  const [input, setInput] = useState('')
  const [taskId, setTaskId] = useState<string | null>(null)
  const [result, setResult] = useState<AgentResult | null>(null)
  const [isAnalysing, setIsAnalysing] = useState(false)
  const [pendingImage, setPendingImage] = useState<PendingImage | null>(null)
  const addResult = useGemScanStore((s) => s.addResult)
  const trustedContactId = useGemScanStore((s) => s.trustedContactId)

  const { tokens, isDone } = useTokenStream(taskId)

  const isAnalysingRef = useRef(false)

  const runAnalysis = useCallback(
    async (task: AgentTask) => {
      if (isAnalysingRef.current) return

      setTaskId(task.id)
      setResult(null)
      setIsAnalysing(true)
      isAnalysingRef.current = true

      try {
        const plugin = await getGemmaPlugin()
        const analysisResult = await plugin.analyse(task)
        setResult(analysisResult)
        addResult(analysisResult)
      } catch (err) {
        // Pull the original input back out of the task payload so the
        // fallback card can still echo it. Image tasks have no OCR'd
        // text on this path (the model didn't run), so we leave
        // analyzedText undefined for those.
        const fallbackInput =
          task.payload.type === 'text'
            ? task.payload.content
            : task.payload.type === 'url'
              ? task.payload.url
              : undefined
        const fallback = makeConservativeResult(task.id, err, fallbackInput)
        setResult(fallback)
        addResult(fallback)
      } finally {
        setIsAnalysing(false)
        isAnalysingRef.current = false
      }
    },
    [addResult]
  )

  const runTextAnalysis = useCallback(
    (text: string) => {
      if (!text.trim()) return
      const taskType = detectTaskType(text)
      const task: AgentTask = {
        id: `task-${Date.now()}`,
        type: taskType,
        payload: buildTextPayload(text, taskType),
        priority: 'realtime',
        createdAt: Date.now(),
        // On-device gen for ~80 tokens at ~10-15 tok/s plus prompt processing
        // can run 10-20s on a warm model, so allow generous headroom.
        timeoutMs: 60000,
      }
      void runAnalysis(task)
    },
    [runAnalysis]
  )

  const runImageAnalysis = useCallback(
    (image: PendingImage) => {
      const task: AgentTask = {
        id: `task-${Date.now()}`,
        type: 'analyseScreenshot',
        payload: {
          type: 'image',
          base64: image.base64,
          mimeType: image.mimeType,
        },
        priority: 'realtime',
        createdAt: Date.now(),
        // Vision-tower passes add a few seconds on top of the text-only
        // budget — give multimodal generation more room than text.
        timeoutMs: 90000,
      }
      void runAnalysis(task)
    },
    [runAnalysis]
  )

  const handleSubmit = useCallback(() => {
    runTextAnalysis(input)
  }, [input, runTextAnalysis])

  // Bootstrap from query params and sessionStorage when navigating in from
  // the home screen. `?q=...` triggers text analysis; `?type=image` reads
  // the pending image payload stashed by the home upload button.
  useEffect(() => {
    if (typeof window === 'undefined') return
    const params = new URLSearchParams(window.location.search)

    if (params.get('type') === 'image') {
      const raw = sessionStorage.getItem(PENDING_IMAGE_KEY)
      if (!raw) return
      sessionStorage.removeItem(PENDING_IMAGE_KEY)
      try {
        const image = JSON.parse(raw) as PendingImage
        if (image.base64 && image.previewDataURL) {
          setPendingImage(image)
          runImageAnalysis(image)
        }
      } catch {
        // Corrupted payload — fall through to the empty text-input state.
      }
      return
    }

    const q = params.get('q')
    if (!q || !q.trim()) return
    setInput(q)
    runTextAnalysis(q)
    // Run once on mount; the run* callbacks are stable across re-renders.
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
      {pendingImage ? (
        // We deliberately don't render the user's screenshot here —
        // pictures shared into GemScan often contain sensitive content
        // (bank balances, addresses, IDs) and there's no need to show
        // it back to them on a screen anyone behind them can see. A
        // status caption is enough to confirm the upload landed.
        <div
          style={{
            display: 'flex',
            flexDirection: 'column',
            gap: 'var(--gap-element)',
            alignItems: 'center',
            padding: 'var(--gap-element) 0',
          }}
        >
          <p className="text-body" style={{ color: 'var(--text)' }}>
            {isAnalysing ? 'Analyzing your image…' : 'Image analyzed.'}
          </p>
        </div>
      ) : (
        <>
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

          <button
            className="btn-primary"
            onClick={handleSubmit}
            disabled={isAnalysing || !input.trim()}
          >
            {isAnalysing ? 'Analysing...' : 'Check this'}
          </button>
        </>
      )}

      {(tokens || result) && (
        <div className="page-scroll">
          {tokens && !result && <StreamingText tokens={tokens} isDone={isDone} />}
          {result && <VerdictCard result={result} onShare={handleShare} onDismiss={handleDismiss} />}
        </div>
      )}
    </main>
  )
}
