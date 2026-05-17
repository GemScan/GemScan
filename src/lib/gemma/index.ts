import type { GemmaPlugin } from './types'
import { isNativePlatform } from '../platform'
import { logger } from '../logger'

export type { GemmaPlugin } from './types'
export type {
  AgentTask,
  AgentTaskType,
  AgentPayload,
  AgentResult,
  ScamVerdict,
  ModelId,
  ToolCallRecord,
  DeviceStatus,
  PluginListenerHandle,
  ModelVerificationResult,
} from './types'

let instance: GemmaPlugin | null = null
let usingMockOnNative = false

export function isUsingMockOnNative(): boolean {
  return usingMockOnNative
}

/// Returns whether the loaded plugin is the mock (either because we're on
/// web, or because the native bridge isn't actually implemented and we
/// fell back).
export function isMockPlugin(): boolean {
  return !isNativePlatform() || usingMockOnNative
}

export async function getGemmaPlugin(): Promise<GemmaPlugin> {
  if (instance) return instance

  if (isNativePlatform()) {
    logger.info('Loading native GemmaPlugin', 'gemma/index')
    const { GemmaPluginNative } = await import('./native')
    const native = new GemmaPluginNative()

    // Probe: does the native side actually implement the plugin? On iOS
    // builds where `GemmaPlugin.swift` isn't compiled into the App target,
    // Capacitor's bridge proxy will reject every call with a
    // `PluginNotImplemented` error. Detect that once and silently fall
    // back to the mock so the UI is still usable for testing.
    try {
      await native.isReady()
      instance = native
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err)
      if (
        /not implemented/i.test(message) ||
        /UNIMPLEMENTED/.test(message) ||
        /registerPlugin/.test(message)
      ) {
        logger.warn(
          `Native GemmaPlugin not implemented on this build — falling back to mock. (${message})`,
          'gemma/index'
        )
        usingMockOnNative = true
        const { GemmaPluginMock } = await import('./mock')
        instance = new GemmaPluginMock()
      } else {
        // A different error — surface it; not our concern to swallow.
        throw err
      }
    }
  } else {
    logger.info('Loading mock GemmaPlugin (non-native platform)', 'gemma/index')
    const { GemmaPluginMock } = await import('./mock')
    instance = new GemmaPluginMock()
  }

  return instance
}

export function resetGemmaPlugin(): void {
  instance = null
  usingMockOnNative = false
}
