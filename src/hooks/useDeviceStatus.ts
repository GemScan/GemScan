'use client'

import { useEffect, useState } from 'react'
import { getGemmaPlugin } from '@/lib/gemma'
import type { DeviceStatus } from '@/lib/gemma/types'

const DEFAULT_POLL_MS = 5000

/// Polls the native plugin for current device status (loaded models, memory,
/// thermal, battery). Returns the latest snapshot or `null` while loading.
export function useDeviceStatus(pollIntervalMs: number = DEFAULT_POLL_MS) {
  const [status, setStatus] = useState<DeviceStatus | null>(null)

  useEffect(() => {
    let cancelled = false
    let timer: ReturnType<typeof setTimeout> | null = null

    async function tick() {
      try {
        const plugin = await getGemmaPlugin()
        const next = await plugin.getDeviceStatus()
        if (!cancelled) setStatus(next)
      } catch {
        if (!cancelled) setStatus(null)
      }
      if (!cancelled) {
        timer = setTimeout(tick, pollIntervalMs)
      }
    }

    tick()

    return () => {
      cancelled = true
      if (timer) clearTimeout(timer)
    }
  }, [pollIntervalMs])

  return status
}
