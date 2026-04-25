import XCTest
@testable import GemmaKit

/// Tests for the MetricsStore ring buffer.
final class MetricsStoreTests: XCTestCase {

    // MARK: - Basic Operations

    func testEmptyStore_ReturnsZeroSummary() async {
        let store = MetricsStore(maxCapacity: 10)

        let summary = await store.summary()

        XCTAssertEqual(summary.medianLatencyMs, 0)
        XCTAssertEqual(summary.p95LatencyMs, 0)
        XCTAssertEqual(summary.escalationRate, 0)
        XCTAssertEqual(summary.lowConfidenceSafeCount, 0)
    }

    func testRecord_SingleMetric() async {
        let store = MetricsStore(maxCapacity: 10)

        let metrics = makeMetrics(taskId: "t1", latencyMs: 200, verdict: "safe", confidence: 0.95)
        await store.record(metrics: metrics)

        let count = await store.count()
        XCTAssertEqual(count, 1)

        let total = await store.totalRecorded()
        XCTAssertEqual(total, 1)
    }

    func testRecord_MultipleMetrics() async {
        let store = MetricsStore(maxCapacity: 10)

        for i in 0..<5 {
            let metrics = makeMetrics(taskId: "t\(i)", latencyMs: Double(100 + i * 50))
            await store.record(metrics: metrics)
        }

        let count = await store.count()
        XCTAssertEqual(count, 5)
    }

    // MARK: - Ring Buffer Behavior

    func testRingBuffer_OverwritesOldestWhenFull() async {
        let store = MetricsStore(maxCapacity: 3)

        // Fill the buffer
        await store.record(metrics: makeMetrics(taskId: "t1", latencyMs: 100))
        await store.record(metrics: makeMetrics(taskId: "t2", latencyMs: 200))
        await store.record(metrics: makeMetrics(taskId: "t3", latencyMs: 300))

        // Buffer is full at 3
        let countBefore = await store.count()
        XCTAssertEqual(countBefore, 3)

        // Add one more - should overwrite t1
        await store.record(metrics: makeMetrics(taskId: "t4", latencyMs: 400))

        // Count stays at 3
        let countAfter = await store.count()
        XCTAssertEqual(countAfter, 3)

        // Total recorded should be 4
        let total = await store.totalRecorded()
        XCTAssertEqual(total, 4)
    }

    func testRingBuffer_LargeOverflow() async {
        let store = MetricsStore(maxCapacity: 5)

        // Write 20 records into a buffer of 5
        for i in 0..<20 {
            await store.record(metrics: makeMetrics(taskId: "t\(i)", latencyMs: Double(i * 10)))
        }

        let count = await store.count()
        XCTAssertEqual(count, 5)

        let total = await store.totalRecorded()
        XCTAssertEqual(total, 20)
    }

    // MARK: - Summary Computation

    func testSummary_MedianLatency() async {
        let store = MetricsStore(maxCapacity: 100)

        // Record latencies: 100, 200, 300, 400, 500
        for latency in [100.0, 200.0, 300.0, 400.0, 500.0] {
            await store.record(metrics: makeMetrics(latencyMs: latency))
        }

        let summary = await store.summary()

        // Median of [100, 200, 300, 400, 500] = 300
        XCTAssertEqual(summary.medianLatencyMs, 300.0, accuracy: 1.0)
    }

    func testSummary_P95Latency() async {
        let store = MetricsStore(maxCapacity: 100)

        // Record 20 latencies from 50 to 1000
        let latencies = stride(from: 50.0, through: 1000.0, by: 50.0).map { $0 }
        for latency in latencies {
            await store.record(metrics: makeMetrics(latencyMs: latency))
        }

        let summary = await store.summary()

        // P95 should be close to the high end
        XCTAssertGreaterThan(summary.p95LatencyMs, 900.0)
        XCTAssertLessThanOrEqual(summary.p95LatencyMs, 1000.0)
    }

    func testSummary_EscalationRate() async {
        let store = MetricsStore(maxCapacity: 100)

        // 3 escalated out of 10
        for i in 0..<10 {
            await store.record(metrics: makeMetrics(
                taskId: "t\(i)",
                escalated: i < 3
            ))
        }

        let summary = await store.summary()
        XCTAssertEqual(summary.escalationRate, 0.3, accuracy: 0.01)
    }

    func testSummary_LowConfidenceSafeCount() async {
        let store = MetricsStore(maxCapacity: 100)

        // 4 safe with low confidence
        await store.record(metrics: makeMetrics(verdict: "safe", confidence: 0.5))
        await store.record(metrics: makeMetrics(verdict: "safe", confidence: 0.6))
        await store.record(metrics: makeMetrics(verdict: "safe", confidence: 0.65))
        await store.record(metrics: makeMetrics(verdict: "safe", confidence: 0.69))
        // These should NOT count (confidence >= 0.7 or not safe)
        await store.record(metrics: makeMetrics(verdict: "safe", confidence: 0.7))
        await store.record(metrics: makeMetrics(verdict: "safe", confidence: 0.95))
        await store.record(metrics: makeMetrics(verdict: "scam", confidence: 0.5))

        let summary = await store.summary()
        XCTAssertEqual(summary.lowConfidenceSafeCount, 4)
    }

    // MARK: - Reset

    func testReset_ClearsAllData() async {
        let store = MetricsStore(maxCapacity: 10)

        await store.record(metrics: makeMetrics(taskId: "t1"))
        await store.record(metrics: makeMetrics(taskId: "t2"))

        await store.reset()

        let count = await store.count()
        XCTAssertEqual(count, 0)

        let total = await store.totalRecorded()
        XCTAssertEqual(total, 0)

        let summary = await store.summary()
        XCTAssertEqual(summary.medianLatencyMs, 0)
    }

    // MARK: - Default Capacity

    func testDefaultCapacity_Is500() async {
        let store = MetricsStore()
        let capacity = await store.maxCapacity
        XCTAssertEqual(capacity, 500)
    }

    // MARK: - Edge Cases

    func testSummary_SingleRecord() async {
        let store = MetricsStore(maxCapacity: 10)

        await store.record(metrics: makeMetrics(latencyMs: 250))

        let summary = await store.summary()
        XCTAssertEqual(summary.medianLatencyMs, 250.0, accuracy: 0.01)
        XCTAssertEqual(summary.p95LatencyMs, 250.0, accuracy: 0.01)
    }

    func testSummary_TwoRecords() async {
        let store = MetricsStore(maxCapacity: 10)

        await store.record(metrics: makeMetrics(latencyMs: 100))
        await store.record(metrics: makeMetrics(latencyMs: 200))

        let summary = await store.summary()
        // Median of [100, 200] with interpolation = 150
        XCTAssertEqual(summary.medianLatencyMs, 150.0, accuracy: 1.0)
    }

    // MARK: - Helpers

    private func makeMetrics(
        taskId: String = UUID().uuidString,
        latencyMs: Double = 200.0,
        verdict: String = "safe",
        confidence: Double = 0.9,
        escalated: Bool = false
    ) -> InferenceMetrics {
        InferenceMetrics(
            taskId: taskId,
            modelTier: escalated ? "e4b" : "e2b",
            escalatedToE4B: escalated,
            firstTokenLatencyMs: latencyMs * 0.1,
            totalLatencyMs: latencyMs,
            tokensPerSecond: 25.0,
            peakRSSBytes: 500_000_000,
            toolCallCount: 2,
            verdict: verdict,
            confidence: confidence,
            language: "en",
            timestamp: Date()
        )
    }
}
