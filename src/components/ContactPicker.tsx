'use client'

import { useState, useMemo } from 'react'
import { useLocale } from '@/lib/i18n/strings'

interface ContactPickerProps {
  onSelect: (contactId: string) => void
}

interface Contact {
  id: string
  name: string
  phone: string
  email: string
}

function maskPhone(phone: string): string {
  // e.g. "+1 (415) 555-2671" -> "+1 (415) ***-2671"
  return phone
    .replace(/(\d{3})([-\s])(\d{4})$/, '***$2$3')
    .replace(/(\d{3})\)(\s)(\d{3})/, '$1)$2***')
}

function maskEmail(email: string): string {
  // e.g. "alice@domain.com" -> "a***@domain.com"
  const [local, domain] = email.split('@')
  if (!domain) return email
  return `${local[0]}***@${domain}`
}

// Placeholder contacts for demonstration
const sampleContacts: Contact[] = [
  { id: 'c1', name: 'Alice Johnson', phone: '+1 (415) 555-2671', email: 'alice@example.com' },
  { id: 'c2', name: 'Bob Smith', phone: '+1 (415) 555-8934', email: 'bob@example.com' },
  { id: 'c3', name: 'Carmen Rivera', phone: '+1 (415) 555-1122', email: 'carmen@example.com' },
  { id: 'c4', name: 'David Chen', phone: '+1 (415) 555-4455', email: 'david@example.com' },
  { id: 'c5', name: 'Elena Petrov', phone: '+1 (415) 555-7788', email: 'elena@example.com' },
]

export default function ContactPicker({ onSelect }: ContactPickerProps) {
  const [query, setQuery] = useState('')
  const { t } = useLocale()

  const filtered = useMemo(() => {
    const q = query.toLowerCase().trim()
    if (!q) return sampleContacts
    return sampleContacts
      .filter((c) => c.name.toLowerCase().includes(q))
      .sort((a, b) => a.name.localeCompare(b.name))
  }, [query])

  const sorted = useMemo(() => {
    return [...filtered].sort((a, b) => a.name.localeCompare(b.name))
  }, [filtered])

  return (
    <div className="w-full max-w-sm">
      <label htmlFor="contact-search" className="sr-only">
        {t('searchContacts')}
      </label>
      <input
        id="contact-search"
        type="search"
        value={query}
        onChange={(e) => setQuery(e.target.value)}
        placeholder={t('searchContacts')}
        className="w-full rounded-lg border p-3 text-base mb-3"
        aria-label={t('searchContacts')}
      />

      <ul className="space-y-2" role="listbox" aria-label={t('trustedContact')}>
        {sorted.map((contact) => (
          <li key={contact.id}>
            <button
              role="option"
              aria-selected={false}
              onClick={() => onSelect(contact.id)}
              className="w-full text-left rounded-lg border p-3 hover:bg-blue-50 dark:hover:bg-blue-950 transition-colors min-h-[44px]"
              aria-label={`Select ${contact.name}`}
            >
              <p className="font-medium">{contact.name}</p>
              <p className="text-sm text-gray-500">{maskPhone(contact.phone)}</p>
              <p className="text-sm text-gray-500">{maskEmail(contact.email)}</p>
            </button>
          </li>
        ))}
        {sorted.length === 0 && (
          <li className="text-sm text-gray-500 text-center py-4">No contacts found</li>
        )}
      </ul>
    </div>
  )
}
