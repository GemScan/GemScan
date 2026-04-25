# Spec 08 — Logging and Monitoring

---

## 1. Overview

GemScan uses **structured, privacy-safe logging** across all layers. Logs are strictly on-device — no telemetry leaves the device without explicit user opt-in. The logging system is designed to accelerate debug cycles during Days 2–14 validation while producing zero PII leakage in production builds.

---

## 2. Log Levels

| Level | When to use | Example |
|---|---|---|
| `.debug` | Per-token tracing, raw model output (dev only, stripped in release) | `"Token generated: 'safe'"` |
| `.info` | Lifecycle events, task start/complete, model load | `"E2B model loaded in 1.2s"` |
| `.warning` | Graceful degradations, thermal downgrade, memory pressure | `"E4B unavailable — falling back to E2B"` |
| `.error` | Unrecoverable failures, grammar violations, MCP tool failures | `"analyse failed: inferenceTimeout taskId=abc limitMs=5000"` |

**Privacy invariant:** No log at any level may contain: message content, contact names, phone numbers, URLs verbatim, audio transcripts, screenshot contents, or any personally identifiable information.

---

## 3. Swift Logging — `os.Logger`

### 3.1 Logger Registration

Each GemmaKit module registers its own `os.Logger` with a distinct category. This allows filtering by module in Instruments and Console.app.

```swift
// GemmaKit/Sources/Logging/GemScanLogger.swift
import os

/// Centralised logger registry. Each subsystem module uses its own category.
enum GemScanLogger {
    static let inference  = Logger(subsystem: "com.gemscan", category: "Inference")
    static let agents     = Logger(subsystem: "com.gemscan", category: "Agents")
    static let mcp        = Logger(subsystem: "com.gemscan", category: "MCP")
    static let router     = Logger(subsystem: "com.gemscan", category: "Router")
    static let extensions = Logger(subsystem: "com.gemscan", category: "Extensions")
    static let plugin     = Logger(subsystem: "com.gemscan", category: "Plugin")
    static let ui         = Logger(subsystem: "com.gemscan", category: "UI")
    static let metrics    = Logger(subsystem: "com.gemscan", category: "Metrics")
}
```

### 3.2 Privacy-Safe Formatting

`os.Logger` automatically redacts dynamic string interpolation in release builds unless explicitly marked `.public`.

```swift
// CORRECT — dynamic values are redacted in release builds
GemScanLogger.inference.info("Task \(task.id, privacy: .public) completed in \(latencyMs)ms")

// CORRECT — safe metadata, always public
GemScanLogger.inference.info("Model tier: \(modelTier.rawValue, privacy: .public) verdict: \(verdict.rawValue, privacy: .public)")

// WRONG — never log content
// GemScanLogger.agents.debug("Message content: \(messageBody)")  // ← never do this

// CORRECT — log summary stats only
GemScanLogger.agents.debug("Processing SMS [\(messageBody.count) chars, language=\(language)]")
```

### 3.3 Structured Log Events

Key lifecycle events must be logged with a consistent structure to enable automated log analysis.

```swift
// GemmaKit/Sources/Logging/LogEvents.swift

/// Structured log event types for automated parsing.
enum LogEvent {
    // Inference events
    static func inferenceStart(taskId: String, type: String, modelTier: String) -> String {
        "inference.start taskId=\(taskId) type=\(type) modelTier=\(modelTier)"
    }
    static func inferenceComplete(taskId: String, verdict: String, confidence: Double, latencyMs: Int, tier: String, escalated: Bool) -> String {
        "inference.complete taskId=\(taskId) verdict=\(verdict) confidence=\(String(format: "%.2f", confidence)) latencyMs=\(latencyMs) tier=\(tier) escalated=\(escalated)"
    }
    static func inferenceError(taskId: String, error: String, latencyMs: Int) -> String {
        "inference.error taskId=\(taskId) error=\(error) latencyMs=\(latencyMs)"
    }

    // Model lifecycle
    static func modelLoaded(tier: String, loadTimeMs: Int, rssBytes: Int) -> String {
        "model.loaded tier=\(tier) loadTimeMs=\(loadTimeMs) rssBytes=\(rssBytes)"
    }
    static func modelUnloaded(tier: String, reason: String) -> String {
        "model.unloaded tier=\(tier) reason=\(reason)"
    }
    static func modelDownloadProgress(modelId: String, progressPct: Int, bytesDownloaded: Int) -> String {
        "model.download.progress modelId=\(modelId) progress=\(progressPct)% bytes=\(bytesDownloaded)"
    }

    // MCP events
    static func mcpCall(server: String, tool: String, durationMs: Int, success: Bool) -> String {
        "mcp.call server=\(server) tool=\(tool) durationMs=\(durationMs) success=\(success)"
    }

    // Degradation events
    static func thermalDowngrade(from: String, to: String, thermalState: String) -> String {
        "degradation.thermal from=\(from) to=\(to) thermalState=\(thermalState)"
    }
    static func oomFallback(requestedBytes: Int, availableBytes: Int, tier: String) -> String {
        "degradation.oom requestedBytes=\(requestedBytes) availableBytes=\(availableBytes) droppedTier=\(tier)"
    }

    // Guardian mode
    static func guardianModeChanged(enabled: Bool, changedBy: String) -> String {
        "guardian.mode.changed enabled=\(enabled) changedBy=\(changedBy)"
    }
}
```

