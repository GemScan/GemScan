'use client'

interface StreamingReasoningViewProps {
  tokens: string
  isDone: boolean
}

export default function StreamingReasoningView({ tokens, isDone }: StreamingReasoningViewProps) {
  return (
    <div
      className="w-full max-w-md rounded-lg bg-gray-50 dark:bg-gray-900 p-4 text-sm font-mono"
      aria-live="polite"
      aria-atomic={false}
      role="log"
      aria-label="Streaming analysis reasoning"
    >
      <span>{tokens}</span>
      {!isDone && (
        <span
          className="inline-block w-2 h-4 ml-0.5 bg-current align-middle motion-safe:animate-pulse"
          aria-hidden="true"
        />
      )}
    </div>
  )
}
