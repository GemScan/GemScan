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
} from './types'

let instance: GemmaPlugin | null = null

export async function getGemmaPlugin(): Promise<GemmaPlugin> {
  if (instance) return instance

  if (isNativePlatform()) {
    logger.info('Loading native GemmaPlugin', 'gemma/index')
    const { GemmaPluginNative } = await import('./native')
    instance = new GemmaPluginNative()
  } else {
    logger.info('Loading mock GemmaPlugin (non-native platform)', 'gemma/index')
    const { GemmaPluginMock } = await import('./mock')
    instance = new GemmaPluginMock()
  }

  return instance
}

export function resetGemmaPlugin(): void {
  instance = null
}
