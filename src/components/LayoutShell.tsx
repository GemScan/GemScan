'use client'

import TabBar from '@/components/TabBar'

export default function LayoutShell({ children }: { children: React.ReactNode }) {
  return (
    <>
      {children}
      <TabBar />
    </>
  )
}
