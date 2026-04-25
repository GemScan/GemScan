import { describe, it, expect } from 'vitest'
import { mockOrchestrate } from '../mock-orchestrator'
import type { AgentTask } from '../../gemma/types'

function makeTask(type: AgentTask['type']): AgentTask {
  return {
    id: `test-${type}`,
    type,
    payload: { type: 'text', content: 'test input' },
    priority: 'realtime',
    createdAt: Date.now(),
    timeoutMs: 5000,
  }
}

describe('mockOrchestrate', () => {
  it('returns a result for classifySMS', async () => {
    const result = await mockOrchestrate(makeTask('classifySMS'))
    expect(result.taskId).toBe('test-classifySMS')
    expect(result.agentId).toBe('text-agent')
    expect(['safe', 'suspicious', 'scam']).toContain(result.verdict)
    expect(result.confidence).toBeGreaterThan(0)
    expect(result.reasoning.length).toBeGreaterThan(0)
  })

  it('returns a result for checkURL', async () => {
    const result = await mockOrchestrate(makeTask('checkURL'))
    expect(result.taskId).toBe('test-checkURL')
    expect(result.agentId).toBe('url-agent')
  })

  it('returns a result for analyseScreenshot', async () => {
    const result = await mockOrchestrate(makeTask('analyseScreenshot'))
    expect(result.agentId).toBe('image-agent')
    expect(result.modelTier).toBe('e4b')
  })

  it('returns a result for scoreVoice', async () => {
    const result = await mockOrchestrate(makeTask('scoreVoice'))
    expect(result.agentId).toBe('voice-agent')
  })

  it('returns a result for explainVerdict', async () => {
    const result = await mockOrchestrate(makeTask('explainVerdict'))
    expect(result.agentId).toBe('orchestrator')
  })

  it('populates taskId from the input task', async () => {
    const task = makeTask('classifyEmail')
    const result = await mockOrchestrate(task)
    expect(result.taskId).toBe(task.id)
  })
})
