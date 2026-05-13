import { describe, it, expect } from 'vitest'
import { render, screen } from '@testing-library/react'
import ProgressRow from '../ProgressRow'

describe('ProgressRow', () => {
  it('renders label and total size', () => {
    render(<ProgressRow label="Gemma E2B" progress={0.45} totalSize="1.8 GB" />)
    expect(screen.getByText('Gemma E2B')).toBeTruthy()
    expect(screen.getByText('1.8 GB')).toBeTruthy()
  })

  it('renders progressbar role', () => {
    render(<ProgressRow label="Gemma E2B" progress={0.45} totalSize="1.8 GB" />)
    const bar = screen.getByRole('progressbar')
    expect(bar).toBeTruthy()
  })

  it('has correct aria-valuetext', () => {
    render(<ProgressRow label="Gemma E2B" progress={0.45} totalSize="1.8 GB" />)
    const bar = screen.getByRole('progressbar')
    expect(bar.getAttribute('aria-valuetext')).toBe('Gemma E2B: 45% of 1.8 GB')
  })

  it('has correct aria-valuenow', () => {
    render(<ProgressRow label="Gemma 4 E2B" progress={1} totalSize="3.4 GB" />)
    const bar = screen.getByRole('progressbar')
    expect(bar.getAttribute('aria-valuenow')).toBe('100')
  })
})
