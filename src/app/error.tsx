'use client'

export default function ErrorBoundary({
  error,
  reset,
}: {
  error: Error & { digest?: string }
  reset: () => void
}) {
  return (
    <main className="flex min-h-screen flex-col items-center justify-center px-6 py-12">
      <div className="w-full max-w-md p-6 rounded-xl border-2 border-amber-300 bg-amber-100 text-center">
        <p className="text-sm font-medium uppercase tracking-wide text-amber-800 mb-1">Verdict</p>
        <p className="text-2xl font-bold text-amber-800 capitalize mb-4">Suspicious</p>
        <p className="text-sm text-amber-700 mb-6">
          Something went wrong while analysing. For your safety, this content has been marked as
          suspicious.
        </p>
        {error.message && <p className="text-xs text-amber-600 mb-4 font-mono">{error.message}</p>}
        <button
          onClick={reset}
          className="rounded-xl bg-amber-500 px-6 py-3 text-white font-semibold"
        >
          Try Again
        </button>
      </div>
    </main>
  )
}
