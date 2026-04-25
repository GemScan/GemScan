import { describe, it, expect, vi } from 'vitest'
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import ResultRow from '../ResultRow'

describe('ResultRow', () => {
  it('truncates text at 40 characters', () => {
    const longText = 'A'.repeat(60)
    render(<ResultRow input={longText} verdict="safe" onClick={vi.fn()} />)
    const button = screen.getByRole('button')
    expect(button.textContent).toContain('A'.repeat(40) + '…')
  })

  it('shows full text when under 40 chars', () => {
    render(<ResultRow input="Short message" verdict="scam" onClick={vi.fn()} />)
    expect(screen.getByText('Short message')).toBeTruthy()
  })

  it('shows verdict pill text', () => {
    render(<ResultRow input="test" verdict="scam" onClick={vi.fn()} />)
    expect(screen.getByText('Scam')).toBeTruthy()
  })

  it('calls onClick when row clicked', async () => {
    const onClick = vi.fn()
    render(<ResultRow input="test" verdict="safe" onClick={onClick} />)
    await userEvent.click(screen.getByRole('button'))
    expect(onClick).toHaveBeenCalledOnce()
  })
})
