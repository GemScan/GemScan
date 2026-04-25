'use client'

import { useState, useEffect, useRef } from 'react'
import { getGemmaPlugin } from '@/lib/gemma'
import type { PluginListenerHandle } from '@/lib/gemma/types'

export function useTokenStream(taskId: string | null) {
  const [tokens, setTokens] = useState('')
  const [isStreaming, setIsStreaming] = useState(false)
  const [isDone, setIsDone] = useState(false)
  const handleRef = useRef<PluginListenerHandle | null>(null)

  useEffect(() => {
    if (!taskId) {
      setTokens('')
      setIsStreaming(false)
      setIsDone(false)
      return
    }

    setTokens('')
    setIsStreaming(true)
    setIsDone(false)

    let cancelled = false

    getGemmaPlugin().then((plugin) => {
      if (cancelled) return

      plugin
        .addListener('tokenStream', (data) => {
          if (cancelled || data.taskId !== taskId) return

          setTokens((prev) => prev + data.token)

          if (data.done) {
            setIsStreaming(false)
            setIsDone(true)
          }
        })
        .then((handle) => {
          if (cancelled) {
            handle.remove()
          } else {
            handleRef.current = handle
          }
        })
    })

    return () => {
      cancelled = true
      handleRef.current?.remove()
      handleRef.current = null
    }
  }, [taskId])

  return { tokens, isStreaming, isDone }
}