Usage pattern:

```swift
GemScanLogger.inference.info("\(LogEvent.inferenceStart(taskId: task.id, type: task.type.rawValue, modelTier: tier.rawValue))")
```

---

## 4. TypeScript Logging — Structured Logger

### 4.1 Logger Implementation

```typescript
// src/lib/logger.ts
type LogLevel = 'debug' | 'info' | 'warning' | 'error'

interface LogEntry {
  level: LogLevel
  message: string
  module?: string
  data?: Record<string, unknown>
  timestamp: string
}

function isProduction(): boolean {
  return process.env.NODE_ENV === 'production'
}

function log(level: LogLevel, message: string, data?: Record<string, unknown>, module?: string): void {
  // Strip debug logs in production
  if (level === 'debug' && isProduction()) return

  const entry: LogEntry = {
    level,
    message,
    module,
    data,
    timestamp: new Date().toISOString(),
  }

  if (isProduction()) {
    // Structured JSON for production log aggregation (if opt-in telemetry enabled)
    console[level === 'warning' ? 'warn' : level](JSON.stringify(entry))
  } else {
    // Pretty-print for development
    const prefix = `[${entry.timestamp.slice(11, 23)}] [${level.toUpperCase()}]${module ? ` [${module}]` : ''}`
    const dataStr = data ? ` ${JSON.stringify(data)}` : ''
    console[level === 'warning' ? 'warn' : level](`${prefix} ${message}${dataStr}`)
  }
}

export const logger = {
  debug: (message: string, data?: Record<string, unknown>, module?: string) => log('debug', message, data, module),
  info:  (message: string, data?: Record<string, unknown>, module?: string) => log('info',  message, data, module),
  warn:  (message: string, data?: Record<string, unknown>, module?: string) => log('warning', message, data, module),
  error: (message: string, data?: Record<string, unknown>, module?: string) => log('error', message, data, module),
}
```

### 4.2 Usage Convention

```typescript
// Always include module name for filterability
logger.info('[MOCK] isReady → ready', {}, 'GemmaPluginMock')
logger.info('OrchestratorAgent: escalating to E4B', { taskId, draftConfidence }, 'OrchestratorAgent')
logger.warn('Streaming timeout — partial result returned', { taskId, tokensReceived }, 'StreamingReasoningView')
logger.error('analyse failed', { error: e.message, taskId }, 'GemmaPlugin')

// Never log content
// logger.debug('SMS body:', messageBody)  // ← forbidden
logger.debug('SMS received', { charCount: messageBody.length, language }, 'TextAgent')
```

---

## 5. Kotlin Logging — GemScanLogger Facade

```kotlin
// android/app/src/main/kotlin/com/gemscan/logging/GemScanLogger.kt
package com.gemscan.logging

import android.util.Log

/**
 * Privacy-safe logging facade. All methods strip content; log only metadata.
 *
 * Log tag format: "GemScan/{Module}"
 * This allows filtering with: adb logcat -s "GemScan/*"
 */
object GemScanLogger {
    private const val SUBSYSTEM = "GemScan"

    fun debug(module: String, message: String, data: Map<String, Any> = emptyMap()) {
        if (!BuildConfig.DEBUG) return    // Strip debug logs in release builds
        Log.d("$SUBSYSTEM/$module", formatMessage(message, data))
    }

    fun info(module: String, message: String, data: Map<String, Any> = emptyMap()) {
        Log.i("$SUBSYSTEM/$module", formatMessage(message, data))
    }

    fun warning(module: String, message: String, data: Map<String, Any> = emptyMap()) {
        Log.w("$SUBSYSTEM/$module", formatMessage(message, data))
    }

    fun error(module: String, message: String, throwable: Throwable? = null, data: Map<String, Any> = emptyMap()) {
        Log.e("$SUBSYSTEM/$module", formatMessage(message, data), throwable)
    }

    private fun formatMessage(message: String, data: Map<String, Any>): String {
        if (data.isEmpty()) return message
        val dataStr = data.entries.joinToString(" ") { "${it.key}=${it.value}" }
        return "$message $dataStr"
    }
}
```

