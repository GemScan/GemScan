'use client'

import { useRef, useState } from 'react'
import { useRouter } from 'next/navigation'
import { Capacitor } from '@capacitor/core'
import { Camera, CameraResultType, CameraSource } from '@capacitor/camera'
import InputArea from '@/components/InputArea'

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

  const handleSubmit = () => {
    if (!input.trim()) return
    router.push(`/analyse?q=${encodeURIComponent(input)}`)
  }

  /// On iOS we use the native Capacitor Camera plugin so the user gets a
  /// proper action sheet (Camera / Photos / Cancel). The hidden file
  /// input is kept around as a fallback for the web mock (`npm run dev`)
  /// where the Camera plugin has no native implementation.
  const handleUploadClick = async () => {
    setUploadError(null)

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
        // `Prompt` shows an iOS action sheet with Camera + Photos
        // options. `Camera` would force-open the camera; `Photos` would
        // force-open the library. Prompt is what most apps use for a
        // "Add picture" affordance.
        source: CameraSource.Prompt,
        quality: 90,
        // Disabling edit (no crop step) keeps the flow snappy and
        // ensures we send the screenshot as-shared.
        allowEditing: false,
        // Force JPEG so the downstream OCR + classify pipeline doesn't
        // need to branch on HEIC/PNG/JPEG. iOS does the conversion
        // before handing us the bytes.
        correctOrientation: true,
        promptLabelHeader: 'Add a picture',
        promptLabelCancel: 'Cancel',
        promptLabelPhoto: 'Choose from library',
        promptLabelPicture: 'Take photo',
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

function readAsDataURL(file: File): Promise<string> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader()
    reader.onload = () => resolve(reader.result as string)
    reader.onerror = () => reject(reader.error ?? new Error('FileReader failed'))
    reader.readAsDataURL(file)
  })
}
