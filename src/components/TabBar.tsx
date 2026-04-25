'use client'

import { usePathname, useRouter } from 'next/navigation'

interface Tab {
  key: string
  label: string
  href: string
  icon: (active: boolean) => React.ReactNode
}

function ScanIcon({ active }: { active: boolean }) {
  return (
    <svg
      width="24"
      height="24"
      viewBox="0 0 24 24"
      fill="none"
      stroke={active ? 'var(--text)' : 'var(--text-muted)'}
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      <path d="M3 7V5a2 2 0 0 1 2-2h2" />
      <path d="M17 3h2a2 2 0 0 1 2 2v2" />
      <path d="M21 17v2a2 2 0 0 1-2 2h-2" />
      <path d="M7 21H5a2 2 0 0 1-2-2v-2" />
      <path d="M12 7v10" />
      <path d="M8 12h8" />
    </svg>
  )
}

function HistoryIcon({ active }: { active: boolean }) {
  return (
    <svg
      width="24"
      height="24"
      viewBox="0 0 24 24"
      fill="none"
      stroke={active ? 'var(--text)' : 'var(--text-muted)'}
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      <circle cx="12" cy="12" r="10" />
      <polyline points="12 6 12 12 16 14" />
    </svg>
  )
}

function SettingsIcon({ active }: { active: boolean }) {
  return (
    <svg
      width="24"
      height="24"
      viewBox="0 0 24 24"
      fill="none"
      stroke={active ? 'var(--text)' : 'var(--text-muted)'}
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      <circle cx="12" cy="12" r="3" />
      <path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06A1.65 1.65 0 0 0 4.68 15a1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06A1.65 1.65 0 0 0 9 4.68a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06A1.65 1.65 0 0 0 19.4 9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z" />
    </svg>
  )
}

const tabs: Tab[] = [
  {
    key: 'scan',
    label: 'Scan',
    href: '/',
    icon: (active) => <ScanIcon active={active} />,
  },
  {
    key: 'history',
    label: 'History',
    href: '/history',
    icon: (active) => <HistoryIcon active={active} />,
  },
  {
    key: 'settings',
    label: 'Settings',
    href: '/settings',
    icon: (active) => <SettingsIcon active={active} />,
  },
]

const HIDDEN_ON = ['/onboarding']

export default function TabBar() {
  const pathname = usePathname()
  const router = useRouter()

  if (HIDDEN_ON.includes(pathname)) return null

  return (
    <nav
      role="tablist"
      aria-label="Main navigation"
      style={{
        position: 'fixed',
        bottom: 0,
        left: 0,
        right: 0,
        display: 'flex',
        justifyContent: 'space-around',
        alignItems: 'center',
        height: 83,
        paddingBottom: 'env(safe-area-inset-bottom, 0px)',
        backgroundColor: 'var(--surface)',
        borderTop: '1px solid var(--border)',
        zIndex: 100,
      }}
    >
      {tabs.map((tab) => {
        const active =
          tab.href === '/'
            ? pathname === '/' || pathname === '/analyse'
            : pathname.startsWith(tab.href)

        return (
          <button
            key={tab.key}
            role="tab"
            aria-selected={active}
            aria-label={tab.label}
            onClick={() => router.push(tab.href)}
            style={{
              display: 'flex',
              flexDirection: 'column',
              alignItems: 'center',
              justifyContent: 'center',
              gap: 4,
              background: 'none',
              border: 'none',
              cursor: 'pointer',
              padding: '8px 16px',
              minWidth: 64,
              minHeight: 44,
            }}
          >
            {tab.icon(active)}
            <span
              style={{
                fontSize: 10,
                fontWeight: active ? 600 : 400,
                color: active ? 'var(--text)' : 'var(--text-muted)',
                letterSpacing: 0.2,
              }}
            >
              {tab.label}
            </span>
          </button>
        )
      })}
    </nav>
  )
}
