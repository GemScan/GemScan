'use client'

import { useEffect, useRef, useState } from 'react'
import { useRouter } from 'next/navigation'
import { Capacitor } from '@capacitor/core'
import { Camera, CameraResultType, CameraSource } from '@capacitor/camera'
import InputArea from '@/components/InputArea'
import { getGemmaPlugin } from '@/lib/gemma'

const PENDING_IMAGE_KEY = 'gemscan.pendingImage'

interface PendingImage {
  base64: string
  mimeType: 'image/jpeg' | 'image/png'
}

export default function HomePage() {
  const router = useRouter()
  const [input, setInput] = useState('')
  const fileInputRef = useRef<HTMLInputElement | null>(null)
  const [uploadError, setUploadError] = useState<string | null>(null)
  // null while we're still asking the native plugin; true/false once
  // we know. We only block an action when this is explicitly false —
  // if the readiness probe fails or hasn't returned yet, we let the
  // user proceed and rely on the downstream analyser to fail loudly.
  const [modelReady, setModelReady] = useState<boolean | null>(null)
  const [showModelReminder, setShowModelReminder] = useState(false)

  useEffect(() => {
    let cancelled = false
    getGemmaPlugin()
      .then((plugin) => plugin.isReady())
      .then((status) => {
        if (cancelled) return
        setModelReady(status.ready)
      })
      .catch(() => {
        if (cancelled) return
        // Treat probe failures as "unknown" — don't block analysis,
        // and don't pop the reminder; the analyse page will surface
        // whatever the real error is.
        setModelReady(null)
      })
    return () => {
      cancelled = true
    }
  }, [])

  const handleSubmit = () => {
    if (!input.trim()) return
    if (modelReady === false) {
      setShowModelReminder(true)
      return
    }
    router.push(`/analyse?q=${encodeURIComponent(input)}`)
  }

  /// On iOS we use the native Capacitor Camera plugin so the user gets a
  /// proper action sheet (Camera / Photos / Cancel). The hidden file
  /// input is kept around as a fallback for the web mock (`npm run dev`)
  /// where the Camera plugin has no native implementation.
  const handleUploadClick = async () => {
    setUploadError(null)

    if (modelReady === false) {
      setShowModelReminder(true)
      return
    }

    if (!Capacitor.isNativePlatform()) {
      // Browser fallback — open the file input.
      fileInputRef.current?.click()
      return
    }

    try {
      const photo = await Camera.getPhoto({
        // Returns the image as a base64 string (and a data URL prefix we
        // can rebuild) without needing a temporary file handle — fits
        // neatly into the sessionStorage handoff the analyse page reads.
        resultType: CameraResultType.Base64,
        // Force the library picker. We previously offered the camera as
        // well, but the live-capture path was unreliable on Simulator
        // (Fig/RunningBoard teardown errors) and not a common flow for
        // checking suspicious screenshots, so this skips the action
        // sheet and goes straight to Photos.
        source: CameraSource.Photos,
        quality: 90,
        // Disabling edit (no crop step) keeps the flow snappy and
        // ensures we send the screenshot as-shared.
        allowEditing: false,
        // Force JPEG so the downstream OCR + classify pipeline doesn't
        // need to branch on HEIC/PNG/JPEG. iOS does the conversion
        // before handing us the bytes.
        correctOrientation: true,
      })

      if (!photo.base64String) {
        setUploadError("Couldn't read that picture. Try another one.")
        return
      }

      const mimeType: 'image/jpeg' | 'image/png' =
        photo.format === 'png' ? 'image/png' : 'image/jpeg'
      const pending: PendingImage = {
        base64: photo.base64String,
        mimeType,
      }
      // eslint-disable-next-line no-console
      console.log(
        `[GemScan] camera photo received: ${photo.base64String.length} base64 chars, mime=${mimeType}`
      )

      // sessionStorage in WKWebView is capped around 5MB. A high-res
      // iPhone photo encoded to base64 can flirt with that ceiling, so
      // catch quota failures explicitly rather than letting them fall
      // through the generic camera catch (which would mislabel them).
      try {
        sessionStorage.setItem(PENDING_IMAGE_KEY, JSON.stringify(pending))
      } catch (storageErr) {
        const msg = storageErr instanceof Error ? storageErr.message : String(storageErr)
        // eslint-disable-next-line no-console
        console.warn('sessionStorage.setItem failed:', msg)
        setUploadError("Picture is too large to hand off. Try a smaller image.")
        return
      }
      router.push('/analyse?type=image')
    } catch (err) {
      // Pull the raw message out — Capacitor Camera throws plain
      // Errors with strings like "User cancelled photos app",
      // "User denied access to camera", "Camera not available while
      // running in Simulator", or "You are missing NSCameraUsage…".
      const raw = err instanceof Error ? err.message : String(err)
      const lower = raw.toLowerCase()

      // Console-log the full error so we always have it in Xcode logs.
      // eslint-disable-next-line no-console
      console.warn('Camera.getPhoto failed:', raw)

      // User cancelled — silent no-op.
      if (lower.includes('cancel')) return

      // Translate the known plugin error strings into user-readable
      // toasts. Everything else falls through to a generic toast that
      // includes the raw message so we can debug if a new error
      // surfaces.
      if (lower.includes('simulator')) {
        setUploadError("Camera isn't available in the iOS Simulator. Run on a real device to take photos.")
      } else if (lower.includes('user denied access to camera')) {
        setUploadError('Camera access is off. Enable it in iOS Settings → GemScan → Camera.')
      } else if (lower.includes('user denied access to photos')) {
        setUploadError('Photo Library access is off. Enable it in iOS Settings → GemScan → Photos.')
      } else if (lower.includes('infoplist') || lower.includes('info.plist') || lower.includes('missing ns')) {
        setUploadError(`Missing iOS permission key: ${raw}`)
      } else {
        setUploadError(`Couldn't open the picture picker: ${raw}`)
      }
    }
  }

  const handleFileChange = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    // Reset the input so picking the same file twice still fires onChange.
    e.target.value = ''
    if (!file) return

    if (file.size > 8 * 1024 * 1024) {
      setUploadError('Image is too large. Pick something under 8 MB.')
      return
    }

    const mimeType: 'image/jpeg' | 'image/png' =
      file.type === 'image/png' ? 'image/png' : 'image/jpeg'

    try {
      const dataURL = await readAsDataURL(file)
      const base64 = dataURL.split(',')[1] ?? ''
      const pending: PendingImage = {
        base64,
        mimeType,
      }
      try {
        sessionStorage.setItem(PENDING_IMAGE_KEY, JSON.stringify(pending))
      } catch {
        setUploadError("Picture is too large to hand off. Try a smaller image.")
        return
      }
      router.push('/analyse?type=image')
    } catch {
      setUploadError("Couldn't read that file. Try another one.")
    }
  }

  return (
    <main
      className="page"
      style={{
        alignItems: 'center',
        paddingTop: 32,
      }}
    >
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img
        src="/GemScan.png"
        alt="GemScan logo"
        width={200}
        height={200}
        style={{
          borderRadius: 16,
          width: 'min(200px, 40vh)',
          height: 'auto',
          flex: '0 1 auto',
          minHeight: 0,
        }}
      />

      <p className="text-heading" style={{ color: 'var(--text)', textAlign: 'center' }}>
        What would you like me to analyze?
      </p>

      <div style={{ width: '100%', maxWidth: 480 }}>
        <InputArea
          value={input}
          onChange={setInput}
          onSubmit={handleSubmit}
          placeholder="Paste a message, URL, or describe what happened..."
        />
      </div>

      <span
        className="text-caption"
        style={{ color: 'var(--text-muted)' }}
        aria-hidden="true"
      >
        or
      </span>

      <div
        style={{
          display: 'flex',
          gap: 'var(--gap-element)',
          width: '100%',
          maxWidth: 480,
        }}
      >
        <button
          className="btn-secondary"
          style={{ flex: 1 }}
          onClick={handleUploadClick}
          aria-label="Add a picture to check"
        >
          <span style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8 }}>
            <svg
              width="20"
              height="20"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="2"
              strokeLinecap="round"
              strokeLinejoin="round"
              aria-hidden="true"
            >
              <rect x="3" y="3" width="18" height="18" rx="2" ry="2" />
              <circle cx="8.5" cy="8.5" r="1.5" />
              <polyline points="21 15 16 10 5 21" />
            </svg>
            Add a picture
          </span>
        </button>
      </div>

      <input
        ref={fileInputRef}
        type="file"
        accept="image/*"
        onChange={handleFileChange}
        style={{ display: 'none' }}
        aria-hidden="true"
      />

      {showModelReminder && (
        <ModelReminderBalloon
          onOpenSettings={() => {
            setShowModelReminder(false)
            router.push('/settings')
          }}
          onDismiss={() => setShowModelReminder(false)}
        />
      )}

      {uploadError && (
        <p
          role="alert"
          className="text-caption"
          style={{ color: 'var(--scam)', marginTop: -8 }}
        >
          {uploadError}
        </p>
      )}
    </main>
  )
}

