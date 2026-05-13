'use client'

import { useState, useEffect, useRef, useCallback } from 'react'
import { getGemmaPlugin } from '@/lib/gemma'
import type { DeviceStatus } from '@/lib/gemma/types'

function formatBytes(bytes: number): string {
  const mb = bytes / (1024 * 1024)
  if (mb >= 1024) return `${(mb / 1024).toFixed(1)} GB`
  return `${Math.round(mb)} MB`
}

export default function DebugOverlay() {
  const [visible, setVisible] = useState(false)
  const [status, setStatus] = useState<DeviceStatus | null>(null)
  const tapTimesRef = useRef<number[]>([])

  const handleTripleTap = useCallback(() => {
    const now = Date.now()
    tapTimesRef.current.push(now)
    // Keep only the last 3 taps
    tapTimesRef.current = tapTimesRef.current.slice(-3)

    if (tapTimesRef.current.length === 3) {
      const elapsed = tapTimesRef.current[2] - tapTimesRef.current[0]
      if (elapsed < 800) {
        setVisible((prev) => !prev)
        tapTimesRef.current = []
      }
    }
  }, [])

  useEffect(() => {
    if (!visible) return

    let cancelled = false

    const refresh = async () => {
      try {
        const plugin = await getGemmaPlugin()
        const s = await plugin.getDeviceStatus()
        if (!cancelled) setStatus(s)
      } catch {
        // ignore
      }
    }

    refresh()
    const interval = setInterval(refresh, 2000)

    return () => {
      cancelled = true
      clearInterval(interval)
    }
  }, [visible])

  if (process.env.NODE_ENV !== 'development') return null

  return (
    <>
      <div
        onClick={handleTripleTap}
        className="fixed top-2 left-2 w-10 h-10 z-50"
        aria-hidden="true"
      />

      {visible && status && (
        <div
          className="fixed bottom-0 left-0 right-0 z-50 bg-black/90 text-green-400 text-xs font-mono p-4 space-y-1"
          role="complementary"
          aria-label="Debug overlay"
        >
          <div className="flex justify-between items-center mb-2">
            <span className="font-bold text-sm">Debug</span>
            <button
              onClick={() => setVisible(false)}
              aria-label="Close debug overlay"
              className="text-white min-h-[44px] min-w-[44px] flex items-center justify-center"
            >
              &#10005;
            </button>
          </div>
          <p>RAM Available: {formatBytes(status.availableMemoryBytes)}</p>
          <p>Thermal State: {status.thermalState}</p>
          <p>Battery: {Math.round(status.batteryLevel * 100)}%</p>
          <p>E2B Loaded: {status.e2bLoaded ? 'Yes' : 'No'}</p>
          <p>Screening Mode: {status.screeningMode}</p>
        </div>
      )}
    </>
  )
}
