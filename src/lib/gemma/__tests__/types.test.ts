import { describe, it, expect } from 'vitest'
import type { AgentTask, AgentResult, ScamVerdict, AgentPayload, ToolCallRecord } from '../types'

describe('AgentTask serialization', () => {
  it('round-trips through JSON.stringify/parse with all fields intact', () => {
    const task: AgentTask = {
      id: 'task-001',
      type: 'classifySMS',
      payload: { type: 'text', content: 'Hello world', language: 'en' },
      priority: 'realtime',
      createdAt: Date.now(),
      timeoutMs: 5000,
    }

    const serialized = JSON.stringify(task)
    const deserialized: AgentTask = JSON.parse(serialized)

    expect(deserialized).toEqual(task)
    expect(deserialized.id).toBe(task.id)
    expect(deserialized.type).toBe(task.type)
    expect(deserialized.priority).toBe(task.priority)
    expect(deserialized.createdAt).toBe(task.createdAt)
    expect(deserialized.timeoutMs).toBe(task.timeoutMs)
  })

  it('preserves discriminated union payload through serialization', () => {
    const imagePayload: AgentPayload = {
      type: 'image',
      base64: 'abc123',
      mimeType: 'image/png',
    }

    const task: AgentTask = {
      id: 'task-002',
      type: 'analyseScreenshot',
      payload: imagePayload,
      priority: 'background',
      createdAt: Date.now(),
      timeoutMs: 10000,
    }

    const deserialized: AgentTask = JSON.parse(JSON.stringify(task))
    expect(deserialized.payload).toEqual(imagePayload)

    if (deserialized.payload.type === 'image') {
      expect(deserialized.payload.base64).toBe('abc123')
      expect(deserialized.payload.mimeType).toBe('image/png')
    } else {
      throw new Error('Expected payload type to be image')
    }
  })
})

describe('AgentResult serialization', () => {
  it('round-trips with toolCallsLog array and lowConfidenceFallback boolean', () => {
    const toolCall: ToolCallRecord = {
      serverName: 'url_reputation',
      toolName: 'check_url',
      inputSummary: 'https://example.com',
      durationMs: 45,
      success: true,
    }

    const result: AgentResult = {
      taskId: 'task-003',
      agentId: 'orchestrator',
      verdict: 'scam',
      confidence: 0.94,
      reasoning: ['Suspicious URL detected.', 'Domain mimics a known brand.'],
      language: 'en',
      toolCallsLog: [toolCall],
      latencyMs: 680,
      modelTier: 'e2b',
      lowConfidenceFallback: true,
    }

    const deserialized: AgentResult = JSON.parse(JSON.stringify(result))

    expect(deserialized).toEqual(result)
    expect(deserialized.toolCallsLog).toHaveLength(1)
    expect(deserialized.toolCallsLog[0].serverName).toBe('url_reputation')
    expect(deserialized.lowConfidenceFallback).toBe(true)
    expect(typeof deserialized.lowConfidenceFallback).toBe('boolean')
  })

  it('round-trips with empty toolCallsLog', () => {
    const result: AgentResult = {
      taskId: 'task-004',
      agentId: 'orchestrator',
      verdict: 'safe',
      confidence: 0.97,
      reasoning: ['Sender matches known contact.'],
      language: 'en',
      toolCallsLog: [],
      latencyMs: 120,
      modelTier: 'e2b',
      lowConfidenceFallback: false,
    }

    const deserialized: AgentResult = JSON.parse(JSON.stringify(result))
    expect(deserialized.toolCallsLog).toEqual([])
    expect(deserialized.lowConfidenceFallback).toBe(false)
  })
})

describe('ScamVerdict', () => {
  it('has exactly the values safe, suspicious, and scam', () => {
    const validVerdicts: ScamVerdict[] = ['safe', 'suspicious', 'scam']
    expect(validVerdicts).toHaveLength(3)
    expect(validVerdicts).toContain('safe')
    expect(validVerdicts).toContain('suspicious')
    expect(validVerdicts).toContain('scam')
  })

  it('is assignable from string literals', () => {
    const safe: ScamVerdict = 'safe'
    const suspicious: ScamVerdict = 'suspicious'
    const scam: ScamVerdict = 'scam'

    expect(safe).toBe('safe')
    expect(suspicious).toBe('suspicious')
    expect(scam).toBe('scam')
  })
})

describe('AgentPayload discriminated union', () => {
  it('narrows correctly on type field for text', () => {
    const payload: AgentPayload = {
      type: 'text',
      content: 'Hello',
      language: 'en',
    }

    if (payload.type === 'text') {
      expect(payload.content).toBe('Hello')
      expect(payload.language).toBe('en')
    } else {
      throw new Error('Expected text payload')
    }
  })

  it('narrows correctly on type field for url', () => {
    const payload: AgentPayload = {
      type: 'url',
      url: 'https://example.com',
    }

    if (payload.type === 'url') {
      expect(payload.url).toBe('https://example.com')
    } else {
      throw new Error('Expected url payload')
    }
  })

  it('narrows correctly on type field for image', () => {
    const payload: AgentPayload = {
      type: 'image',
      base64: 'data',
      mimeType: 'image/jpeg',
    }

    if (payload.type === 'image') {
      expect(payload.base64).toBe('data')
      expect(payload.mimeType).toBe('image/jpeg')
    } else {
      throw new Error('Expected image payload')
    }
  })

  it('narrows correctly on type field for multimodal', () => {
    const inner: AgentPayload = { type: 'text', content: 'inner' }
    const payload: AgentPayload = {
      type: 'multimodal',
      parts: [inner],
    }

    if (payload.type === 'multimodal') {
      expect(payload.parts).toHaveLength(1)
      expect(payload.parts[0].type).toBe('text')
    } else {
      throw new Error('Expected multimodal payload')
    }
  })
})
