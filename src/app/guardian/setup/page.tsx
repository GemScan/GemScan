'use client'

import { useState, useMemo } from 'react'
import { useRouter } from 'next/navigation'
import { useGemScanStore } from '@/lib/store'

const mockContacts = [
  { id: 'c1', name: 'Alice Smith', phone: '***-***-1234', email: 'a***@mail.com' },
  { id: 'c2', name: 'Bob Johnson', phone: '***-***-5678', email: 'b***@mail.com' },
  { id: 'c3', name: 'Carol Williams', phone: '***-***-9012', email: 'c***@mail.com' },
]

export default function GuardianSetupPage() {
  const router = useRouter()
  const setTrustedContactId = useGemScanStore((s) => s.setTrustedContactId)
  const setGuardianModeEnabled = useGemScanStore((s) => s.setGuardianModeEnabled)
  const trustedContactId = useGemScanStore((s) => s.trustedContactId)

  const [search, setSearch] = useState('')
  const [selectedId, setSelectedId] = useState<string | null>(trustedContactId)

  const filtered = useMemo(
    () => mockContacts.filter((c) => c.name.toLowerCase().includes(search.toLowerCase())),
    [search]
  )

  const handleEnable = () => {
    if (selectedId) {
      setTrustedContactId(selectedId)
      setGuardianModeEnabled(true)
    }
    router.push('/')
  }

  return (
    <main className="page">
      <button
        className="text-body"
        onClick={() => router.back()}
        style={{
          color: 'var(--text)',
          background: 'none',
          border: 'none',
          padding: '8px 0',
          cursor: 'pointer',
          alignSelf: 'flex-start',
          minHeight: 44,
          minWidth: 44,
        }}
      >
        ← Back
      </button>

      <h1 className="text-title" style={{ color: 'var(--text)' }}>
        Guardian Mode
      </h1>

      <p className="text-body" style={{ color: 'var(--text)' }}>
        If GemScan detects a high-risk scam, it will alert your trusted contact.
      </p>

      <span className="text-caption" style={{ color: 'var(--text-muted)' }}>
        Trusted contact
      </span>

      <input
        type="text"
        className="text-body"
        placeholder="Search contacts…"
        value={search}
        onChange={(e) => setSearch(e.target.value)}
        style={{
          border: '1px solid var(--border)',
          borderRadius: 'var(--radius-input)',
          height: 44,
          padding: '0 12px',
          width: '100%',
          backgroundColor: 'var(--surface)',
          color: 'var(--text)',
        }}
      />

      <div className="page-scroll" style={{ gap: 0 }}>
        {filtered.map((contact) => (
          <button
            key={contact.id}
            onClick={() => setSelectedId(contact.id)}
            style={{
              display: 'flex',
              flexDirection: 'column',
              justifyContent: 'center',
              height: 'var(--height-row)',
              width: '100%',
              background: selectedId === contact.id ? 'var(--surface)' : 'none',
              border: 'none',
              padding: '0 var(--gap-element)',
              cursor: 'pointer',
              textAlign: 'left',
            }}
          >
            <span className="text-body" style={{ color: 'var(--text)' }}>
              {contact.name}
            </span>
            <span className="text-caption" style={{ color: 'var(--text-muted)' }}>
              {contact.phone} · {contact.email}
            </span>
          </button>
        ))}
      </div>

      <button className="btn-primary" onClick={handleEnable} disabled={!selectedId}>
        Turn on Guardian
      </button>
    </main>
  )
}
