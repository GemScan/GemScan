'use client'

import { useState, useEffect, useRef, useCallback } from 'react'
import { getGemmaPlugin } from '@/lib/gemma'
import type { PluginListenerHandle } from '@/lib/gemma/types'

export function useModelDownload() {
  const [progress, setProgress] = useState<Map<string, number>>(new Map())
  const [isDownloading, setIsDownloading] = useState(false)
  const handleRef = useRef<PluginListenerHandle | null>(null)

  useEffect(() => {
    let cancelled = false

    getGemmaPlugin().then((plugin) => {
      if (cancelled) return

      plugin
        .addListener('downloadProgress', (data) => {
          if (cancelled) return

          setIsDownloading(true)
          setProgress((prev) => {
            const next = new Map(prev)
            next.set(data.modelId, data.progress)
            return next
          })

          if (data.progress >= 1) {
            // Check if all known models are complete
            setProgress((prev) => {
              const allDone = Array.from(prev.values()).every((p) => p >= 1)
              if (allDone) {
                setIsDownloading(false)
              }
              return prev
            })
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
  }, [])

  const reset = useCallback(() => {
    setProgress(new Map())
    setIsDownloading(false)
  }, [])

  return { progress, isDownloading, reset }
}
