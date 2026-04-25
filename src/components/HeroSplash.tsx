'use client'

interface Props {
  visible: boolean
}

export default function HeroSplash({ visible }: Props) {
  return (
    <div
      role="presentation"
      aria-hidden={!visible}
      style={{
        position: 'fixed',
        inset: 0,
        backgroundColor: 'var(--surface)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        zIndex: 9999,
        opacity: visible ? 1 : 0,
        pointerEvents: visible ? 'auto' : 'none',
        transition: 'opacity 320ms ease-out',
      }}
    >
      <div
        style={{
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          gap: 40,
        }}
      >
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img
          src="/GemScan.png"
          alt=""
          width={220}
          height={220}
          style={{ borderRadius: 16 }}
        />

        <div
          role="status"
          aria-label="Starting GemScan"
          style={{ display: 'flex', gap: 8 }}
        >
          <span className="splash-dot" />
          <span className="splash-dot" />
          <span className="splash-dot" />
        </div>
      </div>
    </div>
  )
}
