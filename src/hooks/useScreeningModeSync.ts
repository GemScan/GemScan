'use client'

import { useEffect } from 'react'
import { getGemmaPlugin } from '@/lib/gemma'
import { useGemScanStore } from '@/lib/store'

/// Pushes the current store-side screening mode into the native plugin
/// whenever it changes (and once on mount). The plugin uses this to choose
/// between the passive 5-min background-unload timer and the active/guardian
/// 15-min idle-unload timer.
export function useScreeningModeSync() {
  const screeningMode = useGemScanStore((s) => s.screeningMode)

  useEffect(() => {
    let cancelled = false

    async function sync() {
      try {
        const plugin = await getGemmaPlugin()
        if (!cancelled) await plugin.setScreeningMode({ mode: screeningMode })
      } catch {
        // Native plugin may not be ready on first launch — best-effort sync.
      }
    }

    sync()

    return () => {
      cancelled = true
    }
  }, [screeningMode])
}
