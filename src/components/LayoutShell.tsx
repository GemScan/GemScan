'use client'

import GuardianStatusBar from '@/components/GuardianStatusBar'
import DebugOverlay from '@/components/DebugOverlay'

export default function LayoutShell({ children }: { children: React.ReactNode }) {
  return (
    <>
      <GuardianStatusBar />
      {children}
      <DebugOverlay />
    </>
  )
}
