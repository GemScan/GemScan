export type LogLevel = 'debug' | 'info' | 'warn' | 'error'

export interface LogEntry {
  level: LogLevel
  message: string
  module?: string
  data?: Record<string, unknown>
  timestamp: string
}

const LEVEL_PRIORITY: Record<LogLevel, number> = {
  debug: 0,
  info: 1,
  warn: 2,
  error: 3,
}

const LEVEL_COLORS: Record<LogLevel, string> = {
  debug: '\x1b[36m', // cyan
  info: '\x1b[32m', // green
  warn: '\x1b[33m', // yellow
  error: '\x1b[31m', // red
}

const RESET = '\x1b[0m'

const isProduction = process.env.NODE_ENV === 'production'

const minLevel: LogLevel = isProduction ? 'info' : 'debug'

function shouldLog(level: LogLevel): boolean {
  return LEVEL_PRIORITY[level] >= LEVEL_PRIORITY[minLevel]
}

function stripPII(data?: Record<string, unknown>): Record<string, unknown> | undefined {
  if (!data) return undefined
  const piiKeys = ['email', 'phone', 'ssn', 'password', 'token', 'secret', 'name', 'address']
  const cleaned: Record<string, unknown> = {}
  for (const [key, value] of Object.entries(data)) {
    if (piiKeys.some((pii) => key.toLowerCase().includes(pii))) {
      cleaned[key] = '[REDACTED]'
    } else {
      cleaned[key] = value
    }
  }
  return cleaned
}

function emit(
  level: LogLevel,
  message: string,
  module?: string,
  data?: Record<string, unknown>
): void {
  if (!shouldLog(level)) return

  const entry: LogEntry = {
    level,
    message,
    module,
    data: stripPII(data),
    timestamp: new Date().toISOString(),
  }

  if (isProduction) {
    console.log(JSON.stringify(entry))
    return
  }

  const color = LEVEL_COLORS[level]
  const tag = `${color}[${level.toUpperCase()}]${RESET}`
  const mod = module ? ` (${module})` : ''
  const suffix = entry.data ? ` ${JSON.stringify(entry.data)}` : ''
  console.log(`${tag}${mod} ${message}${suffix}`)
}

export const logger = {
  debug(message: string, module?: string, data?: Record<string, unknown>): void {
    emit('debug', message, module, data)
  },
  info(message: string, module?: string, data?: Record<string, unknown>): void {
    emit('info', message, module, data)
  },
  warn(message: string, module?: string, data?: Record<string, unknown>): void {
    emit('warn', message, module, data)
  },
  error(message: string, module?: string, data?: Record<string, unknown>): void {
    emit('error', message, module, data)
  },
}
