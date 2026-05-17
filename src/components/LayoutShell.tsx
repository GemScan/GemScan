'use client'

import { useEffect, useState } from 'react'
import { useRouter } from 'next/navigation'
import TabBar from '@/components/TabBar'
import HeroSplash from '@/components/HeroSplash'
import { getGemmaPlugin } from '@/lib/gemma'

const MIN_SPLASH_MS = 1200
const FADE_OUT_MS = 320

// sessionStorage key used to hand off a pending image to /analyse — the
// same key the home-screen Upload Picture button writes to, so the
// analyse page only has to know about one image-input source.
const PENDING_IMAGE_KEY = 'gemscan.pendingImage'

export default function LayoutShell({ children }: { children: React.ReactNode }) {
  const router = useRouter()
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

  // Drain any payload the iOS Share Extension queued in the App Group
  // container. The native bridge returns one entry per call and removes
  // it from the queue; we route it to /analyse using the same params the
  // home screen uses for typed input / uploaded images.
  //
  // Runs on initial mount AND whenever the app returns to the foreground
  // (the share-sheet `openURL(...)` call wakes the host process and
  // fires `visibilitychange`). That covers cold launch, warm launch, and
  // mid-session shares.
  useEffect(() => {
    let cancelled = false

    async function drainPendingShare() {
      if (typeof window === 'undefined') return
      if (document.visibilityState === 'hidden') return
      try {
        const plugin = await getGemmaPlugin()
        const { payload } = await plugin.getPendingShare()
        if (cancelled || !payload) return

        if (payload.type === 'text') {
          router.push(`/analyse?q=${encodeURIComponent(payload.content)}`)
        } else if (payload.type === 'url') {
          router.push(`/analyse?q=${encodeURIComponent(payload.url)}`)
        } else if (payload.type === 'image') {
          const previewDataURL = `data:${payload.mimeType};base64,${payload.base64}`
          sessionStorage.setItem(
            PENDING_IMAGE_KEY,
            JSON.stringify({
              base64: payload.base64,
              mimeType: payload.mimeType === 'image/png' ? 'image/png' : 'image/jpeg',
              previewDataURL,
            })
          )
          router.push('/analyse?type=image')
        }
      } catch {
        // No-op on web mock or transient bridge errors — share-sheet
        // delivery is best-effort and the user can always retry.
      }
    }

    void drainPendingShare()

    const onVisibilityChange = () => {
      if (document.visibilityState === 'visible') void drainPendingShare()
    }
    document.addEventListener('visibilitychange', onVisibilityChange)

    return () => {
      cancelled = true
      document.removeEventListener('visibilitychange', onVisibilityChange)
    }
  }, [router])

  return (
    <>
      {children}
      <TabBar />
      {splashMounted && <HeroSplash visible={splashVisible} />}
    </>
  )
}
