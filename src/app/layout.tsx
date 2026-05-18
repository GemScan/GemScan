import type { Metadata, Viewport } from 'next'
import '@/styles/globals.css'
import LayoutShell from '@/components/LayoutShell'

export const metadata: Metadata = {
  title: 'GemScan',
  description: 'On-device AI scam detection powered by Gemma',
}

export const viewport: Viewport = {
  width: 'device-width',
  initialScale: 1,
  viewportFit: 'cover',
  // Locks the WebView to light styling regardless of the user's system
  // appearance. Pairs with `color-scheme: light` in globals.css and the
  // native-side `UIUserInterfaceStyle = Light` in the iOS Info.plist.
  colorScheme: 'light',
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>
        <LayoutShell>{children}</LayoutShell>
      </body>
    </html>
  )
}
