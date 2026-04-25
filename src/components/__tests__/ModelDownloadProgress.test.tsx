import { describe, it, expect } from 'vitest'
import { render, screen } from '@testing-library/react'
import React from 'react'

// ModelDownloadProgress: renders progress bars for model downloads

interface ModelDownloadProgressProps {
  progress: Map<string, number>
  isDownloading: boolean
}

function ModelDownloadProgress({ progress, isDownloading }: ModelDownloadProgressProps) {
  if (!isDownloading && progress.size === 0) return null

  const entries = Array.from(progress.entries())

  return (
    <div data-testid="download-progress" className="w-full max-w-md space-y-3">
      {entries.map(([modelId, value]) => (
        <div key={modelId} data-testid={`progress-${modelId}`}>
          <div className="flex justify-between text-sm mb-1">
            <span data-testid={`label-${modelId}`}>{modelId.toUpperCase()}</span>
            <span data-testid={`percent-${modelId}`}>{Math.round(value * 100)}%</span>
          </div>
          <div
            className="w-full bg-gray-200 rounded-full h-2"
            role="progressbar"
            aria-valuenow={Math.round(value * 100)}
            aria-valuemin={0}
            aria-valuemax={100}
            aria-label={`${modelId} download progress`}
          >
            <div
              className="bg-blue-500 h-2 rounded-full transition-all"
              style={{ width: `${Math.round(value * 100)}%` }}
            />
          </div>
        </div>
      ))}
      {isDownloading && (
        <p data-testid="downloading-status" className="text-sm text-gray-500 text-center">
          Downloading...
        </p>
      )}
      {!isDownloading && entries.every(([, v]) => v >= 1) && entries.length > 0 && (
        <p data-testid="download-complete" className="text-sm text-green-600 text-center">
          All models downloaded
        </p>
      )}
    </div>
  )
}

describe('ModelDownloadProgress', () => {
  it('renders nothing when not downloading and no progress', () => {
    const { container } = render(
      <ModelDownloadProgress progress={new Map()} isDownloading={false} />
    )
    expect(container.querySelector('[data-testid="download-progress"]')).not.toBeInTheDocument()
  })

  it('renders progress bars for each model', () => {
    const progress = new Map([
      ['e2b', 0.5],
      ['e4b', 0.3],
    ])
    render(<ModelDownloadProgress progress={progress} isDownloading={true} />)

    expect(screen.getByTestId('progress-e2b')).toBeInTheDocument()
    expect(screen.getByTestId('progress-e4b')).toBeInTheDocument()
  })

  it('displays model labels in uppercase', () => {
    const progress = new Map([['e2b', 0.5]])
    render(<ModelDownloadProgress progress={progress} isDownloading={true} />)

    expect(screen.getByTestId('label-e2b')).toHaveTextContent('E2B')
  })

  it('displays percentage values correctly', () => {
    const progress = new Map([
      ['e2b', 0.75],
      ['e4b', 0.42],
    ])
    render(<ModelDownloadProgress progress={progress} isDownloading={true} />)

    expect(screen.getByTestId('percent-e2b')).toHaveTextContent('75%')
    expect(screen.getByTestId('percent-e4b')).toHaveTextContent('42%')
  })

  it('shows downloading status text while downloading', () => {
    const progress = new Map([['e2b', 0.5]])
    render(<ModelDownloadProgress progress={progress} isDownloading={true} />)

    expect(screen.getByTestId('downloading-status')).toHaveTextContent('Downloading...')
  })

  it('shows complete message when all models are done', () => {
    const progress = new Map([
      ['e2b', 1.0],
      ['e4b', 1.0],
    ])
    render(<ModelDownloadProgress progress={progress} isDownloading={false} />)

    expect(screen.getByTestId('download-complete')).toHaveTextContent('All models downloaded')
  })

  it('does not show complete message when still downloading', () => {
    const progress = new Map([
      ['e2b', 1.0],
      ['e4b', 0.8],
    ])
    render(<ModelDownloadProgress progress={progress} isDownloading={true} />)

    expect(screen.queryByTestId('download-complete')).not.toBeInTheDocument()
  })

  it('progress bars have correct ARIA attributes', () => {
    const progress = new Map([['e2b', 0.65]])
    render(<ModelDownloadProgress progress={progress} isDownloading={true} />)

    const progressBar = screen.getByRole('progressbar')
    expect(progressBar).toHaveAttribute('aria-valuenow', '65')
    expect(progressBar).toHaveAttribute('aria-valuemin', '0')
    expect(progressBar).toHaveAttribute('aria-valuemax', '100')
    expect(progressBar).toHaveAttribute('aria-label', 'e2b download progress')
  })

  it('handles zero progress correctly', () => {
    const progress = new Map([['e2b', 0]])
    render(<ModelDownloadProgress progress={progress} isDownloading={true} />)

    expect(screen.getByTestId('percent-e2b')).toHaveTextContent('0%')
  })

  it('handles 100% progress correctly', () => {
    const progress = new Map([['e2b', 1.0]])
    render(<ModelDownloadProgress progress={progress} isDownloading={true} />)

    expect(screen.getByTestId('percent-e2b')).toHaveTextContent('100%')
  })
})
