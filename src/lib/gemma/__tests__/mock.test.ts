import { describe, it, expect, beforeEach } from 'vitest'
import { GemmaPluginMock } from '../mock'
import type { AgentTask, AgentResult } from '../types'

describe('GemmaPluginMock', () => {
  let mock: GemmaPluginMock

  beforeEach(() => {
    mock = new GemmaPluginMock()
  })

  describe('isReady', () => {
    it('returns { ready: false, missingModels: [...] } when no models downloaded', async () => {
      const status = await mock.isReady()
      expect(status.ready).toBe(false)
      expect(status.missingModels).toEqual(expect.arrayContaining(['e2b', 'e4b', 'distilbert']))
      expect(status.missingModels).toHaveLength(3)
    })
  })

  describe('analyse', () => {
    it('returns a valid AgentResult within 1000ms', async () => {
      const task: AgentTask = {
        id: 'test-task-001',
        type: 'classifySMS',
        payload: { type: 'text', content: 'Hello from a known-contact' },
        priority: 'realtime',
        createdAt: Date.now(),
        timeoutMs: 5000,
      }

      const start = Date.now()
      const result: AgentResult = await mock.analyse(task)
      const elapsed = Date.now() - start

      expect(elapsed).toBeLessThan(1000)
      expect(result.taskId).toBe('test-task-001')
      expect(result.verdict).toBeDefined()
      expect(['safe', 'suspicious', 'scam']).toContain(result.verdict)
      expect(result.confidence).toBeGreaterThanOrEqual(0)
      expect(result.confidence).toBeLessThanOrEqual(1)
      expect(Array.isArray(result.reasoning)).toBe(true)
      expect(Array.isArray(result.toolCallsLog)).toBe(true)
      expect(typeof result.escalatedToE4B).toBe('boolean')
    })
  })

  describe('addListener', () => {
    it('returns a handle with remove()', async () => {
      const handle = await mock.addListener('tokenStream', () => {})
      expect(handle).toBeDefined()
      expect(typeof handle.remove).toBe('function')
      handle.remove()
    })
  })

  describe('downloadModels', () => {
    it('fires progress events during download', async () => {
      const events: { modelId: string; progress: number }[] = []

      await mock.addListener('downloadProgress', (data) => {
        events.push({ modelId: data.modelId, progress: data.progress })
      })

      await mock.downloadModels({ modelIds: ['e2b'] })

      expect(events.length).toBeGreaterThan(0)
      expect(events[0].modelId).toBe('e2b')
      expect(events[events.length - 1].progress).toBe(1)

      const status = await mock.isReady()
      expect(status.missingModels).not.toContain('e2b')
    })
  })
})
