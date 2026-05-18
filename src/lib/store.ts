import { create } from 'zustand'
import { persist, createJSONStorage } from 'zustand/middleware'
import type { AgentResult } from './gemma/types'

/// History entry: an `AgentResult` plus the wall-clock time it was
/// saved. Stored separately from `AgentResult` so the inference pipeline
/// stays pure — it produces the result, the persistence layer stamps
/// it. `savedAt` is a Unix-ms timestamp; entries persisted before this
/// field existed are migrated with `savedAt: 0`, which the UI renders
/// as a blank time.
export interface StoredResult {
  result: AgentResult
  savedAt: number
}

export interface GemScanStore {
  guardianModeEnabled: boolean
  trustedContactId: string | null
  preferredLanguage: string
  recentResults: StoredResult[]

  setGuardianModeEnabled: (enabled: boolean) => void
  setTrustedContactId: (contactId: string | null) => void
  setPreferredLanguage: (language: string) => void
  addResult: (result: AgentResult) => void
  clearResults: () => void
}

const MAX_RECENT_RESULTS = 100

function getDefaultLanguage(): string {
  if (typeof navigator !== 'undefined' && navigator.language) {
    return navigator.language.split('-')[0]
  }
  return 'en'
}

export const useGemScanStore = create<GemScanStore>()(
  persist(
    (set) => ({
      guardianModeEnabled: false,
      trustedContactId: null,
      preferredLanguage: getDefaultLanguage(),
      recentResults: [],

      setGuardianModeEnabled: (enabled) => set({ guardianModeEnabled: enabled }),

      setTrustedContactId: (contactId) => set({ trustedContactId: contactId }),

      setPreferredLanguage: (language) => set({ preferredLanguage: language }),

      addResult: (result) =>
        set((state) => ({
          recentResults: [
            { result, savedAt: Date.now() },
            ...state.recentResults,
          ].slice(0, MAX_RECENT_RESULTS),
        })),

      clearResults: () => set({ recentResults: [] }),
    }),
    {
      name: 'gemscan-store',
      version: 1,
      storage: createJSONStorage(() => localStorage),
      // Convert v0 entries (raw `AgentResult[]`) into v1 (`StoredResult[]`).
      // v0 entries pre-date the timestamp feature; we stamp them with
      // `savedAt: 0` so the row caption renders blank instead of a
      // misleading "Just now". New entries always get a real timestamp.
      migrate: (persistedState, fromVersion) => {
        if (fromVersion < 1 && persistedState && typeof persistedState === 'object') {
          const s = persistedState as Record<string, unknown>
          const legacy = Array.isArray(s.recentResults) ? (s.recentResults as unknown[]) : []
          s.recentResults = legacy.map((entry) => {
            // v1 entries already have the wrapper shape — leave them alone.
            if (entry && typeof entry === 'object' && 'result' in entry && 'savedAt' in entry) {
              return entry
            }
            // v0 entry: bare AgentResult. Wrap it with an unknown
            // timestamp (0) so the UI renders no time caption rather
            // than a misleading recent-looking value.
            return { result: entry, savedAt: 0 }
          })
        }
        return persistedState as GemScanStore
      },
      partialize: (state) => ({
        guardianModeEnabled: state.guardianModeEnabled,
        trustedContactId: state.trustedContactId,
        preferredLanguage: state.preferredLanguage,
        recentResults: state.recentResults,
      }),
    }
  )
)
