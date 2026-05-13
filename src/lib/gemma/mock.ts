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
import { goldenFixtures } from './__fixtures__/golden'
import { logger } from '../logger'

const MODULE = 'GemmaPluginMock'

function delay(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms))
}

function pickFixture(task: AgentTask): AgentResult {
  const payload = task.payload

  if (task.type === 'scoreVoice') {
    return { ...goldenFixtures['scam-voice-deepfake'], taskId: task.id }
  }

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
  private screeningMode: ScreeningMode = 'active'
  private unloadTimer: ReturnType<typeof setTimeout> | null = null

  async setScreeningMode(options: { mode: ScreeningMode }): Promise<void> {
    logger.info(`setScreeningMode: ${options.mode}`, MODULE)
    this.screeningMode = options.mode
    this.rescheduleUnload()
  }

  async recordActivity(): Promise<void> {
    logger.info(`recordActivity (mode=${this.screeningMode})`, MODULE)
    if (this.screeningMode === 'active' || this.screeningMode === 'guardian') {
      this.rescheduleUnload()
    }
    // Reload models if they were unloaded.
    for (const m of this.modelsDownloaded) {
      this.modelsLoadedInRAM.add(m)
    }
  }

  /// Mock uses compressed timings so devs can validate the flow in seconds:
  /// passive ⇒ 30s, active/guardian idle ⇒ 60s. Real plugin uses 5min / 15min.
  private rescheduleUnload(): void {
    if (this.unloadTimer) clearTimeout(this.unloadTimer)
    const delaySeconds = this.screeningMode === 'passive' ? 30 : 60
    this.unloadTimer = setTimeout(() => {
      logger.info(`Mock idle unload (mode=${this.screeningMode})`, MODULE)
      this.modelsLoadedInRAM.clear()
    }, delaySeconds * 1000)
  }

  async isReady(): Promise<{ ready: boolean; missingModels: ModelId[] }> {
    logger.info('isReady() called', MODULE)
    const allModels: ModelId[] = ['e2b', 'distilbert']
    const missingModels = allModels.filter((m) => !this.modelsDownloaded.has(m))
    return { ready: missingModels.length === 0, missingModels }
  }

  async downloadModels(options: { modelIds: ModelId[] }): Promise<void> {
    logger.info('downloadModels() called', MODULE, { modelIds: options.modelIds })

    for (const modelId of options.modelIds) {
      const totalBytes =
        modelId === 'e2b' ? 3_400_000_000 :
        5_000_000
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

    const sizeBytes =
      options.modelId === 'e2b' ? 3_400_000_000 :
      5_000_000

    return { valid: true, sizeBytes }
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
      screeningMode: 'active',
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
