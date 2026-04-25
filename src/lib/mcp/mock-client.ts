/**
 * Web mock MCP client for GemScan.
 *
 * Simulates all 10 MCP server tools with deterministic responses
 * for use in the web/Capacitor layer during development and testing.
 */

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

type MCPResult = Record<string, unknown>

interface MockHandler {
  (input: Record<string, unknown>): MCPResult
}

// ---------------------------------------------------------------------------
// Server tool handlers
// ---------------------------------------------------------------------------

const handlers: Record<string, Record<string, MockHandler>> = {
  scam_patterns: {
    match_patterns: (input) => {
      const textHash = (input.text_hash as string) ?? ''
      // Deterministic: short hashes match no patterns, long ones match a few
      const patternIds = textHash.length > 32 ? ['SP001', 'SP013'] : []
      return { patternIds }
    },
    get_pattern_detail: (input) => {
      const id = (input.id as string) ?? ''
      return {
        id,
        name: `Mock Pattern ${id}`,
        regex: '.*',
        risk_level: 'medium',
        description: `Mock description for pattern ${id}`,
      }
    },
  },

  sqlite_vec: {
    semantic_search: (input) => {
      const topK = (input.top_k as number) ?? 5
      const matches = Array.from({ length: Math.min(topK, 3) }, (_, i) => ({
        id: `match-${i}`,
        distance: 0.1 * (i + 1),
      }))
      return { matches }
    },
    store_embedding: (_input) => {
      return { success: true }
    },
  },

  contacts: {
    is_known_sender: (input) => {
      const senderHash = (input.sender_hash as string) ?? ''
      // Deterministic: hashes starting with 'a' are "known"
      const isKnown = senderHash.startsWith('a')
      return { is_known: isKnown, count: isKnown ? 1 : 0 }
    },
  },

  url_reputation: {
    check_url: (input) => {
      const url = (input.url as string) ?? ''
      const blocklisted = url.includes('secure-login-verify') || url.includes('phishing')
      const signals: string[] = []
      let riskScore = 0

      if (blocklisted) {
        signals.push('blocklisted_domain')
        riskScore += 0.5
      }
      if (url.includes('.xyz') || url.includes('.tk')) {
        signals.push('risky_tld')
        riskScore += 0.2
      }
      if (/\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/.test(url)) {
        signals.push('ip_address_host')
        riskScore += 0.3
      }

      return {
        risk_score: Math.min(1, riskScore),
        blocklisted,
        signals,
      }
    },
  },

  whois: {
    lookup: (input) => {
      const domain = (input.domain as string) ?? ''
      // Deterministic: known scam domains return young age
      const isScamDomain = domain.includes('verify') || domain.includes('alert')
      return {
        age_days: isScamDomain ? 30 : 1200,
        registrar: isScamDomain ? 'NameCheap Inc.' : 'Cloudflare Inc.',
        country: isScamDomain ? 'PA' : 'US',
        privacy_protected: isScamDomain,
      }
    },
  },

  reverse_image: {
    extract_text_urls: (input) => {
      const base64Image = (input.base64_image as string) ?? ''
      return {
        urls: base64Image.length > 100 ? ['https://example.com/detected'] : [],
        text_length: Math.floor(base64Image.length / 4),
        has_qr: base64Image.length > 500,
      }
    },
    compute_phash: (input) => {
      // Deterministic hash based on input length
      const base64Image = (input.base64_image as string) ?? ''
      const hash = base64Image.length.toString(16).padStart(16, '0')
      return { phash: hash }
    },
  },

  phone_reputation: {
    check: (input) => {
      const excerpt = (input.transcript_excerpt as string) ?? ''
      // Detect phone-like patterns
      const phoneRegex = /\+?\d[\d\s\-()]{7,}/g
      const matches = excerpt.match(phoneRegex) ?? []
      return {
        found_numbers: matches.length,
        max_risk_score: matches.length > 0 ? 0.75 : 0,
        report_count: matches.length * 42,
      }
    },
  },

  message_filter: {
    check_sender_history: (input) => {
      const senderHash = (input.sender_hash as string) ?? ''
      // Deterministic: hashes starting with 'b' have previous verdicts
      const hasPrevious = senderHash.startsWith('b')
      return {
        previous_verdict: hasPrevious ? 'suspicious' : null,
        user_allowed: false,
        scan_count: hasPrevious ? 3 : 0,
      }
    },
  },

  clipboard_watcher: {
    get_clipboard_signals: () => {
      return {
        url_count: 0,
        has_phone: false,
        text_length: 0,
        risk_signals: [],
      }
    },
  },

  screen_time: {
    get_session_context: () => {
      const hour = new Date().getHours()
      let timeOfDay: string
      if (hour >= 6 && hour < 12) timeOfDay = 'morning'
      else if (hour >= 12 && hour < 17) timeOfDay = 'afternoon'
      else if (hour >= 17 && hour < 21) timeOfDay = 'evening'
      else timeOfDay = 'night'

      return {
        session_duration_min: 15.0,
        time_of_day: timeOfDay,
        notification_pressure: timeOfDay === 'night' ? 0.5 : 0.1,
      }
    },
  },
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/**
 * Simulates an MCP tool call with deterministic responses.
 *
 * @param server - The MCP server name (e.g. "scam_patterns", "url_reputation").
 * @param tool   - The tool name on that server (e.g. "check_url", "match_patterns").
 * @param input  - The input parameters for the tool call.
 * @returns A promise resolving to the tool's result dictionary.
 * @throws If the server or tool is not recognized.
 */
export async function mockMCPCall(
  server: string,
  tool: string,
  input: Record<string, unknown> = {}
): Promise<MCPResult> {
  const serverHandlers = handlers[server]
  if (!serverHandlers) {
    throw new Error(`[MockMCP] Unknown server: ${server}`)
  }

  const handler = serverHandlers[tool]
  if (!handler) {
    throw new Error(`[MockMCP] Unknown tool '${tool}' on server '${server}'`)
  }

  // Simulate a small async delay (1-5ms) to mirror real MCP latency patterns
  await new Promise((resolve) => setTimeout(resolve, 1 + Math.random() * 4))

  return handler(input)
}
