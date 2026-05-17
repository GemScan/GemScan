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
import { goldenFixtures } from './__fixtures__/golden'
import { logger } from '../logger'

const MODULE = 'GemmaPluginMock'

function delay(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms))
}

function pickFixture(task: AgentTask): AgentResult {
  const payload = task.payload

  if (task.type === 'checkURL') {
    if (payload.type === 'url' && /amazon\.com|google\.com|apple\.com/.test(payload.url)) {
      return { ...goldenFixtures['safe-url-known'], taskId: task.id }
    }
    return { ...goldenFixtures['scam-url-phishing'], taskId: task.id }
  }

  if (task.type === 'analyseScreenshot') {
    if (payload.type === 'image' && payload.mimeType === 'image/png') {
      return { ...goldenFixtures['scam-screenshot-fake-login'], taskId: task.id }
    }
    return { ...goldenFixtures['safe-screenshot-receipt'], taskId: task.id }
  }

  if (task.type === 'classifyEmail') {
    if (payload.type === 'text' && /lottery|winner|prize|won/i.test(payload.content)) {
      return { ...goldenFixtures['scam-email-lottery'], taskId: task.id }
    }
    return { ...goldenFixtures['safe-email-receipt'], taskId: task.id }
  }

  if (task.type === 'classifySMS') {
    if (payload.type === 'text' && /bank|account.*lock|suspend/i.test(payload.content)) {
      return { ...goldenFixtures['scam-sms-bank'], taskId: task.id }
    }
    if (payload.type === 'text' && /promo|offer|limited/i.test(payload.content)) {
      return { ...goldenFixtures['suspicious-sms-promo'], taskId: task.id }
    }
    if (payload.type === 'text' && /known-contact/i.test(payload.content)) {
      return { ...goldenFixtures['safe-known-contact'], taskId: task.id }
    }
  }

  return { ...goldenFixtures['default'], taskId: task.id }
}

type ListenerEvent = 'tokenStream' | 'downloadProgress' | 'guardianModeChanged'
// eslint-disable-next-line @typescript-eslint/no-explicit-any
type ListenerHandler = (data: any) => void

export class GemmaPluginMock implements GemmaPlugin {
  private modelsDownloaded = new Set<ModelId>()
  private modelsLoadedInRAM = new Set<ModelId>()
  private listeners = new Map<ListenerEvent, Set<ListenerHandler>>()
  private unloadTimer: ReturnType<typeof setTimeout> | null = null

  async recordActivity(): Promise<void> {
    logger.info('recordActivity', MODULE)
    this.rescheduleUnload()
    // Reload models if they were unloaded.
    for (const m of this.modelsDownloaded) {
      this.modelsLoadedInRAM.add(m)
    }
  }

  /// Mock uses a compressed idle timer (60s) so devs can validate the flow
  /// in seconds. Real plugin uses 15 min.
  private rescheduleUnload(): void {
    if (this.unloadTimer) clearTimeout(this.unloadTimer)
    this.unloadTimer = setTimeout(() => {
      logger.info('Mock idle unload', MODULE)
      this.modelsLoadedInRAM.clear()
    }, 60 * 1000)
  }

  async isReady(): Promise<{ ready: boolean; missingModels: ModelId[] }> {
    logger.info('isReady() called', MODULE)
    const allModels: ModelId[] = ['e2b']
    const missingModels = allModels.filter((m) => !this.modelsDownloaded.has(m))
    return { ready: missingModels.length === 0, missingModels }
  }

  async downloadModels(options: { modelIds: ModelId[] }): Promise<void> {
    logger.info('downloadModels() called', MODULE, { modelIds: options.modelIds })

    for (const modelId of options.modelIds) {
      const totalBytes = 3_400_000_000
      const steps = 20
      const chunkSize = totalBytes / steps

      for (let i = 1; i <= steps; i++) {
        await delay(40)
        this.emit('downloadProgress', {
          modelId,
          progress: i / steps,
          bytesDownloaded: Math.round(chunkSize * i),
          totalBytes,
        })
      }

      this.modelsDownloaded.add(modelId)
      // Newly downloaded models are warmed into RAM immediately, mirroring
      // the native plugin's `warmLoadE2B` behavior.
      this.modelsLoadedInRAM.add(modelId)
      logger.info(`Model ${modelId} downloaded (mock)`, MODULE)
    }
    this.rescheduleUnload()
  }

