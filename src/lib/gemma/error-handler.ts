import type { AgentResult, ScamVerdict } from './types'
import { logger } from '../logger'

const MODULE = 'error-handler'

interface UserFriendlyError {
  message: string
  verdict: ScamVerdict
}

const ERROR_MESSAGES: Record<string, string> = {
  ModelNotLoaded: 'AI models are not yet downloaded. Please complete setup first.',
  AnalysisTimeout: 'Analysis took too long. The content has been marked as suspicious for safety.',
  InsufficientMemory: 'Not enough memory to run analysis. Please close other apps and try again.',
  NetworkError: 'A network error occurred. Analysis will continue with on-device models only.',
}

export function toUserFriendlyError(error: unknown): UserFriendlyError {
  const errorMessage = error instanceof Error ? error.message : String(error)
  const errorName = error instanceof Error ? error.name : 'UnknownError'

  logger.error(`GemScan error: ${errorMessage}`, MODULE, {
    errorName,
    errorMessage,
  })

  const knownMessage = ERROR_MESSAGES[errorName]

  return {
    message:
      knownMessage ??
      'Something went wrong. For your safety, this content has been flagged as suspicious.',
    verdict: 'suspicious' as ScamVerdict,
  }
}

export function makeConservativeResult(taskId: string, error: unknown): AgentResult {
  const friendly = toUserFriendlyError(error)

  return {
    taskId,
    agentId: 'error-handler',
    verdict: friendly.verdict,
    confidence: 0,
    reasoning: [friendly.message],
    language: 'en',
    toolCallsLog: [],
    latencyMs: 0,
    modelTier: 'e2b',
    escalatedToE4B: false,
  }
}
