/* eslint-disable @typescript-eslint/no-explicit-any */
import type {
  AgentResult,
  AgentTask,
  DeviceStatus,
  GemmaPlugin,
  ModelId,
  PluginListenerHandle,
} from './types'

function getCapacitorPlugin(): any {
  const cap = (window as any).Capacitor
  if (!cap) {
    throw new Error(
      'Capacitor is not available — native.ts should only be used on native platforms'
    )
  }
  return cap.Plugins?.GemmaPlugin ?? cap.registerPlugin('GemmaPlugin')
}

export class GemmaPluginNative implements GemmaPlugin {
  private plugin: any

  constructor() {
    this.plugin = getCapacitorPlugin()
  }

  async isReady(): Promise<{ ready: boolean; missingModels: ModelId[] }> {
    return this.plugin.isReady()
  }

  async downloadModels(options: { modelIds: ModelId[] }): Promise<void> {
    return this.plugin.downloadModels(options)
  }

  async analyse(task: AgentTask): Promise<AgentResult> {
    return this.plugin.analyse({ task })
  }

  async getDeviceStatus(): Promise<DeviceStatus> {
    return this.plugin.getDeviceStatus()
  }

  async addListener(
    event: 'tokenStream',
    handler: (data: { taskId: string; token: string; done: boolean }) => void
  ): Promise<PluginListenerHandle>
  async addListener(
    event: 'downloadProgress',
    handler: (data: {
      modelId: string
      progress: number
      bytesDownloaded: number
      totalBytes: number
    }) => void
  ): Promise<PluginListenerHandle>
  async addListener(
    event: 'guardianModeChanged',
    handler: (data: { enabled: boolean; changedBy: 'self' | 'trustedContact' }) => void
  ): Promise<PluginListenerHandle>
  async addListener(event: string, handler: (data: any) => void): Promise<PluginListenerHandle> {
    return this.plugin.addListener(event, handler)
  }
}
