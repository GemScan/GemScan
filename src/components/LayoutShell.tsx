'use client'

import { useEffect, useState } from 'react'
import TabBar from '@/components/TabBar'
import HeroSplash from '@/components/HeroSplash'
import { getGemmaPlugin } from '@/lib/gemma'

const MIN_SPLASH_MS = 1200
const FADE_OUT_MS = 320

export default function LayoutShell({ children }: { children: React.ReactNode }) {
  const [splashVisible, setSplashVisible] = useState(true)
  const [splashMounted, setSplashMounted] = useState(true)

  useEffect(() => {
    const startedAt = Date.now()
    let cancelled = false

    async function waitForReady() {
      try {
        const plugin = await getGemmaPlugin()
        // Kick off model warm-load in the background. We don't await it — the
        // splash should clear as soon as the plugin handle exists, and the
        // weights can finish loading into RAM while the user looks at the
        // home screen. Failures here are non-fatal (no download yet, etc.)
        // and surface via the Settings status pill once polling catches up.
        void plugin.warmUp().catch(() => {})
      } catch {
        // Even if init fails, fall through so the user sees the UI
      }

      if (cancelled) return

      const elapsed = Date.now() - startedAt
      const remaining = Math.max(0, MIN_SPLASH_MS - elapsed)

      setTimeout(() => {
        if (cancelled) return
        setSplashVisible(false)
        setTimeout(() => {
          if (!cancelled) setSplashMounted(false)
        }, FADE_OUT_MS)
      }, remaining)
    }

    waitForReady()

    return () => {
      cancelled = true
    }
  }, [])

  return (
    <>
      {children}
      <TabBar />
      {splashMounted && <HeroSplash visible={splashVisible} />}
    </>
  )
}