  async verifyModel(options: { modelId: ModelId }): Promise<ModelVerificationResult> {
    logger.info('verifyModel() called', MODULE, { modelId: options.modelId })
    await delay(150) // simulate native verification work

    if (!this.modelsDownloaded.has(options.modelId)) {
      return { valid: false, reason: 'Not downloaded', sizeBytes: 0 }
    }

    return { valid: true, sizeBytes: 3_400_000_000 }
  }

  async warmUp(): Promise<void> {
    logger.info('warmUp() called', MODULE)
    // Mirror native: only "load" what's actually been downloaded.
    for (const m of this.modelsDownloaded) {
      this.modelsLoadedInRAM.add(m)
    }
    this.rescheduleUnload()
  }

  async analyse(task: AgentTask): Promise<AgentResult> {
    logger.info('analyse() called', MODULE, { taskId: task.id, type: task.type })

    const result = pickFixture(task)
    const simulatedLatency = result.lowConfidenceFallback ? 400 : 100

    // Simulate token streaming
    const tokens = result.reasoning.join(' ').split(' ')
    for (let i = 0; i < tokens.length; i++) {
      await delay(simulatedLatency / tokens.length)
      this.emit('tokenStream', {
        taskId: task.id,
        token: tokens[i] + ' ',
        done: i === tokens.length - 1,
      })
    }

    return {
      ...result,
      latencyMs: simulatedLatency,
    }
  }

  async generateHaiku(): Promise<{ haiku: string }> {
    logger.info('generateHaiku() called', MODULE)
    await delay(450)
    const haikus = [
      'Tiny glowing screen\nThumbs scroll past a thousand lives\nBattery weeps red',
      'Phone says low power\nCharger lives in the next room\nDoom-scroll a bit more',
      'Notifications buzz\nIgnoring my friends is hard\nThe cat memes win out',
      'Five percent battery\nAirport WiFi will not load\nDestiny: a book',
    ]
    return { haiku: haikus[Math.floor(Math.random() * haikus.length)] }
  }

  // No share queue in the browser mock — the iOS share extension is the
  // only producer. Resolve to null so the JS app-url-open path can no-op
  // cleanly when running in dev / web preview.
  async getPendingShare(): Promise<{ payload: PendingSharePayload | null }> {
    return { payload: null }
  }

  /** Simulate a guardian mode state change (for testing and UI development). */
  emitGuardianModeChanged(enabled: boolean, changedBy: 'self' | 'trustedContact' = 'self'): void {
    logger.info(`guardianModeChanged: enabled=${String(enabled)}`, MODULE)
    this.emit('guardianModeChanged', { enabled, changedBy })
  }

  async getDeviceStatus(): Promise<DeviceStatus> {
    logger.debug('getDeviceStatus() called', MODULE)
    return {
      availableMemoryBytes: 3_000_000_000,
      e2bLoaded: this.modelsLoadedInRAM.has('e2b'),
      thermalState: 'nominal',
      batteryLevel: 0.85,
    }
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
  async addListener(event: ListenerEvent, handler: ListenerHandler): Promise<PluginListenerHandle> {
    if (!this.listeners.has(event)) {
      this.listeners.set(event, new Set())
    }
    this.listeners.get(event)?.add(handler)
    logger.debug(`Listener added for "${event}"`, MODULE)

    return {
      remove: () => {
        this.listeners.get(event)?.delete(handler)
        logger.debug(`Listener removed for "${event}"`, MODULE)
      },
    }
  }

  private emit(event: ListenerEvent, data: Record<string, unknown>): void {
    const handlers = this.listeners.get(event)
    if (handlers) {
      for (const handler of handlers) {
        handler(data)
      }
    }
  }
}
