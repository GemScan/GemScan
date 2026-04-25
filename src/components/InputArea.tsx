'use client'

interface InputAreaProps {
  value: string
  onChange: (v: string) => void
  onSubmit: () => void
  placeholder?: string
  disabled?: boolean
}

export default function InputArea({
  value,
  onChange,
  onSubmit,
  placeholder = 'Paste a message to check…',
  disabled = false,
}: InputAreaProps) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--gap-element)' }}>
      <textarea
        className="text-body"
        aria-label={placeholder}
        placeholder={placeholder}
        value={value}
        onChange={(e) => onChange(e.target.value)}
        disabled={disabled}
        style={{
          height: 'var(--height-input)',
          border: '1px solid var(--border)',
          borderRadius: 'var(--radius-input)',
          padding: 16,
          resize: 'none',
          width: '100%',
          backgroundColor: 'var(--surface)',
          color: 'var(--text)',
        }}
      />
      <button className="btn-primary" onClick={onSubmit} disabled={!value.trim() || disabled}>
        Check this
      </button>
    </div>
  )
}
