'use client'

interface StreamingTextProps {
  tokens: string
  isDone: boolean
}

export default function StreamingText({ tokens, isDone }: StreamingTextProps) {
  return (
    <div aria-live="polite" className="text-body">
      {tokens}
      {!isDone && <span className="streaming-cursor">|</span>}
    </div>
  )
}
