'use client'

import { useEffect, useRef, useState } from 'react'
import { getGemmaPlugin } from '@/lib/gemma'
import { useGemScanStore } from '@/lib/store'

/**
 * Listens for guardianModeChanged events from the native plugin
 * and syncs the state to the Zustand store.
 *
 * On iOS, this event fires when the trusted contact remotely
 * enables/disables guardian mode. In web mock mode, it can be
 * triggered via GemmaPluginMock.emitGuardianModeChanged().
 */
export function useGuardianMode() {
  const setGuardianModeEnabled = useGemScanStore((s) => s.setGuardianModeEnabled)
  const guardianModeEnabled = useGemScanStore((s) => s.guardianModeEnabled)
  const [changedBy, setChangedBy] = useState<'self' | 'trustedContact' | null>(null)
  const handleRef = useRef<{ remove: () => void } | null>(null)

  useEffect(() => {
    let cancelled = false

    getGemmaPlugin().then((plugin) => {
      if (cancelled) return
      plugin
        .addListener('guardianModeChanged', (data) => {
          setGuardianModeEnabled(data.enabled)
          setChangedBy(data.changedBy)
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
  }, [setGuardianModeEnabled])

  return { guardianModeEnabled, changedBy }
}
