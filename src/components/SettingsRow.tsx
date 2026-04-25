'use client'

import type { ReactNode } from 'react'

interface SettingsRowProps {
  label: string
  value?: string
  showChevron?: boolean
  onClick?: () => void
  children?: ReactNode
}

export default function SettingsRow({
  label,
  value,
  showChevron = false,
  onClick,
  children,
}: SettingsRowProps) {
  const Tag = onClick ? 'button' : 'div'

  return (
    <Tag
      onClick={onClick}
      style={{
        height: 'var(--height-row)',
        width: '100%',
        display: 'flex',
        flexDirection: 'column',
        justifyContent: 'center',
        background: 'none',
        border: 'none',
        padding: 0,
        cursor: onClick ? 'pointer' : 'default',
        color: 'var(--text)',
        textAlign: 'left',
      }}
    >
      <span className="text-caption" style={{ color: 'var(--text-muted)' }}>
        {label}
      </span>
      {children ? (
        children
      ) : (
        <span style={{ display: 'flex', alignItems: 'center' }}>
          <span className="text-body" style={{ flexGrow: 1 }}>
            {value}
          </span>
          {showChevron && (
            <span className="text-caption" style={{ color: 'var(--text-muted)' }}>
              ▸
            </span>
          )}
        </span>
      )}
    </Tag>
  )
}
