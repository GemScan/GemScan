import { describe, it, expect, beforeEach } from 'vitest'
import type { AgentResult } from '../gemma/types'

// Polyfill localStorage before importing the store,
// since Node 22's built-in localStorage object lacks setItem/getItem methods
// when --localstorage-file is not configured.
const storage = new Map<string, string>()
const localStorageMock: Storage = {
  getItem: (key: string) => storage.get(key) ?? null,
  setItem: (key: string, value: string) => {
    storage.set(key, value)
  },
  removeItem: (key: string) => {
    storage.delete(key)
  },
  clear: () => {
    storage.clear()
  },
  get length() {
    return storage.size
  },
  key: (index: number) => [...storage.keys()][index] ?? null,
}
Object.defineProperty(globalThis, 'localStorage', {
  value: localStorageMock,
  writable: true,
  configurable: true,
})

// Import after localStorage is polyfilled
const { useGemScanStore } = await import('../store')

function makeResult(taskId: string): AgentResult {
  return {
    taskId,
    agentId: 'orchestrator',
    verdict: 'safe',
    confidence: 0.95,
    reasoning: ['Test reasoning'],
    language: 'en',
    toolCallsLog: [],
    latencyMs: 100,
    modelTier: 'e2b',
    escalatedToE4B: false,
  }
}

describe('useGemScanStore', () => {
  beforeEach(() => {
    storage.clear()
    const { setState } = useGemScanStore
    setState({
      screeningMode: 'active',
      guardianModeEnabled: false,
      trustedContactId: null,
      preferredLanguage: 'en',
      recentResults: [],
    })
  })

  describe('initial state', () => {
    it('has screeningMode === "active"', () => {
      const state = useGemScanStore.getState()
      expect(state.screeningMode).toBe('active')
    })

    it('has guardianModeEnabled === false', () => {
      const state = useGemScanStore.getState()
      expect(state.guardianModeEnabled).toBe(false)
    })
  })

  describe('setScreeningMode', () => {
    it('updates screening mode', () => {
      useGemScanStore.getState().setScreeningMode('guardian')
      expect(useGemScanStore.getState().screeningMode).toBe('guardian')
    })
  })

  describe('setGuardianModeEnabled', () => {
    it('updates guardian mode', () => {
      useGemScanStore.getState().setGuardianModeEnabled(true)
      expect(useGemScanStore.getState().guardianModeEnabled).toBe(true)
    })
  })

  describe('setTrustedContactId', () => {
    it('updates trusted contact id', () => {
      useGemScanStore.getState().setTrustedContactId('contact-123')
      expect(useGemScanStore.getState().trustedContactId).toBe('contact-123')
    })

    it('can set to null', () => {
      useGemScanStore.getState().setTrustedContactId('contact-123')
      useGemScanStore.getState().setTrustedContactId(null)
      expect(useGemScanStore.getState().trustedContactId).toBeNull()
    })
  })

  describe('addResult', () => {
    it('pushes to recentResults array', () => {
      const result = makeResult('task-001')
      useGemScanStore.getState().addResult(result)

      const state = useGemScanStore.getState()
      expect(state.recentResults).toHaveLength(1)
      expect(state.recentResults[0].taskId).toBe('task-001')
    })

    it('prepends new results', () => {
      useGemScanStore.getState().addResult(makeResult('task-001'))
      useGemScanStore.getState().addResult(makeResult('task-002'))

      const state = useGemScanStore.getState()
      expect(state.recentResults[0].taskId).toBe('task-002')
      expect(state.recentResults[1].taskId).toBe('task-001')
    })
  })

  describe('persist', () => {
    it('has persist name "gemscan-store"', () => {
      const persistApi = (
        useGemScanStore as unknown as {
          persist: { getOptions: () => { name: string } }
        }
      ).persist
      expect(persistApi.getOptions().name).toBe('gemscan-store')
    })
  })
})
