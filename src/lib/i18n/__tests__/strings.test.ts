import { describe, it, expect } from 'vitest'
import { t } from '../strings'

// We need to verify all locales have all keys and t() returns correct strings.
// We import the strings module and introspect it.

// The locales and keys are defined in strings.ts
const SUPPORTED_LOCALES = ['en', 'hi', 'ja', 'es', 'zh-Hans'] as const
const EXPECTED_KEYS = [
  'appName',
  'checkButton',
  'verdictSafe',
  'verdictSuspicious',
  'verdictScam',
  'confidence',
  'reasoning',
  'share',
  'dismiss',
  'guardianMode',
  'settings',
  'onboarding',
  'downloadModels',
  'downloading',
  'analysing',
  'analyse',
  'analyseMessage',
  'pastePrompt',
  'recentResults',
  'language',
  'enableGuardian',
  'trustedContact',
  'guardianDescription',
  'consentMessage',
  'iAgree',
  'modelsReady',
  'getStarted',
  'save',
  'searchContacts',
  'guardianActive',
  'pause',
  'modelTier',
  'complete',
] as const

describe('i18n strings', () => {
  describe('completeness', () => {
    for (const locale of SUPPORTED_LOCALES) {
      it(`locale "${locale}" has all expected keys`, () => {
        for (const key of EXPECTED_KEYS) {
          const value = t(key, locale)
          // The value should not fall back to the key itself (which would mean it is missing)
          // For non-English locales, the value should be different from the key
          // (except appName which is the same across locales)
          expect(value).toBeTruthy()
          expect(value).not.toBe('')
          // Ensure we got an actual translation, not just the key echoed back
          if (key !== 'appName') {
            expect(value).not.toBe(key)
          }
        }
      })
    }
  })

  describe('t() function', () => {
    it('returns English string for en locale', () => {
      expect(t('checkButton', 'en')).toBe('Check this for me')
    })

    it('returns Hindi string for hi locale', () => {
      expect(t('checkButton', 'hi')).toBe('यह मेरे लिए जांचें')
    })

    it('returns Japanese string for ja locale', () => {
      expect(t('checkButton', 'ja')).toBe('これを確認して')
    })

    it('returns Spanish string for es locale', () => {
      expect(t('checkButton', 'es')).toBe('Revisa esto por mi')
    })

    it('returns Chinese string for zh-Hans locale', () => {
      expect(t('checkButton', 'zh-Hans')).toBe('帮我检查')
    })

    it('falls back to English for unknown locale', () => {
      expect(t('checkButton', 'fr')).toBe('Check this for me')
    })

    it('falls back to base language for region-specific locale', () => {
      // "es-MX" should resolve to "es"
      expect(t('checkButton', 'es-MX')).toBe('Revisa esto por mi')
    })

    it('maps "zh" to "zh-Hans"', () => {
      expect(t('checkButton', 'zh')).toBe('帮我检查')
    })

    it('returns the key itself for unknown key', () => {
      expect(t('nonExistentKey', 'en')).toBe('nonExistentKey')
    })

    it('defaults to English when no locale is provided', () => {
      expect(t('appName')).toBe('GemScan')
    })
  })

  describe('appName is consistent across locales', () => {
    for (const locale of SUPPORTED_LOCALES) {
      it(`appName is "GemScan" in "${locale}"`, () => {
        expect(t('appName', locale)).toBe('GemScan')
      })
    }
  })

  describe('verdict labels are non-empty across locales', () => {
    const verdictKeys = ['verdictSafe', 'verdictSuspicious', 'verdictScam']

    for (const locale of SUPPORTED_LOCALES) {
      for (const key of verdictKeys) {
        it(`${key} in "${locale}" is non-empty`, () => {
          const value = t(key, locale)
          expect(value.length).toBeGreaterThan(0)
        })
      }
    }
  })
})
