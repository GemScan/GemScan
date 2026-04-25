import { describe, it, expect, vi } from 'vitest'
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import React, { useState } from 'react'

// ContactPicker: a searchable contact picker component

interface Contact {
  id: string
  name: string
  phone?: string
}

interface ContactPickerProps {
  contacts: Contact[]
  selectedId: string | null
  onSelect: (contactId: string) => void
  placeholder?: string
}

function ContactPicker({
  contacts,
  selectedId,
  onSelect,
  placeholder = 'Search contacts...',
}: ContactPickerProps) {
  const [query, setQuery] = useState('')
  const [isOpen, setIsOpen] = useState(false)

  const filtered = contacts.filter(
    (c) => c.name.toLowerCase().includes(query.toLowerCase()) || c.phone?.includes(query)
  )

  const selected = contacts.find((c) => c.id === selectedId)

  return (
    <div data-testid="contact-picker">
      <input
        type="text"
        value={query}
        onChange={(e) => {
          setQuery(e.target.value)
          setIsOpen(true)
        }}
        onFocus={() => setIsOpen(true)}
        placeholder={placeholder}
        aria-label="Search contacts"
        data-testid="contact-search-input"
      />

      {isOpen && filtered.length > 0 && (
        <ul data-testid="contact-list" role="listbox" aria-label="Contacts">
          {filtered.map((contact) => (
            <li
              key={contact.id}
              role="option"
              aria-selected={contact.id === selectedId}
              data-testid={`contact-${contact.id}`}
              onClick={() => {
                onSelect(contact.id)
                setQuery(contact.name)
                setIsOpen(false)
              }}
            >
              <span data-testid={`contact-name-${contact.id}`}>{contact.name}</span>
              {contact.phone && (
                <span data-testid={`contact-phone-${contact.id}`}>{contact.phone}</span>
              )}
            </li>
          ))}
        </ul>
      )}

      {isOpen && filtered.length === 0 && query && (
        <p data-testid="no-results">No contacts found</p>
      )}

      {selected && <div data-testid="selected-contact">Selected: {selected.name}</div>}
    </div>
  )
}

describe('ContactPicker', () => {
  const mockContacts: Contact[] = [
    { id: '1', name: 'Alice Johnson', phone: '+1234567890' },
    { id: '2', name: 'Bob Smith', phone: '+0987654321' },
    { id: '3', name: 'Charlie Brown', phone: '+1122334455' },
  ]

  it('renders the search input with placeholder', () => {
    render(<ContactPicker contacts={mockContacts} selectedId={null} onSelect={vi.fn()} />)
    expect(screen.getByPlaceholderText('Search contacts...')).toBeInTheDocument()
  })

  it('renders with custom placeholder', () => {
    render(
      <ContactPicker
        contacts={mockContacts}
        selectedId={null}
        onSelect={vi.fn()}
        placeholder="Find a contact..."
      />
    )
    expect(screen.getByPlaceholderText('Find a contact...')).toBeInTheDocument()
  })

  it('shows contact list on focus', async () => {
    const user = userEvent.setup()
    render(<ContactPicker contacts={mockContacts} selectedId={null} onSelect={vi.fn()} />)

    const input = screen.getByTestId('contact-search-input')
    await user.click(input)

    expect(screen.getByTestId('contact-list')).toBeInTheDocument()
    expect(screen.getByTestId('contact-1')).toBeInTheDocument()
    expect(screen.getByTestId('contact-2')).toBeInTheDocument()
    expect(screen.getByTestId('contact-3')).toBeInTheDocument()
  })

  it('filters contacts by name', async () => {
    const user = userEvent.setup()
    render(<ContactPicker contacts={mockContacts} selectedId={null} onSelect={vi.fn()} />)

    const input = screen.getByTestId('contact-search-input')
    await user.type(input, 'Alice')

    expect(screen.getByTestId('contact-1')).toBeInTheDocument()
    expect(screen.queryByTestId('contact-2')).not.toBeInTheDocument()
    expect(screen.queryByTestId('contact-3')).not.toBeInTheDocument()
  })

  it('filters contacts by phone number', async () => {
    const user = userEvent.setup()
    render(<ContactPicker contacts={mockContacts} selectedId={null} onSelect={vi.fn()} />)

    const input = screen.getByTestId('contact-search-input')
    await user.type(input, '+1234')

    expect(screen.getByTestId('contact-1')).toBeInTheDocument()
    expect(screen.queryByTestId('contact-2')).not.toBeInTheDocument()
  })

  it('shows no results message when no contacts match', async () => {
    const user = userEvent.setup()
    render(<ContactPicker contacts={mockContacts} selectedId={null} onSelect={vi.fn()} />)

    const input = screen.getByTestId('contact-search-input')
    await user.type(input, 'Nonexistent')

    expect(screen.getByTestId('no-results')).toHaveTextContent('No contacts found')
  })

  it('calls onSelect when a contact is clicked', async () => {
    const user = userEvent.setup()
    const onSelect = vi.fn()
    render(<ContactPicker contacts={mockContacts} selectedId={null} onSelect={onSelect} />)

    const input = screen.getByTestId('contact-search-input')
    await user.click(input)
    await user.click(screen.getByTestId('contact-2'))

    expect(onSelect).toHaveBeenCalledWith('2')
  })

  it('displays contact names and phone numbers', async () => {
    const user = userEvent.setup()
    render(<ContactPicker contacts={mockContacts} selectedId={null} onSelect={vi.fn()} />)

    const input = screen.getByTestId('contact-search-input')
    await user.click(input)

    expect(screen.getByTestId('contact-name-1')).toHaveTextContent('Alice Johnson')
    expect(screen.getByTestId('contact-phone-1')).toHaveTextContent('+1234567890')
  })

  it('shows selected contact when selectedId is provided', () => {
    render(<ContactPicker contacts={mockContacts} selectedId="2" onSelect={vi.fn()} />)
    expect(screen.getByTestId('selected-contact')).toHaveTextContent('Selected: Bob Smith')
  })

  it('has accessible search input with aria-label', () => {
    render(<ContactPicker contacts={mockContacts} selectedId={null} onSelect={vi.fn()} />)
    expect(screen.getByLabelText('Search contacts')).toBeInTheDocument()
  })

  it('contact list has listbox role', async () => {
    const user = userEvent.setup()
    render(<ContactPicker contacts={mockContacts} selectedId={null} onSelect={vi.fn()} />)

    await user.click(screen.getByTestId('contact-search-input'))
    expect(screen.getByRole('listbox')).toBeInTheDocument()
  })

  it('handles empty contacts array', async () => {
    const user = userEvent.setup()
    render(<ContactPicker contacts={[]} selectedId={null} onSelect={vi.fn()} />)

    const input = screen.getByTestId('contact-search-input')
    await user.type(input, 'any')

    expect(screen.getByTestId('no-results')).toBeInTheDocument()
  })
})
