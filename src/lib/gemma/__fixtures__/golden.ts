import type { AgentResult } from '../types'

function makeResult(
  overrides: Partial<AgentResult> &
    Pick<AgentResult, 'taskId' | 'verdict' | 'confidence' | 'reasoning'>
): AgentResult {
  return {
    agentId: 'orchestrator',
    language: 'en',
    toolCallsLog: [],
    latencyMs: 120,
    modelTier: 'e2b',
    lowConfidenceFallback: false,
    ...overrides,
  }
}

export const goldenFixtures: Record<string, AgentResult> = {
  default: makeResult({
    taskId: 'golden-default',
    verdict: 'suspicious',
    confidence: 0.65,
    reasoning: ['Message contains urgency language.', 'No known sender match.'],
  }),

  'safe-known-contact': makeResult({
    taskId: 'golden-safe-known-contact',
    verdict: 'safe',
    confidence: 0.97,
    reasoning: ['Sender matches known contact.', 'Message content is routine.'],
  }),

  'scam-sms-bank': makeResult({
    taskId: 'golden-scam-sms-bank',
    verdict: 'scam',
    confidence: 0.91,
    reasoning: [
      'Impersonates bank with urgent account-lock language.',
      'Contains suspicious shortened URL.',
      'Requests credentials via link.',
    ],
    toolCallsLog: [
      {
        serverName: 'sms-mcp',
        toolName: 'classifyMessage',
        inputSummary: 'SMS 140 chars',
        durationMs: 85,
        success: true,
      },
    ],
  }),

  'suspicious-sms-promo': makeResult({
    taskId: 'golden-suspicious-sms-promo',
    verdict: 'suspicious',
    confidence: 0.58,
    reasoning: [
      'Promotional language with limited-time offer.',
      'Unknown sender, but no credential request.',
    ],
  }),

  'scam-url-phishing': makeResult({
    taskId: 'golden-scam-url-phishing',
    verdict: 'scam',
    confidence: 0.96,
    reasoning: [
      'Domain mimics well-known brand with typosquatting.',
      'SSL certificate mismatch.',
      'Page contains credential-harvesting form.',
    ],
    toolCallsLog: [
      {
        serverName: 'url-mcp',
        toolName: 'checkURL',
        inputSummary: 'https://arnazon-secure.com/login',
        durationMs: 210,
        success: true,
      },
    ],
  }),

  'safe-url-known': makeResult({
    taskId: 'golden-safe-url-known',
    verdict: 'safe',
    confidence: 0.99,
    reasoning: ['Domain is on the verified allowlist.', 'Valid SSL certificate from trusted CA.'],
    toolCallsLog: [
      {
        serverName: 'url-mcp',
        toolName: 'checkURL',
        inputSummary: 'https://amazon.com/orders',
        durationMs: 45,
        success: true,
      },
    ],
  }),

  'scam-screenshot-fake-login': makeResult({
    taskId: 'golden-scam-screenshot-fake-login',
    verdict: 'scam',
    confidence: 0.89,
    reasoning: [
      'Screenshot shows login page with mismatched branding.',
      'URL bar shows suspicious domain.',
      'Layout mimics bank portal.',
    ],
    latencyMs: 520,
    toolCallsLog: [
      {
        serverName: 'screenshot-mcp',
        toolName: 'analyseScreenshot',
        inputSummary: 'image/png 1284x2778',
        durationMs: 410,
        success: true,
      },
    ],
  }),

  'safe-screenshot-receipt': makeResult({
    taskId: 'golden-safe-screenshot-receipt',
    verdict: 'safe',
    confidence: 0.95,
    reasoning: [
      'Screenshot shows legitimate purchase receipt.',
      'Merchant and amount match expected patterns.',
    ],
    toolCallsLog: [
      {
        serverName: 'screenshot-mcp',
        toolName: 'analyseScreenshot',
        inputSummary: 'image/png 1170x2532',
        durationMs: 280,
        success: true,
      },
    ],
  }),

  'scam-email-lottery': makeResult({
    taskId: 'golden-scam-email-lottery',
    verdict: 'scam',
    confidence: 0.98,
    reasoning: [
      'Classic lottery/prize scam template.',
      'Requests upfront fee to claim winnings.',
      'Sender domain is newly registered.',
    ],
    toolCallsLog: [
      {
        serverName: 'email-mcp',
        toolName: 'classifyEmail',
        inputSummary: 'email subject: You Won!',
        durationMs: 130,
        success: true,
      },
    ],
  }),

  'safe-email-receipt': makeResult({
    taskId: 'golden-safe-email-receipt',
    verdict: 'safe',
    confidence: 0.96,
    reasoning: [
      'Email from verified merchant domain.',
      'Content matches standard purchase confirmation.',
    ],
    toolCallsLog: [
      {
        serverName: 'email-mcp',
        toolName: 'classifyEmail',
        inputSummary: 'email subject: Order Confirmation #12345',
        durationMs: 95,
        success: true,
      },
    ],
  }),
}