/// Soft callout shown when the user tries to analyse something before
/// the Gemma 4 weights have been downloaded. Brand-blue accent (matches
/// the tab bar) so it doesn't look like the red error toast. Carries a
/// CTA straight to Settings, where the download UI lives.
function ModelReminderBalloon({
  onOpenSettings,
  onDismiss,
}: {
  onOpenSettings: () => void
  onDismiss: () => void
}) {
  return (
    <div
      role="alert"
      aria-live="polite"
      style={{
        position: 'relative',
        width: '100%',
        maxWidth: 480,
        padding: '14px 16px',
        borderRadius: 'var(--radius-card)',
        backgroundColor: '#eaf1fb',
        border: '1px solid #c2d4ef',
        boxShadow: '0 4px 16px rgba(0, 74, 173, 0.10)',
        display: 'flex',
        flexDirection: 'column',
        gap: 10,
      }}
    >
      {/* Speech-bubble pointer pointing up at the input/button area. */}
      <span
        aria-hidden="true"
        style={{
          position: 'absolute',
          top: -8,
          left: 32,
          width: 14,
          height: 14,
          backgroundColor: '#eaf1fb',
          borderTop: '1px solid #c2d4ef',
          borderLeft: '1px solid #c2d4ef',
          transform: 'rotate(45deg)',
          borderTopLeftRadius: 3,
        }}
      />
      <div style={{ display: 'flex', alignItems: 'flex-start', gap: 10 }}>
        <svg
          width="20"
          height="20"
          viewBox="0 0 24 24"
          fill="none"
          stroke="#004aad"
          strokeWidth="2"
          strokeLinecap="round"
          strokeLinejoin="round"
          aria-hidden="true"
          style={{ flexShrink: 0, marginTop: 2 }}
        >
          <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z" />
          <line x1="12" y1="8" x2="12" y2="13" />
          <circle cx="12" cy="16" r="0.5" fill="#004aad" />
        </svg>
        <div style={{ flex: 1, minWidth: 0 }}>
          <span
            className="text-body"
            style={{ color: '#0e1626', fontWeight: 600, display: 'block', marginBottom: 2 }}
          >
            Download the model first
          </span>
          <span className="text-caption" style={{ color: 'var(--text-muted)' }}>
            GemScan needs the Gemma 4 weights on this device before it can analyse anything.
            Under 5 minutes on Wi-Fi.
          </span>
        </div>
        <button
          onClick={onDismiss}
          aria-label="Dismiss reminder"
          style={{
            background: 'transparent',
            border: 'none',
            color: 'var(--text-muted)',
            cursor: 'pointer',
            padding: 4,
            minHeight: 32,
            minWidth: 32,
            flexShrink: 0,
          }}
        >
          <svg
            width="16"
            height="16"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            strokeWidth="2.5"
            strokeLinecap="round"
            strokeLinejoin="round"
            aria-hidden="true"
          >
            <line x1="18" y1="6" x2="6" y2="18" />
            <line x1="6" y1="6" x2="18" y2="18" />
          </svg>
        </button>
      </div>
      <button
        onClick={onOpenSettings}
        style={{
          alignSelf: 'flex-start',
          backgroundColor: '#004aad',
          color: '#ffffff',
          border: 'none',
          borderRadius: 'var(--radius-button)',
          padding: '8px 16px',
          fontFamily: 'inherit',
          fontSize: '0.94rem',
          fontWeight: 600,
          cursor: 'pointer',
          minHeight: 36,
        }}
      >
        Open Settings
      </button>
    </div>
  )
}

function readAsDataURL(file: File): Promise<string> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader()
    reader.onload = () => resolve(reader.result as string)
    reader.onerror = () => reject(reader.error ?? new Error('FileReader failed'))
    reader.readAsDataURL(file)
  })
}
