/* eslint-disable @typescript-eslint/no-explicit-any */
import { registerPlugin } from '@capacitor/core'
import type {
  AgentResult,
  AgentTask,
  DeviceStatus,
  GemmaPlugin,
  ModelId,
  ModelVerificationResult,
  PendingSharePayload,
  PluginListenerHandle,
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
  warmUp(): Promise<void>
  getDeviceStatus(): Promise<DeviceStatus>
  recordActivity(): Promise<void>
  generateHaiku(): Promise<{ haiku: string }>
  getPendingShare(): Promise<{ payload: PendingSharePayload | null }>
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

  async warmUp(): Promise<void> {
    return NativeBridge.warmUp()
  }

  async getDeviceStatus(): Promise<DeviceStatus> {
    return NativeBridge.getDeviceStatus()
  }

  async recordActivity(): Promise<void> {
    return NativeBridge.recordActivity()
  }

  async generateHaiku(): Promise<{ haiku: string }> {
    return NativeBridge.generateHaiku()
  }

  async getPendingShare(): Promise<{ payload: PendingSharePayload | null }> {
    return NativeBridge.getPendingShare()
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
