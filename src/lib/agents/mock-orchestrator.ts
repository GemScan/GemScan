/**
 * Mock orchestrator for the agent pipeline.
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
    suggestion:
      'This message looks fine. Reply normally if you know the sender. ' +
      'If a follow-up suddenly asks for money, a verification code, or ' +
      'personal information, stop and call the person on a number you ' +
      'already have saved before doing anything they ask.',
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
    lowConfidenceFallback: false,
  },

  classifyEmail: {
    taskId: '',
    agentId: 'text-agent',
    verdict: 'scam' as ScamVerdict,
    confidence: 0.68,
    reasoning: [
      'Email contains a link that does not match the claimed sender domain.',
      'Urgency language detected: "act now" and "account suspended".',
      'Confidence is below the safety threshold — defaulted to scam.',
    ],
    suggestion:
      'Do not click any links or reply to this email. Open the company ' +
      'directly by typing their address into your browser or using their ' +
      'app, then check whether anything is actually wrong. If you already ' +
      'clicked or shared details, change your password and contact your ' +
      'bank from a number on the back of your card.',
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
    modelTier: 'e2b',
    lowConfidenceFallback: true,
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
    suggestion:
      'Do not visit this link. Close the message or page that sent you ' +
      'here. If it claimed to be from a service you use, open that ' +
      'service the normal way through its official app or a bookmark ' +
      'you saved earlier. Let whoever sent the link know it looks unsafe.',
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
    lowConfidenceFallback: false,
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
    suggestion:
      'Do not enter any details into the page shown in the screenshot. ' +
      'If you already typed your password or codes, change them right ' +
      'away through the bank\'s official app and watch your account for ' +
      'new charges. Report the original message to the real company\'s ' +
      'support team and your phone carrier.',
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
    modelTier: 'e2b',
    lowConfidenceFallback: false,
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
    suggestion:
      'Nothing urgent to do here — this looks like everyday safe content. ' +
      'Keep doing what you normally would. If a later message ever feels ' +
      'rushed or pressures you to share codes, money, or personal details, ' +
      'slow down and check by reaching the sender through a different ' +
      'app or phone call first.',
    language: 'en',
    toolCallsLog: [],
    latencyMs: 180,
    modelTier: 'e2b',
    lowConfidenceFallback: false,
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
