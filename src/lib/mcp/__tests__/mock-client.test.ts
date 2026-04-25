import { describe, it, expect } from 'vitest'
import { mockMCPCall } from '../mock-client'

describe('mockMCPCall', () => {
  it('scam_patterns/match_patterns returns pattern IDs for long hashes', async () => {
    const result = await mockMCPCall('scam_patterns', 'match_patterns', {
      text_hash: 'a'.repeat(64),
    })
    expect(result.patternIds).toEqual(['SP001', 'SP013'])
  })

  it('scam_patterns/match_patterns returns empty for short hashes', async () => {
    const result = await mockMCPCall('scam_patterns', 'match_patterns', {
      text_hash: 'short',
    })
    expect(result.patternIds).toEqual([])
  })

  it('contacts/is_known_sender detects known senders', async () => {
    const result = await mockMCPCall('contacts', 'is_known_sender', {
      sender_hash: 'abc123',
    })
    expect(result.is_known).toBe(true)
    expect(result.count).toBe(1)
  })

  it('contacts/is_known_sender detects unknown senders', async () => {
    const result = await mockMCPCall('contacts', 'is_known_sender', {
      sender_hash: 'xyz789',
    })
    expect(result.is_known).toBe(false)
  })

  it('url_reputation/check_url scores blocklisted URLs', async () => {
    const result = await mockMCPCall('url_reputation', 'check_url', {
      url: 'https://secure-login-verify.com',
    })
    expect(result.blocklisted).toBe(true)
    expect((result.risk_score as number) > 0).toBe(true)
  })

  it('url_reputation/check_url scores safe URLs low', async () => {
    const result = await mockMCPCall('url_reputation', 'check_url', {
      url: 'https://google.com',
    })
    expect(result.blocklisted).toBe(false)
    expect(result.risk_score).toBe(0)
  })

  it('whois/lookup returns young domain for scam patterns', async () => {
    const result = await mockMCPCall('whois', 'lookup', { domain: 'verify-bank.com' })
    expect(result.age_days).toBe(30)
    expect(result.privacy_protected).toBe(true)
  })

  it('clipboard_watcher/get_clipboard_signals returns signals', async () => {
    const result = await mockMCPCall('clipboard_watcher', 'get_clipboard_signals', {})
    expect(result).toHaveProperty('url_count')
    expect(result).toHaveProperty('has_phone')
  })

  it('screen_time/get_session_context returns time context', async () => {
    const result = await mockMCPCall('screen_time', 'get_session_context', {})
    expect(result).toHaveProperty('session_duration_min')
    expect(result).toHaveProperty('time_of_day')
  })

  it('throws for unknown server', async () => {
    await expect(mockMCPCall('fake_server', 'tool', {})).rejects.toThrow('Unknown server')
  })

  it('throws for unknown tool', async () => {
    await expect(mockMCPCall('contacts', 'fake_tool', {})).rejects.toThrow('Unknown tool')
  })

  it('scam_patterns/get_pattern_detail returns detail', async () => {
    const result = await mockMCPCall('scam_patterns', 'get_pattern_detail', { id: 'SP001' })
    expect(result.id).toBe('SP001')
    expect(result.name).toContain('SP001')
  })

  it('sqlite_vec/semantic_search returns matches', async () => {
    const result = await mockMCPCall('sqlite_vec', 'semantic_search', {
      embedding: [],
      top_k: 2,
    })
    expect((result.matches as unknown[]).length).toBeLessThanOrEqual(2)
  })

  it('sqlite_vec/store_embedding succeeds', async () => {
    const result = await mockMCPCall('sqlite_vec', 'store_embedding', {
      id: 'test',
      embedding: [],
    })
    expect(result.success).toBe(true)
  })

  it('reverse_image/extract_text_urls returns urls for large images', async () => {
    const result = await mockMCPCall('reverse_image', 'extract_text_urls', {
      base64_image: 'x'.repeat(600),
    })
    expect((result.urls as string[]).length).toBeGreaterThan(0)
    expect(result.has_qr).toBe(true)
  })

  it('reverse_image/compute_phash returns a hash', async () => {
    const result = await mockMCPCall('reverse_image', 'compute_phash', {
      base64_image: 'test',
    })
    expect(typeof result.phash).toBe('string')
  })

  it('phone_reputation/check returns phone data', async () => {
    const result = await mockMCPCall('phone_reputation', 'check', {
      transcript_excerpt: 'Call me at 555-123-4567 now!',
    })
    expect(result.found_numbers).toBe(1)
    expect((result.max_risk_score as number) > 0).toBe(true)
  })

  it('message_filter/check_sender_history returns history', async () => {
    const result = await mockMCPCall('message_filter', 'check_sender_history', {
      sender_hash: 'b12345',
    })
    expect(result.previous_verdict).toBe('suspicious')
    expect(result.scan_count).toBe(3)
  })

  it('whois/lookup returns old domain for non-scam', async () => {
    const result = await mockMCPCall('whois', 'lookup', { domain: 'google.com' })
    expect(result.age_days).toBe(1200)
    expect(result.privacy_protected).toBe(false)
  })
})
