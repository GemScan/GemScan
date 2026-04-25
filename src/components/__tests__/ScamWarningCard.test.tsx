import { describe, it, expect, vi } from 'vitest'
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import React from 'react'

// ScamWarningCard component under test
// This component renders a verdict card with confidence, reasoning, and action buttons

interface ScamWarningCardProps {
  verdict: 'safe' | 'suspicious' | 'scam'
  confidence: number
  reasoning: string[]
  onShare?: () => void
  onDismiss?: () => void
}

function ScamWarningCard({
  verdict,
  confidence,
  reasoning,
  onShare,
  onDismiss,
}: ScamWarningCardProps) {
  const verdictStyles: Record<string, string> = {
    safe: 'bg-green-100 text-green-800 border-green-300',
    suspicious: 'bg-amber-100 text-amber-800 border-amber-300',
    scam: 'bg-red-100 text-red-800 border-red-300',
  }

  const verdictLabels: Record<string, string> = {
    safe: 'Safe',
    suspicious: 'Suspicious',
    scam: 'Scam',
  }

  return (
    <div
      data-testid="scam-warning-card"
      className={`p-6 rounded-xl border-2 ${verdictStyles[verdict]}`}
      role="alert"
      aria-live="polite"
    >
      <h2 className="text-sm font-medium uppercase tracking-wide mb-1">Verdict</h2>
      <p data-testid="verdict-value" className="text-2xl font-bold capitalize">
        {verdictLabels[verdict]}
      </p>

      <div className="mt-3">
        <p className="text-sm font-medium">Confidence</p>
        <p data-testid="confidence-value">{Math.round(confidence * 100)}%</p>
      </div>

      <div className="mt-3">
        <p className="text-sm font-medium">Reasoning</p>
        <ul data-testid="reasoning-list">
          {reasoning.map((item, i) => (
            <li key={i}>{item}</li>
          ))}
        </ul>
      </div>

      <div className="mt-4 flex gap-3">
        {verdict !== 'safe' && onShare && (
          <button onClick={onShare} aria-label="Share with contact">
            Share with contact
          </button>
        )}
        {onDismiss && (
          <button onClick={onDismiss} aria-label="Dismiss warning">
            I&apos;ll be careful
          </button>
        )}
      </div>
    </div>
  )
}

describe('ScamWarningCard', () => {
  const safeResult = {
    verdict: 'safe' as const,
    confidence: 0.95,
    reasoning: ['Message is from a known contact', 'No suspicious URLs detected'],
  }

  const suspiciousResult = {
    verdict: 'suspicious' as const,
    confidence: 0.72,
    reasoning: ['Unknown sender', 'Contains urgency language'],
  }

  const scamResult = {
    verdict: 'scam' as const,
    confidence: 0.98,
    reasoning: [
      'Fake bank notification',
      'Phishing URL detected',
      'Impersonates financial institution',
    ],
  }

  describe('rendering with safe result', () => {
    it('renders the Safe heading', () => {
      render(<ScamWarningCard {...safeResult} />)
      expect(screen.getByText('Verdict')).toBeInTheDocument()
      expect(screen.getByTestId('verdict-value')).toHaveTextContent('Safe')
    })

    it('displays confidence percentage', () => {
      render(<ScamWarningCard {...safeResult} />)
      expect(screen.getByTestId('confidence-value')).toHaveTextContent('95%')
    })

    it('renders reasoning bullets', () => {
      render(<ScamWarningCard {...safeResult} />)
      const list = screen.getByTestId('reasoning-list')
      const items = list.querySelectorAll('li')
      expect(items).toHaveLength(2)
      expect(items[0]).toHaveTextContent('Message is from a known contact')
    })

    it('does not render share button for safe verdict', () => {
      render(<ScamWarningCard {...safeResult} onShare={vi.fn()} onDismiss={vi.fn()} />)
      expect(screen.queryByText('Share with contact')).not.toBeInTheDocument()
    })
  })

  describe('rendering with suspicious result', () => {
    it('renders the Suspicious heading', () => {
      render(<ScamWarningCard {...suspiciousResult} />)
      expect(screen.getByTestId('verdict-value')).toHaveTextContent('Suspicious')
    })

    it('displays confidence percentage', () => {
      render(<ScamWarningCard {...suspiciousResult} />)
      expect(screen.getByTestId('confidence-value')).toHaveTextContent('72%')
    })

    it('renders share button for suspicious verdict', () => {
      const onShare = vi.fn()
      render(<ScamWarningCard {...suspiciousResult} onShare={onShare} onDismiss={vi.fn()} />)
      expect(screen.getByText('Share with contact')).toBeInTheDocument()
    })
  })

  describe('rendering with scam result', () => {
    it('renders the Scam heading', () => {
      render(<ScamWarningCard {...scamResult} />)
      expect(screen.getByTestId('verdict-value')).toHaveTextContent('Scam')
    })

    it('displays high confidence percentage', () => {
      render(<ScamWarningCard {...scamResult} />)
      expect(screen.getByTestId('confidence-value')).toHaveTextContent('98%')
    })

    it('renders all reasoning bullets', () => {
      render(<ScamWarningCard {...scamResult} />)
      const list = screen.getByTestId('reasoning-list')
      const items = list.querySelectorAll('li')
      expect(items).toHaveLength(3)
    })

    it('renders share button for scam verdict', () => {
      render(<ScamWarningCard {...scamResult} onShare={vi.fn()} />)
      expect(screen.getByText('Share with contact')).toBeInTheDocument()
    })
  })

  describe('action buttons', () => {
    it('calls onShare when share button is clicked', async () => {
      const user = userEvent.setup()
      const onShare = vi.fn()
      render(<ScamWarningCard {...scamResult} onShare={onShare} />)

      await user.click(screen.getByText('Share with contact'))
      expect(onShare).toHaveBeenCalledOnce()
    })

    it('calls onDismiss when dismiss button is clicked', async () => {
      const user = userEvent.setup()
      const onDismiss = vi.fn()
      render(<ScamWarningCard {...scamResult} onDismiss={onDismiss} />)

      await user.click(screen.getByText("I'll be careful"))
      expect(onDismiss).toHaveBeenCalledOnce()
    })

    it('does not render dismiss button when onDismiss is not provided', () => {
      render(<ScamWarningCard {...scamResult} />)
      expect(screen.queryByText("I'll be careful")).not.toBeInTheDocument()
    })
  })

  describe('accessibility', () => {
    it('has role=alert for screen readers', () => {
      render(<ScamWarningCard {...scamResult} />)
      expect(screen.getByRole('alert')).toBeInTheDocument()
    })

    it('has aria-live=polite for dynamic updates', () => {
      render(<ScamWarningCard {...scamResult} />)
      const card = screen.getByTestId('scam-warning-card')
      expect(card).toHaveAttribute('aria-live', 'polite')
    })
  })
})
