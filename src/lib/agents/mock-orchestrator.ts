/**
 * Mock orchestrator for the six-agent pipeline.
 *
 * Routes tasks to golden fixture responses by task type, simulating
 * the on-device agent pipeline for development and testing.
 */

import type { AgentTask, AgentResult, ScamVerdict, AgentTaskType } from '../gemma/types'

// ---------------------------------------------------------------------------
// Golden fixtures
// ---------------------------------------------------------------------------

const GOLDEN_FIXTURES: Record<AgentTaskType, AgentResult> = {
  classifySMS: {
    taskId: '',
    agentId: 'text-agent',
    verdict: 'safe' as ScamVerdict,
    confidence: 0.92,
    reasoning: [
      'Message does not contain urgent language or suspicious links.',
      'Sender matches a known contact pattern.',
    ],
    language: 'en',
    toolCallsLog: [
      {
        serverName: 'scam_patterns',
        toolName: 'check_patterns',
        inputSummary: 'SMS content hash',
        durationMs: 12,
        success: true,
      },
      {
        serverName: 'sqlite_vec',
        toolName: 'similarity_search',
        inputSummary: 'Embedding lookup',
        durationMs: 8,
        success: true,
      },
    ],
    latencyMs: 340,
    modelTier: 'e2b',
    escalatedToE4B: false,
  },

  classifyEmail: {
    taskId: '',
    agentId: 'text-agent',
    verdict: 'suspicious' as ScamVerdict,
    confidence: 0.68,
    reasoning: [
      'Email contains a link that does not match the claimed sender domain.',
      'Urgency language detected: "act now" and "account suspended".',
      'Escalated to E4B for deeper analysis.',
    ],
    language: 'en',
    toolCallsLog: [
      {
        serverName: 'scam_patterns',
        toolName: 'check_patterns',
        inputSummary: 'Email content hash',
        durationMs: 15,
        success: true,
      },
      {
        serverName: 'url_reputation',
        toolName: 'check_url',
        inputSummary: 'Extracted URL',
        durationMs: 45,
        success: true,
      },
    ],
    latencyMs: 1200,
    modelTier: 'e4b',
    escalatedToE4B: true,
  },

  checkURL: {
    taskId: '',
    agentId: 'url-agent',
    verdict: 'scam' as ScamVerdict,
    confidence: 0.97,
    reasoning: [
      'Domain was registered less than 7 days ago.',
      'URL reputation score is very low across multiple databases.',
      'Domain name mimics a well-known bank.',
    ],
    language: 'en',
    toolCallsLog: [
      {
        serverName: 'url_reputation',
        toolName: 'check_url',
        inputSummary: 'Full URL check',
        durationMs: 38,
        success: true,
      },
      {
        serverName: 'whois',
        toolName: 'lookup',
        inputSummary: 'Domain WHOIS',
        durationMs: 120,
        success: true,
      },
    ],
    latencyMs: 520,
    modelTier: 'e2b',
    escalatedToE4B: false,
  },

  analyseScreenshot: {
    taskId: '',
    agentId: 'image-agent',
    verdict: 'scam' as ScamVerdict,
    confidence: 0.89,
    reasoning: [
      'Screenshot shows a fake login page impersonating a major bank.',
      'OCR-extracted URL does not match the real bank domain.',
    ],
    language: 'en',
    toolCallsLog: [
      {
        serverName: 'reverse_image',
        toolName: 'extract_text_urls',
        inputSummary: 'Screenshot OCR',
        durationMs: 210,
        success: true,
      },
      {
        serverName: 'url_reputation',
        toolName: 'check_url',
        inputSummary: 'Extracted URL',
        durationMs: 42,
        success: true,
      },
    ],
    latencyMs: 2100,
    modelTier: 'e4b',
    escalatedToE4B: false,
  },

  scoreVoice: {
    taskId: '',
    agentId: 'voice-agent',
    verdict: 'suspicious' as ScamVerdict,
    confidence: 0.74,
    reasoning: [
      'Audio has a moderate probability of being AI-generated.',
      'Transcript contains pressure tactics about gift card payments.',
    ],
    language: 'en',
    toolCallsLog: [
      {
        serverName: 'phone_reputation',
        toolName: 'check_number',
        inputSummary: 'Caller ID hash',
        durationMs: 25,
        success: true,
      },
      {
        serverName: 'sqlite_vec',
        toolName: 'similarity_search',
        inputSummary: 'Transcript embedding',
        durationMs: 10,
        success: true,
      },
    ],
    latencyMs: 1800,
    modelTier: 'e2b',
    escalatedToE4B: false,
  },

  explainVerdict: {
    taskId: '',
    agentId: 'orchestrator',
    verdict: 'safe' as ScamVerdict,
    confidence: 0.95,
    reasoning: [
      'This message looks safe. It does not have any signs of a scam.',
      'The sender is someone you know.',
    ],
    language: 'en',
    toolCallsLog: [],
    latencyMs: 180,
    modelTier: 'e2b',
    escalatedToE4B: false,
  },
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/** Simulates network/inference latency with a random jitter. */
function simulateLatency(baseMs: number): Promise<void> {
  const jitter = Math.floor(Math.random() * 100) - 50
  const delay = Math.max(50, baseMs + jitter)
  return new Promise((resolve) => setTimeout(resolve, delay))
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/**
 * Mock orchestrator that routes tasks to golden fixture responses.
 *
 * Simulates realistic latency and returns pre-defined results based on
 * the task type. Useful for UI development and integration tests before
 * the on-device inference pipeline is wired up.
 *
 * @param task - The agent task to process.
 * @returns A promise resolving to the mock agent result.
 */
export async function mockOrchestrate(task: AgentTask): Promise<AgentResult> {
  const fixture = GOLDEN_FIXTURES[task.type]

  if (!fixture) {
    throw new Error(`No golden fixture for task type: ${task.type}`)
  }

  // Simulate latency proportional to the fixture's expected latency
  await simulateLatency(fixture.latencyMs)

  // Return fixture with the actual task ID
  return {
    ...fixture,
    taskId: task.id,
  }
}
