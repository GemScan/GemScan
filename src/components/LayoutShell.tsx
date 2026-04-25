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
        await getGemmaPlugin()
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
