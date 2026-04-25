import { describe, it, expect } from 'vitest'
import { render, screen } from '@testing-library/react'
import StreamingText from '../StreamingText'

describe('StreamingText', () => {
  it('renders tokens as text', () => {
    render(<StreamingText tokens="Hello world" isDone={false} />)
    expect(screen.getByText(/Hello world/)).toBeTruthy()
  })

  it('has aria-live="polite"', () => {
    const { container } = render(<StreamingText tokens="test" isDone={false} />)
    const liveRegion = container.querySelector('[aria-live="polite"]')
    expect(liveRegion).toBeTruthy()
  })

  it('shows cursor when not done', () => {
    const { container } = render(<StreamingText tokens="test" isDone={false} />)
    const cursor = container.querySelector('.streaming-cursor')
    expect(cursor).toBeTruthy()
    expect(cursor?.textContent).toBe('|')
  })

  it('hides cursor when done', () => {
    const { container } = render(<StreamingText tokens="test" isDone={true} />)
    const cursor = container.querySelector('.streaming-cursor')
    expect(cursor).toBeNull()
  })
})
