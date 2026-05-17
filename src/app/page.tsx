'use client'

import { useRef, useState } from 'react'
import { useRouter } from 'next/navigation'
import InputArea from '@/components/InputArea'

const PENDING_IMAGE_KEY = 'gemscan.pendingImage'

interface PendingImage {
  base64: string
  mimeType: 'image/jpeg' | 'image/png'
  previewDataURL: string
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

  const handleUploadClick = () => {
    setUploadError(null)
    fileInputRef.current?.click()
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
        previewDataURL: dataURL,
      }
      sessionStorage.setItem(PENDING_IMAGE_KEY, JSON.stringify(pending))
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
        What would you like me to check?
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
          onClick={() => {
            /* TODO: open camera via Capacitor Camera plugin */
          }}
          aria-label="Use camera to take a photo"
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
              <path d="M23 19a2 2 0 0 1-2 2H3a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h4l2-3h6l2 3h4a2 2 0 0 1 2 2z" />
              <circle cx="12" cy="13" r="4" />
            </svg>
            Use camera
          </span>
        </button>

        <button
          className="btn-secondary"
          style={{ flex: 1 }}
          onClick={handleUploadClick}
          aria-label="Upload a picture from your photo library"
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
            Upload picture
          </span>
        </button>
      </div>

      <input
        ref={fileInputRef}
        type="file"
        accept="image/jpeg,image/png"
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
