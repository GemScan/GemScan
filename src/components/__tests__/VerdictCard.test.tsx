import { describe, it, expect, vi } from 'vitest'
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import VerdictCard from '../VerdictCard'
import type { AgentResult } from '@/lib/gemma/types'

function makeResult(verdict: 'safe' | 'suspicious' | 'scam'): AgentResult {
  return {
    taskId: 'test-1',
    agentId: 'orchestrator',
    verdict,
    confidence: 0.87,
    reasoning: ['First reason.', 'Second reason.'],
    language: 'en',
    toolCallsLog: [],
    latencyMs: 300,
    modelTier: 'e2b',
    lowConfidenceFallback: false,
  }
}

describe('VerdictCard', () => {
  it('renders correct heading for scam verdict', () => {
    render(<VerdictCard result={makeResult('scam')} onShare={vi.fn()} onDismiss={vi.fn()} />)
    expect(screen.getByRole('heading', { level: 1 })).toHaveTextContent('This looks like a scam')
  })

  it('renders correct heading for safe verdict', () => {
    render(<VerdictCard result={makeResult('safe')} onShare={vi.fn()} onDismiss={vi.fn()} />)
    expect(screen.getByRole('heading', { level: 1 })).toHaveTextContent('Looks safe')
  })

  it('renders correct heading for suspicious verdict', () => {
    render(<VerdictCard result={makeResult('suspicious')} onShare={vi.fn()} onDismiss={vi.fn()} />)
    expect(screen.getByRole('heading', { level: 1 })).toHaveTextContent('Be careful')
  })

  it('heading receives focus on mount', () => {
    render(<VerdictCard result={makeResult('scam')} onShare={vi.fn()} onDismiss={vi.fn()} />)
    expect(document.activeElement).toBe(screen.getByRole('heading', { level: 1 }))
  })

  it('confidence bar has correct aria-valuenow', () => {
    render(<VerdictCard result={makeResult('scam')} onShare={vi.fn()} onDismiss={vi.fn()} />)
    const meter = screen.getByRole('meter')
    expect(meter).toHaveAttribute('aria-valuenow', '87')
  })

  it('hides Share button for safe verdict', () => {
    render(<VerdictCard result={makeResult('safe')} onShare={vi.fn()} onDismiss={vi.fn()} />)
    expect(screen.queryByText('Share with contact')).toBeNull()
  })

  it('shows Share button for scam verdict', () => {
    render(<VerdictCard result={makeResult('scam')} onShare={vi.fn()} onDismiss={vi.fn()} />)
    expect(screen.getByText('Share with contact')).toBeTruthy()
  })

  it('dismiss button says "Great!" for safe verdict', () => {
    render(<VerdictCard result={makeResult('safe')} onShare={vi.fn()} onDismiss={vi.fn()} />)
    expect(screen.getByText('Great!')).toBeTruthy()
  })

  it('dismiss button says "I\'ll be careful" for scam verdict', () => {
    render(<VerdictCard result={makeResult('scam')} onShare={vi.fn()} onDismiss={vi.fn()} />)
    expect(screen.getByText("I'll be careful")).toBeTruthy()
  })

  it('calls onDismiss when dismiss button clicked', async () => {
    const onDismiss = vi.fn()
    render(<VerdictCard result={makeResult('scam')} onShare={vi.fn()} onDismiss={onDismiss} />)
    await userEvent.click(screen.getByText("I'll be careful"))
    expect(onDismiss).toHaveBeenCalledOnce()
  })

  it('calls onShare when share button clicked', async () => {
    const onShare = vi.fn()
    render(<VerdictCard result={makeResult('scam')} onShare={onShare} onDismiss={vi.fn()} />)
    await userEvent.click(screen.getByText('Share with contact'))
    expect(onShare).toHaveBeenCalledOnce()
  })
})
