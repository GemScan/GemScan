// Core type definitions — Spec 00 §4 + Spec 01 §4

export type AgentTaskType =
  | 'classifySMS'
  | 'classifyEmail'
  | 'checkURL'
  | 'analyseScreenshot'
  | 'scoreVoice'
  | 'explainVerdict'

export type AgentPayload =
  | { type: 'text'; content: string; language?: string }
  | { type: 'url'; url: string }
  | { type: 'image'; base64: string; mimeType: 'image/jpeg' | 'image/png' }
  | { type: 'audio'; base64: string; durationSeconds: number }
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

export type ModelId = 'e2b' | 'e4b' | 'distilbert'

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
  reasoning: string[]
  language: string
  toolCallsLog: ToolCallRecord[]
  latencyMs: number
  modelTier: 'e2b' | 'e4b' | 'distilbert'
  escalatedToE4B: boolean
}

export interface DeviceStatus {
  availableMemoryBytes: number
  e2bLoaded: boolean
  e4bLoaded: boolean
  thermalState: 'nominal' | 'fair' | 'serious' | 'critical'
  batteryLevel: number
  screeningMode: 'passive' | 'active' | 'guardian'
}

export interface PluginListenerHandle {
  remove: () => void
}

export interface ModelVerificationResult {
  valid: boolean
  reason?: string
  sizeBytes: number
}

export type ScreeningMode = 'passive' | 'active' | 'guardian'

export interface GemmaPlugin {
  isReady(): Promise<{ ready: boolean; missingModels: ModelId[] }>
  downloadModels(options: { modelIds: ModelId[] }): Promise<void>
  verifyModel(options: { modelId: ModelId }): Promise<ModelVerificationResult>
  analyse(task: AgentTask): Promise<AgentResult>
  getDeviceStatus(): Promise<DeviceStatus>
  setScreeningMode(options: { mode: ScreeningMode }): Promise<void>
  recordActivity(): Promise<void>
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
