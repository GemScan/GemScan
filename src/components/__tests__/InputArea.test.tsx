import { describe, it, expect, vi } from 'vitest'
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import InputArea from '../InputArea'

describe('InputArea', () => {
  it('renders textarea and submit button', () => {
    render(<InputArea value="" onChange={vi.fn()} onSubmit={vi.fn()} />)
    expect(screen.getByRole('textbox')).toBeTruthy()
    expect(screen.getByRole('button', { name: /check this/i })).toBeTruthy()
  })

  it('submit button disabled when value is empty', () => {
    render(<InputArea value="" onChange={vi.fn()} onSubmit={vi.fn()} />)
    expect(screen.getByRole('button', { name: /check this/i })).toBeDisabled()
  })

  it('submit button enabled when value has text', () => {
    render(<InputArea value="hello" onChange={vi.fn()} onSubmit={vi.fn()} />)
    expect(screen.getByRole('button', { name: /check this/i })).not.toBeDisabled()
  })

  it('calls onSubmit when button clicked', async () => {
    const onSubmit = vi.fn()
    render(<InputArea value="test message" onChange={vi.fn()} onSubmit={onSubmit} />)
    await userEvent.click(screen.getByRole('button', { name: /check this/i }))
    expect(onSubmit).toHaveBeenCalledOnce()
  })
})
