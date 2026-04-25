import { create } from 'zustand'
import { persist, createJSONStorage } from 'zustand/middleware'
import type { AgentResult } from './gemma/types'

export interface GemScanStore {
  screeningMode: 'passive' | 'active' | 'guardian'
  guardianModeEnabled: boolean
  trustedContactId: string | null
  preferredLanguage: string
  recentResults: AgentResult[]

  setScreeningMode: (mode: 'passive' | 'active' | 'guardian') => void
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
      screeningMode: 'active',
      guardianModeEnabled: false,
      trustedContactId: null,
      preferredLanguage: getDefaultLanguage(),
      recentResults: [],

      setScreeningMode: (mode) => set({ screeningMode: mode }),

      setGuardianModeEnabled: (enabled) => set({ guardianModeEnabled: enabled }),

      setTrustedContactId: (contactId) => set({ trustedContactId: contactId }),

      setPreferredLanguage: (language) => set({ preferredLanguage: language }),

      addResult: (result) =>
        set((state) => ({
          recentResults: [result, ...state.recentResults].slice(0, MAX_RECENT_RESULTS),
        })),

      clearResults: () => set({ recentResults: [] }),
    }),
    {
      name: 'gemscan-store',
      storage: createJSONStorage(() => localStorage),
      partialize: (state) => ({
        screeningMode: state.screeningMode,
        guardianModeEnabled: state.guardianModeEnabled,
        trustedContactId: state.trustedContactId,
        preferredLanguage: state.preferredLanguage,
        recentResults: state.recentResults,
      }),
    }
  )
)
