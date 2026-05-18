'use client'

import { useEffect } from 'react'
import { useRouter } from 'next/navigation'
import TabBar from '@/components/TabBar'
import { getGemmaPlugin } from '@/lib/gemma'

// sessionStorage key used to hand off a pending image to /analyse — the
// same key the home-screen Upload Picture button writes to, so the
// analyse page only has to know about one image-input source.
const PENDING_IMAGE_KEY = 'gemscan.pendingImage'

export default function LayoutShell({ children }: { children: React.ReactNode }) {
  const router = useRouter()

  useEffect(() => {
    // Kick off model warm-load in the background. The iOS LaunchScreen
    // covers the boot transition, so there's no in-app splash to gate
    // on this — we just fire-and-forget. Failures (model not yet
    // downloaded, etc.) surface via the Settings status pill once
    // polling catches up.
    let cancelled = false
    void (async () => {
      try {
        const plugin = await getGemmaPlugin()
        if (!cancelled) {
          void plugin.warmUp().catch(() => {})
        }
      } catch {
        // Plugin handle failed — let the user see the UI anyway.
      }
    })()
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
    </>
  )
}