Usage:

```kotlin
GemScanLogger.info("OrchestratorAgent", "task received", mapOf("taskId" to task.id, "type" to task.type))
GemScanLogger.warning("InferenceEngine", "E4B unavailable — falling back to E2B", mapOf("availableBytes" to available))
GemScanLogger.error("MCPClient", "tool call failed", exception, mapOf("server" to serverName, "tool" to toolName))
```

---

## 6. InferenceMetrics — Performance Monitoring

```swift
// GemmaKit/Sources/Logging/InferenceMetrics.swift
import Foundation
import os

/// Captures per-inference performance metrics for profiling and regression detection.
struct InferenceMetrics {
    let taskId: String
    let modelTier: ModelTier
    let escalatedToE4B: Bool
    let firstTokenLatencyMs: Int
    let totalLatencyMs: Int
    let tokensPerSecond: Double
    let peakRSSBytes: Int
    let toolCallCount: Int
    let verdict: ScamVerdict
    let confidence: Double
    let timestamp: Date

    /// Emit as a structured os_signpost for Instruments time profiling.
    func emit() {
        let log = OSLog(subsystem: "com.gemscan", category: .pointsOfInterest)
        os_signpost(.event, log: log, name: "InferenceComplete",
            "%{public}s tier=%{public}s latency=%dms rss=%dKB tps=%.1f verdict=%{public}s",
            taskId, modelTier.rawValue, totalLatencyMs, peakRSSBytes / 1024,
            tokensPerSecond, verdict.rawValue
        )

        GemScanLogger.metrics.info("""
        \(LogEvent.inferenceComplete(
            taskId: taskId,
            verdict: verdict.rawValue,
            confidence: confidence,
            latencyMs: totalLatencyMs,
            tier: modelTier.rawValue,
            escalated: escalatedToE4B
        ))
        """)

        // Write to local metrics store for trend analysis
        MetricsStore.shared.record(self)
    }
}

/// Lightweight on-device metrics accumulator.
actor MetricsStore {
    static let shared = MetricsStore()

    private var records: [InferenceMetrics] = []
    private let maxRecords = 500    // Ring buffer

    private let logger = GemScanLogger.metrics

    func record(_ metrics: InferenceMetrics) {
        if records.count >= maxRecords { records.removeFirst() }
        records.append(metrics)
    }

    func summary() -> MetricsSummary {
        guard !records.isEmpty else { return MetricsSummary.empty }

        let latencies = records.map(\.totalLatencyMs)
        let e2bCount = records.filter { $0.modelTier == .e2b }.count
        let e4bCount = records.filter { $0.modelTier == .e4b }.count
        let escalationRate = Double(records.filter(\.escalatedToE4B).count) / Double(records.count)
        let falseSafeCount = records.filter { $0.verdict == .safe && $0.confidence < 0.60 }.count

        return MetricsSummary(
            totalTasks: records.count,
            medianLatencyMs: median(latencies),
            p95LatencyMs: percentile(latencies, 0.95),
            e2bUsage: e2bCount,
            e4bUsage: e4bCount,
            escalationRate: escalationRate,
            lowConfidenceSafeCount: falseSafeCount
        )
    }
}

struct MetricsSummary {
    let totalTasks: Int
    let medianLatencyMs: Int
    let p95LatencyMs: Int
    let e2bUsage: Int
    let e4bUsage: Int
    let escalationRate: Double
    let lowConfidenceSafeCount: Int

    static let empty = MetricsSummary(totalTasks: 0, medianLatencyMs: 0, p95LatencyMs: 0,
        e2bUsage: 0, e4bUsage: 0, escalationRate: 0, lowConfidenceSafeCount: 0)
}
```

---

## 7. Debug UI Overlay (Dev Builds Only)

A debug overlay panel is available in development builds, toggled by a triple-tap on the GemScan logo. It is compiled out of release builds via `#if DEBUG`.

