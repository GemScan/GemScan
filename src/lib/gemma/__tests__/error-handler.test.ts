import { describe, it, expect } from 'vitest'
import { toUserFriendlyError, makeConservativeResult } from '../error-handler'

describe('toUserFriendlyError', () => {
  it('returns a known message for ModelNotLoaded', () => {
    const err = new Error('model not available')
    err.name = 'ModelNotLoaded'
    const result = toUserFriendlyError(err)
    expect(result.message).toContain('not yet downloaded')
    expect(result.verdict).toBe('suspicious')
  })

  it('returns a fallback message for unknown errors', () => {
    const result = toUserFriendlyError(new Error('something broke'))
    expect(result.message).toContain('Something went wrong')
    expect(result.verdict).toBe('suspicious')
  })

  it('handles non-Error values', () => {
    const result = toUserFriendlyError('string error')
    expect(result.verdict).toBe('suspicious')
  })
})

describe('makeConservativeResult', () => {
  it('returns a valid AgentResult with suspicious verdict', () => {
    const result = makeConservativeResult('task-123', new Error('fail'))
    expect(result.taskId).toBe('task-123')
    expect(result.verdict).toBe('suspicious')
    expect(result.confidence).toBe(0)
    expect(result.agentId).toBe('error-handler')
    expect(result.reasoning).toHaveLength(1)
    expect(result.modelTier).toBe('e2b')
    expect(result.lowConfidenceFallback).toBe(false)
  })
})
