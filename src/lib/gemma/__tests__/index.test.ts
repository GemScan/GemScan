import { describe, it, expect, beforeEach } from 'vitest'
import { getGemmaPlugin, resetGemmaPlugin } from '../index'

describe('getGemmaPlugin', () => {
  beforeEach(() => {
    resetGemmaPlugin()
  })

  it('returns the mock plugin in jsdom (non-native)', async () => {
    const plugin = await getGemmaPlugin()
    expect(plugin).toBeDefined()
    expect(typeof plugin.isReady).toBe('function')
    expect(typeof plugin.analyse).toBe('function')
    expect(typeof plugin.downloadModels).toBe('function')
    expect(typeof plugin.getDeviceStatus).toBe('function')
    expect(typeof plugin.addListener).toBe('function')
  })

  it('returns the same instance on subsequent calls', async () => {
    const a = await getGemmaPlugin()
    const b = await getGemmaPlugin()
    expect(a).toBe(b)
  })

  it('returns a fresh instance after reset', async () => {
    const a = await getGemmaPlugin()
    resetGemmaPlugin()
    const b = await getGemmaPlugin()
    expect(a).not.toBe(b)
  })
})
