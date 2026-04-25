/* eslint-disable @typescript-eslint/no-explicit-any */
import { registerPlugin } from '@capacitor/core'
import type {
  AgentResult,
  AgentTask,
  DeviceStatus,
  GemmaPlugin,
  ModelId,
  ModelVerificationResult,
  PluginListenerHandle,
  ScreeningMode,
} from './types'

/// Capacitor's `registerPlugin` returns a proxy that forwards to the native
/// implementation when one is registered for the given name. If no native
/// implementation exists (e.g. the Swift `GemmaPlugin` class is not compiled
/// into the app target yet), method calls reject at call time with a clear
/// `PluginNotImplemented` error rather than throwing during construction.
const NativeBridge = registerPlugin<{
  isReady(): Promise<{ ready: boolean; missingModels: ModelId[] }>
  downloadModels(options: { modelIds: ModelId[] }): Promise<void>
  verifyModel(options: { modelId: ModelId }): Promise<ModelVerificationResult>
  analyse(options: { task: AgentTask }): Promise<AgentResult>
  getDeviceStatus(): Promise<DeviceStatus>
  setScreeningMode(options: { mode: ScreeningMode }): Promise<void>
  recordActivity(): Promise<void>
  addListener(event: string, handler: (data: any) => void): Promise<PluginListenerHandle>
}>('GemmaPlugin')

export class GemmaPluginNative implements GemmaPlugin {
  async isReady(): Promise<{ ready: boolean; missingModels: ModelId[] }> {
    return NativeBridge.isReady()
  }

  async downloadModels(options: { modelIds: ModelId[] }): Promise<void> {
    return NativeBridge.downloadModels(options)
  }

  async verifyModel(options: { modelId: ModelId }): Promise<ModelVerificationResult> {
    return NativeBridge.verifyModel(options)
  }

  async analyse(task: AgentTask): Promise<AgentResult> {
    return NativeBridge.analyse({ task })
  }

  async getDeviceStatus(): Promise<DeviceStatus> {
    return NativeBridge.getDeviceStatus()
  }

  async setScreeningMode(options: { mode: ScreeningMode }): Promise<void> {
    return NativeBridge.setScreeningMode(options)
  }

  async recordActivity(): Promise<void> {
    return NativeBridge.recordActivity()
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
    return NativeBridge.addListener(event, handler)
  }
}
