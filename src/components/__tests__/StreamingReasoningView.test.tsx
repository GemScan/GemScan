import { describe, it, expect } from 'vitest'
import { render, screen } from '@testing-library/react'
import React from 'react'

// StreamingReasoningView: displays streaming tokens with a blinking cursor

interface StreamingReasoningViewProps {
  tokens: string
  isStreaming: boolean
  isDone: boolean
}

function StreamingReasoningView({ tokens, isStreaming, isDone }: StreamingReasoningViewProps) {
  if (!tokens && !isStreaming) return null

  return (
    <div
      data-testid="streaming-view"
      className="p-4 rounded-lg bg-gray-50 text-sm font-mono"
      role="status"
      aria-live="polite"
      aria-label={isStreaming ? 'Analysis in progress' : 'Analysis complete'}
    >
      <span data-testid="streaming-tokens">{tokens}</span>
      {isStreaming && (
        <span data-testid="streaming-cursor" className="animate-pulse" aria-hidden="true">
          |
        </span>
      )}
      {isDone && (
        <span data-testid="streaming-done" className="text-green-600 ml-2">
          Done
        </span>
      )}
    </div>
  )
}

describe('StreamingReasoningView', () => {
  it('renders nothing when no tokens and not streaming', () => {
    const { container } = render(
      <StreamingReasoningView tokens="" isStreaming={false} isDone={false} />
    )
    expect(container.querySelector('[data-testid="streaming-view"]')).not.toBeInTheDocument()
  })

  it('renders streaming view when isStreaming is true', () => {
    render(<StreamingReasoningView tokens="" isStreaming={true} isDone={false} />)
    expect(screen.getByTestId('streaming-view')).toBeInTheDocument()
  })

  it('displays accumulated tokens', () => {
    render(
      <StreamingReasoningView
        tokens="This message appears to be"
        isStreaming={true}
        isDone={false}
      />
    )
    expect(screen.getByTestId('streaming-tokens')).toHaveTextContent('This message appears to be')
  })

  it('shows blinking cursor while streaming', () => {
    render(<StreamingReasoningView tokens="Analysing..." isStreaming={true} isDone={false} />)
    expect(screen.getByTestId('streaming-cursor')).toBeInTheDocument()
    expect(screen.getByTestId('streaming-cursor')).toHaveTextContent('|')
  })

  it('hides cursor when streaming is complete', () => {
    render(<StreamingReasoningView tokens="This is safe." isStreaming={false} isDone={true} />)
    expect(screen.queryByTestId('streaming-cursor')).not.toBeInTheDocument()
  })

  it('shows done indicator when analysis is complete', () => {
    render(<StreamingReasoningView tokens="This is safe." isStreaming={false} isDone={true} />)
    expect(screen.getByTestId('streaming-done')).toHaveTextContent('Done')
  })

  it('has role=status for screen reader announcements', () => {
    render(<StreamingReasoningView tokens="test" isStreaming={true} isDone={false} />)
    expect(screen.getByRole('status')).toBeInTheDocument()
  })

  it('has appropriate aria-label during streaming', () => {
    render(<StreamingReasoningView tokens="test" isStreaming={true} isDone={false} />)
    expect(screen.getByTestId('streaming-view')).toHaveAttribute(
      'aria-label',
      'Analysis in progress'
    )
  })

  it('has appropriate aria-label when complete', () => {
    render(<StreamingReasoningView tokens="test" isStreaming={false} isDone={true} />)
    expect(screen.getByTestId('streaming-view')).toHaveAttribute('aria-label', 'Analysis complete')
  })

  it('cursor is hidden from screen readers', () => {
    render(<StreamingReasoningView tokens="test" isStreaming={true} isDone={false} />)
    expect(screen.getByTestId('streaming-cursor')).toHaveAttribute('aria-hidden', 'true')
  })

  it('updates display as tokens grow', () => {
    const { rerender } = render(
      <StreamingReasoningView tokens="Hello" isStreaming={true} isDone={false} />
    )
    expect(screen.getByTestId('streaming-tokens')).toHaveTextContent('Hello')

    rerender(<StreamingReasoningView tokens="Hello world" isStreaming={true} isDone={false} />)
    expect(screen.getByTestId('streaming-tokens')).toHaveTextContent('Hello world')
  })
})
