// Core type definitions — Spec 00 §4 + Spec 01 §4

export type AgentTaskType =
  | 'classifySMS'
  | 'classifyEmail'
  | 'checkURL'
  | 'analyseScreenshot'
  | 'explainVerdict'

export type AgentPayload =
  | { type: 'text'; content: string; language?: string }
  | { type: 'url'; url: string }
  | { type: 'image'; base64: string; mimeType: 'image/jpeg' | 'image/png' }
  | { type: 'multimodal'; parts: AgentPayload[] }

export interface AgentTask {
  id: string
  type: AgentTaskType
  payload: AgentPayload
  priority: 'realtime' | 'background'
  createdAt: number
  timeoutMs: number
}

export type ScamVerdict = 'safe' | 'suspicious' | 'scam'

export type ModelId = 'e2b'

export interface ToolCallRecord {
  serverName: string
  toolName: string
  inputSummary: string
  durationMs: number
  success: boolean
}

export interface AgentResult {
  taskId: string
  agentId: string
  verdict: ScamVerdict
  confidence: number
  /**
   * Short explanation as 1-2 bullets, total under 25 words combined.
   */
  reasoning: string[]
  /**
   * Actionable guidance for the user (40-60 words). Surfaced beneath the
   * explanation. Optional for backward-compat with results persisted before
   * this field was added.
   */
  suggestion?: string
  /**
   * The text the model actually classified — for SMS/email tasks this is
   * the user's input; for screenshot tasks it is the OCR transcription
   * produced by Apple Vision before classification. Surfaced in the
   * verdict card so the user can see what was checked. Optional for
   * back-compat with results persisted before this field was added.
   */
  analyzedText?: string
  language: string
  toolCallsLog: ToolCallRecord[]
  latencyMs: number
  modelTier: 'e2b'
  /**
   * Whether the orchestrator forced the verdict to `'scam'` because the
   * underlying agent's confidence was below the safety threshold. The
   * agent's original confidence is preserved in `confidence` so the UI can
   * show a "we weren't sure — defaulted to scam" indicator.
   */
  lowConfidenceFallback: boolean
}

export interface DeviceStatus {
  availableMemoryBytes: number
  e2bLoaded: boolean
  thermalState: 'nominal' | 'fair' | 'serious' | 'critical'
  batteryLevel: number
}

export interface PluginListenerHandle {
  remove: () => void
}

export interface ModelVerificationResult {
  valid: boolean
  reason?: string
  sizeBytes: number
}

// Payload returned by `GemmaPlugin.getPendingShare()` when the user
// arrived via the iOS Share Extension. The shape mirrors what the native
// side packages in the App Group queue: text and URL come through as
// plain strings; images arrive base64-encoded with their MIME type so
// the consumer can hand them off to the same /analyse flow the
// home-screen Upload Picture button uses.
export type PendingSharePayload =
  | { type: 'text'; content: string; id?: string }
  | { type: 'url'; url: string; id?: string }
  | {
      type: 'image'
      base64: string
      mimeType: 'image/jpeg' | 'image/png' | 'image/heic'
      id?: string
    }

export interface GemmaPlugin {
  isReady(): Promise<{ ready: boolean; missingModels: ModelId[] }>
  downloadModels(options: { modelIds: ModelId[] }): Promise<void>
  verifyModel(options: { modelId: ModelId }): Promise<ModelVerificationResult>
  analyse(task: AgentTask): Promise<AgentResult>
  warmUp(): Promise<void>
  getDeviceStatus(): Promise<DeviceStatus>
  recordActivity(): Promise<void>
  generateHaiku(): Promise<{ haiku: string }>
  getPendingShare(): Promise<{ payload: PendingSharePayload | null }>
  addListener(
    event: 'tokenStream',
    handler: (data: { taskId: string; token: string; done: boolean }) => void
  ): Promise<PluginListenerHandle>
  addListener(
    event: 'downloadProgress',
    handler: (data: {
      modelId: string
      progress: number
      bytesDownloaded: number
      totalBytes: number
    }) => void
  ): Promise<PluginListenerHandle>
  addListener(
    event: 'guardianModeChanged',
    handler: (data: { enabled: boolean; changedBy: 'self' | 'trustedContact' }) => void
  ): Promise<PluginListenerHandle>
}
