import Foundation
import os

/// Summary statistics computed from the metrics ring buffer.
public struct MetricsSummary: Sendable {
    /// Median total latency in milliseconds across recorded metrics.
    public let medianLatencyMs: Double
    /// 95th-percentile total latency in milliseconds.
    public let p95LatencyMs: Double
    /// Fraction of tasks where the verdict was forced to `.scam` by the
    /// orchestrator's low-confidence safety fallback (0.0-1.0).
    public let lowConfidenceFallbackRate: Double
    /// Number of tasks with verdict "safe" and confidence below 0.7.
    public let lowConfidenceSafeCount: Int

    public init(
        medianLatencyMs: Double,
        p95LatencyMs: Double,
        lowConfidenceFallbackRate: Double,
        lowConfidenceSafeCount: Int
    ) {
        self.medianLatencyMs = medianLatencyMs
        self.p95LatencyMs = p95LatencyMs
        self.lowConfidenceFallbackRate = lowConfidenceFallbackRate
        self.lowConfidenceSafeCount = lowConfidenceSafeCount
    }
}

/// An actor-isolated ring buffer that stores the most recent inference metrics.
///
/// `MetricsStore` retains up to ``maxCapacity`` records in FIFO order.
/// Once the buffer is full, the oldest record is overwritten. This ensures
/// bounded memory usage regardless of how many tasks are processed.
///
/// Thread safety is guaranteed by Swift's actor model.
public actor MetricsStore {

    // MARK: - Properties

    /// Maximum number of records the ring buffer can hold.
    public let maxCapacity: Int

    /// The ring buffer backing store.
    private var buffer: [InferenceMetrics]

    /// Index of the next write position in the ring buffer.
    private var writeIndex: Int = 0

    /// Total number of records ever written (may exceed maxCapacity).
    private var totalWritten: Int = 0

    /// Logger for metrics operations.
    private let logger = GemScanLogger.metrics

    // MARK: - Initialization

    /// Creates a new metrics store with the given capacity.
    ///
    /// - Parameter maxCapacity: Maximum number of records to retain. Defaults to 500.
    public init(maxCapacity: Int = 500) {
        self.maxCapacity = maxCapacity
        self.buffer = []
        self.buffer.reserveCapacity(maxCapacity)
    }

    // MARK: - Public API

    /// Records a new inference metrics snapshot.
    ///
    /// If the buffer is full, the oldest record is overwritten.
    ///
    /// - Parameter metrics: The metrics to record.
    public func record(metrics: InferenceMetrics) {
        if buffer.count < maxCapacity {
            buffer.append(metrics)
        } else {
            buffer[writeIndex] = metrics
        }
        writeIndex = (writeIndex + 1) % maxCapacity
        totalWritten += 1

        logger.debug("Recorded metrics for task \(metrics.taskId). Buffer: \(self.buffer.count)/\(self.maxCapacity)")
    }

    /// Computes a summary of all currently buffered metrics.
    ///
    /// - Returns: A ``MetricsSummary`` with median/p95 latency, low-confidence
    ///   fallback rate, and low-confidence safe count. Returns zeroed summary
    ///   if the buffer is empty.
    public func summary() -> MetricsSummary {
        guard !buffer.isEmpty else {
            return MetricsSummary(
                medianLatencyMs: 0,
                p95LatencyMs: 0,
                lowConfidenceFallbackRate: 0,
                lowConfidenceSafeCount: 0
            )
        }

        let latencies = buffer.map(\.totalLatencyMs).sorted()

        let median = percentile(sorted: latencies, quantile: 0.50)
        let p95 = percentile(sorted: latencies, quantile: 0.95)

        let fallbackCount = buffer.filter(\.lowConfidenceFallback).count
        let fallbackRate = Double(fallbackCount) / Double(buffer.count)

        let lowConfSafe = buffer.filter { $0.verdict == "safe" && $0.confidence < 0.7 }.count

        return MetricsSummary(
            medianLatencyMs: median,
            p95LatencyMs: p95,
            lowConfidenceFallbackRate: fallbackRate,
            lowConfidenceSafeCount: lowConfSafe
        )
    }

    /// Returns the current number of records in the buffer.
    public func count() -> Int {
        buffer.count
    }

    /// Returns the total number of records ever written.
    public func totalRecorded() -> Int {
        totalWritten
    }

    /// Clears all recorded metrics.
    public func reset() {
        buffer.removeAll(keepingCapacity: true)
        writeIndex = 0
        totalWritten = 0
        logger.info("Metrics store reset")
    }

    // MARK: - Private

    /// Computes the q-th percentile of a pre-sorted array of doubles.
    ///
    /// Uses linear interpolation between the two nearest ranks.
    private func percentile(sorted: [Double], quantile: Double) -> Double {
        guard !sorted.isEmpty else { return 0 }
        guard sorted.count > 1 else { return sorted[0] }

        let rank = quantile * Double(sorted.count - 1)
        let lowerIndex = Int(floor(rank))
        let upperIndex = min(lowerIndex + 1, sorted.count - 1)
        let fraction = rank - Double(lowerIndex)

        return sorted[lowerIndex] + fraction * (sorted[upperIndex] - sorted[lowerIndex])
    }
}
