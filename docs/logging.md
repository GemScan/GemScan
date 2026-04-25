# Logging Conventions

Structured logging standards for GemScan across Swift and TypeScript layers.

---

## Swift Logging

### Framework

GemScan uses Apple's `os.Logger` with the subsystem `com.gemscan`.

```swift
import os

let logger = Logger(subsystem: "com.gemscan", category: "inference")
logger.info("Model loaded: \(modelName, privacy: .public)")
```

### Logger Categories

| Category | Subsystem | Usage |
|----------|-----------|-------|
| `inference` | `com.gemscan` | Model loading, token generation, latency |
| `agents` | `com.gemscan` | Agent lifecycle, routing, escalation |
| `mcp` | `com.gemscan` | MCP server tool invocations and responses |
| `router` | `com.gemscan` | Message routing between agents |
| `extensions` | `com.gemscan` | SMS Filter, Call Directory, Share, Safari Blocker |
| `plugin` | `com.gemscan` | Capacitor bridge calls |
| `ui` | `com.gemscan` | UI-layer events (Swift side) |
| `metrics` | `com.gemscan` | Performance metrics collection |

### Log Levels

| Level | When to use | Example |
|-------|-------------|---------|
| `debug` | Verbose tracing during development | Token-by-token generation output |
| `info` | Normal operational events | "Scan completed in 1.2s" |
| `warning` | Recoverable issues | "MLX init failed, falling back to llama.cpp" |
| `error` | Failures requiring attention | "Model file not found at path" |

### Example

```swift
private let log = Logger(subsystem: "com.gemscan", category: "agents")

func route(_ task: AgentTask) async -> AgentResult {
    log.info("Routing task \(task.id, privacy: .public) type=\(task.inputType.rawValue, privacy: .public)")
    
    let result = await specialist.process(task)
    
    if result.confidence < 0.75 {
        log.warning("Low confidence \(result.confidence, privacy: .public) — escalating to E4B")
    }
    
    log.info("Task \(task.id, privacy: .public) verdict=\(result.verdict.rawValue, privacy: .public)")
    return result
}
```

---

## TypeScript Logging

### Structured JSON Logger

The TypeScript layer uses a structured logger that outputs JSON for easy parsing in development and CI.

```typescript
import { logger } from '@/lib/logger';

logger.info('scan.started', { inputType: 'text', source: 'manual' });
logger.warn('mock.active', { plugin: 'GemmaPlugin' });
logger.error('scan.failed', { error: err.message, taskId });
```

### Output Format

```json
{
  "level": "info",
  "event": "scan.started",
  "timestamp": "2026-01-15T10:30:00.000Z",
  "data": {
    "inputType": "text",
    "source": "manual"
  }
}
```

### Log Levels (TypeScript)

| Level | When to use |
|-------|-------------|
| `debug` | Development-only tracing |
| `info` | User actions, state transitions |
| `warn` | Degraded behavior (mock mode, fallbacks) |
| `error` | Unhandled errors, failed operations |

---

## CRITICAL: Never Log PII

**Personally identifiable information must never appear in logs.** This includes:

- [ ] Phone numbers
- [ ] Message content / body text
- [ ] Contact names
- [ ] Email addresses
- [ ] Device identifiers (UDID, IDFV in production logs)
- [ ] Location data
- [ ] IP addresses

### Swift Privacy Annotations

Always use `privacy: .private` (the default) for any value that could contain PII:

```swift
// CORRECT — message body is redacted in release builds
log.info("Processing message length=\(message.count, privacy: .public)")

// WRONG — message content exposed in logs
log.info("Processing message: \(message)")
```

In debug builds, `.private` values are visible in Console.app. In release builds, they are redacted to `<private>`.

### TypeScript PII Prevention

Never include raw user input in log data:

```typescript
// CORRECT
logger.info('scan.started', { inputType: 'text', inputLength: text.length });

// WRONG
logger.info('scan.started', { inputType: 'text', content: text });
```

### PII Scan in CI

The CI pipeline includes a PII scan step that greps source files for patterns that might leak PII into logs:

```yaml
- name: PII log scan
  run: |
    ! grep -rn 'log\.\(info\|debug\|warning\|error\).*message\b' ios/ \
      --include='*.swift' \
      | grep -v 'privacy: .public' \
      | grep -v '// pii-safe'
```

Add `// pii-safe` to suppress false positives on lines you have manually verified.

---

## Debug Overlay

### Activation

Triple-tap the app icon in the tab bar to open the debug overlay. This is only available in debug builds.

### What It Shows

- Last 50 log entries (all categories)
- InferenceMetrics for the most recent scan
- Active model tier (E2B / E4B / DistilBERT)
- Memory usage
- Extension status

### InferenceMetrics

```swift
struct InferenceMetrics {
    let modelTier: ModelTier       // .e2b, .e4b, .distilbert
    let loadTimeMs: Double         // Model load time
    let inferenceTimeMs: Double    // Token generation time
    let totalTimeMs: Double        // End-to-end pipeline time
    let tokenCount: Int            // Tokens generated
    let peakMemoryMB: Double       // Peak memory during inference
    let didEscalate: Bool          // Whether E4B was used
}
```

### MetricsStore

```swift
actor MetricsStore {
    static let shared = MetricsStore()
    
    func record(_ metrics: InferenceMetrics) { ... }
    func recentMetrics(limit: Int = 50) -> [InferenceMetrics] { ... }
    func averageInferenceTime() -> Double { ... }
}
```

MetricsStore is an actor — thread-safe by design. It retains the last 500 entries in memory and flushes aggregates to the App Group container every 60 seconds.

---

## How to Add New Log Events

### Swift

1. Choose the appropriate category from the table above.
2. Create or reuse a `Logger` instance:
   ```swift
   private let log = Logger(subsystem: "com.gemscan", category: "agents")
   ```
3. Use the correct log level.
4. Mark values as `privacy: .public` only if they contain no PII.
5. Run the PII scan: `scripts/pii-scan.sh` (or wait for CI).

### TypeScript

1. Import the logger: `import { logger } from '@/lib/logger'`
2. Use dot-notation event names: `domain.action` (e.g., `scan.completed`, `history.cleared`).
3. Include only non-PII metadata in the data object.
4. Verify in browser console or debug overlay.

---

## Filtering Logs

### Console.app (macOS)

Filter by subsystem to see only GemScan logs:

```
subsystem:com.gemscan
```

Filter by category:

```
subsystem:com.gemscan category:inference
```

### Xcode Console

Use the filter bar with `com.gemscan` to narrow output during debugging.

### Terminal (log stream)

```bash
log stream --predicate 'subsystem == "com.gemscan"' --level debug
```
