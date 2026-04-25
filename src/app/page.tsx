'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import InputArea from '@/components/InputArea'

export default function HomePage() {
  const router = useRouter()
  const [input, setInput] = useState('')

  const handleSubmit = () => {
    if (!input.trim()) return
    router.push('/analyse')
  }

  return (
    <main
      style={{
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        padding: 'var(--padding-page)',
        gap: 'var(--gap-section)',
        minHeight: '100vh',
        paddingBottom: 100,
      }}
    >
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img
        src="/GemScan.png"
        alt="GemScan logo"
        width={300}
        height={300}
        style={{ borderRadius: 16 }}
      />

      <p className="text-body" style={{ color: 'var(--text-muted)', textAlign: 'center' }}>
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
          onClick={() => {
            /* TODO: open file picker for image upload */
          }}
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
    </main>
  )
}