```typescript
// src/components/DebugOverlay.tsx
'use client'

import { useState, useEffect } from 'react'
import { GemmaPlugin } from '@/lib/gemma'
import type { DeviceStatus } from '@/lib/gemma/types'

export function DebugOverlay() {
  if (process.env.NODE_ENV !== 'development') return null

  const [visible, setVisible] = useState(false)
  const [status, setStatus] = useState<DeviceStatus | null>(null)
  const [tapCount, setTapCount] = useState(0)

  useEffect(() => {
    if (tapCount === 3) {
      setVisible(v => !v)
      setTapCount(0)
    }
  }, [tapCount])

  useEffect(() => {
    if (!visible) return
    const interval = setInterval(async () => {
      const s = await GemmaPlugin.getDeviceStatus()
      setStatus(s)
    }, 1000)
    return () => clearInterval(interval)
  }, [visible])

  return (
    <>
      {/* Invisible tap target on logo */}
      <div
        onClick={() => setTapCount(c => c + 1)}
        className="absolute top-0 left-0 w-16 h-16 opacity-0"
        aria-hidden="true"
      />

      {visible && status && (
        <div className="fixed bottom-0 left-0 right-0 bg-black/90 text-green-400 font-mono text-xs p-3 z-50 max-h-48 overflow-auto">
          <div className="grid grid-cols-2 gap-x-4 gap-y-1">
            <span>RAM available:</span><span>{(status.availableMemoryBytes / 1e9).toFixed(1)} GB</span>
            <span>E2B loaded:</span><span>{status.e2bLoaded ? '✓' : '✗'}</span>
            <span>E4B loaded:</span><span>{status.e4bLoaded ? '✓' : '✗'}</span>
            <span>Thermal:</span><span>{status.thermalState}</span>
            <span>Battery:</span><span>{(status.batteryLevel * 100).toFixed(0)}%</span>
            <span>Mode:</span><span>{status.screeningMode}</span>
            <span>Mock mode:</span><span>{process.env.NEXT_PUBLIC_IS_MOCK === 'true' ? 'ON' : 'OFF'}</span>
            <span>App version:</span><span>{process.env.NEXT_PUBLIC_APP_VERSION}</span>
          </div>
          <button
            onClick={() => setVisible(false)}
            className="mt-2 text-gray-400 underline text-xs"
          >
            Close
          </button>
        </div>
      )}
    </>
  )
}
```

Swift native debug overlay (Xcode debug build only):

```swift
// ios/App/App/DebugOverlayView.swift
#if DEBUG
import SwiftUI
import GemmaKit

struct DebugOverlayView: View {
    @State private var status: DeviceStatus?
    @State private var summary: MetricsSummary = .empty

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let s = status {
                Group {
                    debugRow("RAM avail", "\(s.availableMemoryMB) MB")
                    debugRow("E2B", s.e2bLoaded ? "loaded" : "unloaded")
                    debugRow("E4B", s.e4bLoaded ? "loaded" : "unloaded")
                    debugRow("Thermal", s.thermalState.rawValue)
                    debugRow("Tasks", "\(summary.totalTasks)")
                    debugRow("P95 latency", "\(summary.p95LatencyMs) ms")
                    debugRow("Escalation rate", String(format: "%.1f%%", summary.escalationRate * 100))
                }
            }
        }
        .font(.system(size: 10, design: .monospaced))
        .foregroundColor(.green)
        .padding(8)
        .background(Color.black.opacity(0.85))
        .cornerRadius(8)
        .onReceive(timer) { _ in
            Task {
                status = try? await InferenceEngine.shared.getDeviceStatus()
                summary = await MetricsStore.shared.summary()
            }
        }
    }

    private func debugRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).opacity(0.7)
            Spacer()
            Text(value)
        }
    }
}
#endif
```

---

## 8. OSLog Filtering Cheatsheet

For debugging on-device via Xcode Console or `xcrun simctl`:

```bash
# Filter all GemScan logs
log stream --predicate 'subsystem == "com.gemscan"'

# Filter by module
log stream --predicate 'subsystem == "com.gemscan" AND category == "Inference"'

# Filter warnings and errors only
log stream --predicate 'subsystem == "com.gemscan" AND messageType >= 16'

# Export last 30 min for analysis
log collect --output gemscan_logs.logarchive --start "$(date -v-30M '+%Y-%m-%d %H:%M:%S')"
```

For Android logcat:

```bash
# All GemScan logs
adb logcat -s "GemScan/*"

# Specific module
adb logcat -s "GemScan/OrchestratorAgent"

# Warnings and errors only
adb logcat "*:W" "GemScan/*:V"
```

---

## 9. Logging Compliance Checklist

- [ ] No PII in any log message at any level (automated regex scan in CI: see Spec 09)
- [ ] `.debug` logs are stripped from release builds (Swift `#if DEBUG`; Kotlin `BuildConfig.DEBUG`)
- [ ] Every `catch` block logs at `.error` level minimum (code review gate)
- [ ] `InferenceMetrics.emit()` called after every `InferenceEngine.generate()` completion
- [ ] `MetricsStore` ring buffer does not exceed 500 records (XCTest: verify eviction)
- [ ] `DebugOverlay` not present in production build (Playwright: assert overlay absent)
- [ ] All log categories register against `com.gemscan` subsystem (XCTest: verify logger registry)
- [ ] OSLog privacy annotations present on all dynamic string interpolations in Swift (static analysis)
