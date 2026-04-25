/* eslint-disable @typescript-eslint/no-explicit-any */
import { describe, it, expect, afterEach } from 'vitest'
import { isNativePlatform } from '../platform'

describe('isNativePlatform', () => {
  afterEach(() => {
    delete (window as any).Capacitor
  })

  it('returns false in jsdom (no window.Capacitor)', () => {
    expect(isNativePlatform()).toBe(false)
  })

  it('returns true when window.Capacitor is injected', () => {
    ;(window as any).Capacitor = {
      isNativePlatform: () => true,
    }
    expect(isNativePlatform()).toBe(true)
  })
})
