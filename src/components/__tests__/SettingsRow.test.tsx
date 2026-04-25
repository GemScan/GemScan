import { describe, it, expect, vi } from 'vitest'
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import SettingsRow from '../SettingsRow'

describe('SettingsRow', () => {
  it('renders label and value', () => {
    render(<SettingsRow label="Language" value="English" />)
    expect(screen.getByText('Language')).toBeTruthy()
    expect(screen.getByText('English')).toBeTruthy()
  })

  it('shows chevron when showChevron is true', () => {
    render(<SettingsRow label="Language" value="English" showChevron />)
    expect(screen.getByText('▸')).toBeTruthy()
  })

  it('hides chevron when showChevron is false', () => {
    render(<SettingsRow label="Language" value="English" />)
    expect(screen.queryByText('▸')).toBeNull()
  })

  it('is clickable when onClick provided', async () => {
    const onClick = vi.fn()
    render(<SettingsRow label="Language" value="English" onClick={onClick} />)
    await userEvent.click(screen.getByRole('button'))
    expect(onClick).toHaveBeenCalledOnce()
  })

  it('renders as div when no onClick', () => {
    const { container } = render(<SettingsRow label="About" value="v1.0.0" />)
    expect(container.querySelector('button')).toBeNull()
  })

  it('renders children instead of value when provided', () => {
    render(
      <SettingsRow label="Mode">
        <span>Custom content</span>
      </SettingsRow>
    )
    expect(screen.getByText('Custom content')).toBeTruthy()
  })
})
