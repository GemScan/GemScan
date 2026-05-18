'use client'

import { usePathname, useRouter } from 'next/navigation'

interface Tab {
  key: string
  label: string
  href: string
  icon: () => React.ReactNode
}

// The icon components were previously parameterised by `active` to swap
// stroke colour between `var(--text)` and `var(--text-muted)`. Now that
// every icon is pure white against the brand-blue bar, the parameter is
// gone — active-state differentiation lives on the label's font weight.
function ScanIcon() {
  return (
    <svg
      width="24"
      height="24"
      viewBox="0 0 24 24"
      fill="none"
      stroke="#ffffff"
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

function LearnIcon() {
  // Open-book glyph — signals "read / learn about scams" without
  // crowding the bar with text. Same stroke / weight as the other tabs.
  return (
    <svg
      width="24"
      height="24"
      viewBox="0 0 24 24"
      fill="none"
      stroke="#ffffff"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      <path d="M2 6.5C2 5.67 2.67 5 3.5 5H9a3 3 0 0 1 3 3v12a2 2 0 0 0-2-2H3.5A1.5 1.5 0 0 1 2 16.5z" />
      <path d="M22 6.5C22 5.67 21.33 5 20.5 5H15a3 3 0 0 0-3 3v12a2 2 0 0 1 2-2h6.5a1.5 1.5 0 0 0 1.5-1.5z" />
    </svg>
  )
}

function HistoryIcon() {
  return (
    <svg
      width="24"
      height="24"
      viewBox="0 0 24 24"
      fill="none"
      stroke="#ffffff"
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

function SettingsIcon() {
  return (
    <svg
      width="24"
      height="24"
      viewBox="0 0 24 24"
      fill="none"
      stroke="#ffffff"
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
    label: 'Analyze',
    href: '/',
    icon: () => <ScanIcon />,
  },
  {
    key: 'history',
    label: 'History',
    href: '/history',
    icon: () => <HistoryIcon />,
  },
  {
    key: 'learn',
    label: 'Learn',
    href: '/learn',
    icon: () => <LearnIcon />,
  },
  {
    key: 'settings',
    label: 'Settings',
    href: '/settings',
    icon: () => <SettingsIcon />,
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
        alignItems: 'flex-start',
        paddingTop: 6,
        paddingBottom: 'calc(env(safe-area-inset-bottom, 0px) + 4px)',
        // Brand-blue tab bar with white iconography. The previous neutral
        // surface + border-top has been replaced; on a solid colour bar
        // the divider line reads as visual noise and is dropped.
        backgroundColor: '#004aad',
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
              // The button itself stays the full tap target (Apple HIG
              // minimum 44 pt). The pill lives on an inner wrapper so it
              // can be visibly inset from the button bounds.
              display: 'flex',
              flexDirection: 'column',
              alignItems: 'center',
              justifyContent: 'center',
              background: 'none',
              border: 'none',
              cursor: 'pointer',
              padding: '4px 6px',
              minWidth: 64,
              minHeight: 44,
            }}
          >
            <div
              style={{
                // Active state: translucent white pill behind the icon +
                // label. The inset (margin around vs. the button edge)
                // gives a clear gap between the pill and the bar's top /
                // bottom, plus a small gap between adjacent pills.
                display: 'flex',
                flexDirection: 'column',
                alignItems: 'center',
                gap: 2,
                padding: '4px 12px',
                borderRadius: 16,
                backgroundColor: active ? 'rgba(255, 255, 255, 0.15)' : 'transparent',
                transition: 'background-color 180ms ease',
              }}
            >
              {tab.icon()}
              <span
                style={{
                  fontSize: 11,
                  // Active vs inactive is signalled by weight rather
                  // than colour — both are white against the brand-blue
                  // bar.
                  fontWeight: active ? 600 : 500,
                  color: '#ffffff',
                  letterSpacing: -0.08,
                }}
              >
                {tab.label}
              </span>
            </div>
          </button>
        )
      })}
    </nav>
  )
}
