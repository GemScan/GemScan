import Foundation
import os

// MARK: - InferenceEngine

/// The central coordinator for on-device inference in GemScan.
///
/// `InferenceEngine` manages two model tiers (E2B and E4B), routes generation
/// requests to the appropriate backend, and enforces safety guards for memory
/// pressure, thermal state, and execution timeouts.
public actor InferenceEngine {

    // MARK: - Properties

    /// Backend used for the lightweight Gemma 2B model.
    private let e2bBackend: any InferenceBackend

    /// Backend used for the higher-quality Gemma 4B model.
    private let e4bBackend: any InferenceBackend

    /// Handles model downloading, verification, and local path management.
    public let modelLoader: ModelLoader

    /// Logger for inference operations.
    private let logger = GemScanLogger.inference

    /// Maximum RSS (in bytes) before refusing to load additional models.
    private let maxRSSBytes: Int = 1_500_000_000 // 1.5 GB

    /// Default generation timeout in seconds.
    private let defaultTimeoutSeconds: TimeInterval = 120

    // MARK: - Initialization

    /// Creates a new inference engine with the provided backends.
    ///
    /// - Parameters:
    ///   - e2bBackend: The backend for Gemma 2B inference.
    ///   - e4bBackend: The backend for Gemma 4B inference.
    ///   - modelLoader: The model loader for downloading and verifying weights.
    public init(
        e2bBackend: any InferenceBackend,
        e4bBackend: any InferenceBackend,
        modelLoader: ModelLoader
    ) {
        self.e2bBackend = e2bBackend
        self.e4bBackend = e4bBackend
        self.modelLoader = modelLoader
    }

    // MARK: - Generation

    /// Generates text for the given task using the specified model tier.
    ///
    /// This method enforces timeout, RSS memory limits, and thermal state checks
    /// before dispatching to the appropriate backend. Performance metrics are
    /// logged on completion.
    ///
    /// - Parameters:
    ///   - task: The prompt string describing the task.
    ///   - modelTier: Which model tier to use for generation.
    ///   - grammar: An optional grammar constraint for structured output.
    ///   - tokenHandler: A closure called with each incremental token as it is generated.
    /// - Returns: The fully concatenated generated text.
    public func generate(
        task: String,
        modelTier: ModelTier,
        grammar: GrammarConstraint? = nil,
        tokenHandler: (@Sendable (String) -> Void)? = nil
    ) async throws -> String {

        // Thermal guard
        let thermalState = checkThermalState()
        guard thermalState != .critical else {
            logger.error("Thermal state is critical — refusing generation")
            throw GemScanError.thermalThrottled
        }

        // RSS guard
        let rss = currentRSSBytes()
        guard rss < maxRSSBytes else {
            logger.error("RSS \(rss) exceeds limit \(self.maxRSSBytes) — refusing generation")
            throw GemScanError.memoryPressure(currentBytes: rss, limitBytes: maxRSSBytes)
        }

        let backend: any InferenceBackend = (modelTier == .e2b) ? e2bBackend : e4bBackend

        guard await backend.isLoaded else {
            logger.error("Model \(modelTier.rawValue) is not loaded")
            throw GemScanError.modelNotLoaded(tier: modelTier)
        }

        let startTime = CFAbsoluteTimeGetCurrent()
        var tokenCount = 0

        let stream = try await backend.generate(
            prompt: task,
            grammar: grammar,
            maxTokens: 2048
        )

        // Wrap generation in a timeout task
        let generated: String = try await withThrowingTaskGroup(of: String.self) { group in
            group.addTask {
                var accumulated = ""
                for await token in stream {
                    accumulated += token
                    tokenCount += 1
                    tokenHandler?(token)
                }
                return accumulated
            }

            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(self.defaultTimeoutSeconds * 1_000_000_000))
                throw GemScanError.generationTimeout(seconds: self.defaultTimeoutSeconds)
            }

            guard let first = try await group.next() else {
                throw GemScanError.generationTimeout(seconds: defaultTimeoutSeconds)
            }
            group.cancelAll()
            return first
        }

        // Performance metrics
        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        let tokensPerSecond = elapsed > 0 ? Double(tokenCount) / elapsed : 0
        logger.info("Generation complete: \(tokenCount) tokens in \(String(format: "%.2f", elapsed))s (\(String(format: "%.1f", tokensPerSecond)) tok/s) using \(modelTier.rawValue)")

        return generated
    }

    // MARK: - Model Lifecycle

    /// Warm-loads the E2B model at app launch for fast inference.
    ///
    /// Call this early in the app lifecycle so the lightweight model is ready
    /// when the first inference request arrives.
    public func warmLoadE2B() async throws {
        logger.info("Warm-loading E2B model")
        try await e2bBackend.loadModel(tier: .e2b)
        logger.info("E2B model loaded successfully")
    }

    /// Loads the E4B model on demand, with thermal and memory guards.
    ///
    /// If the device is under thermal or memory pressure the load is refused
    /// and a ``GemScanError`` is thrown.
    public func loadE4BIfNeeded() async throws {
        guard await !e4bBackend.isLoaded else {
            logger.info("E4B model already loaded")
            return
        }

        let thermalState = checkThermalState()
        guard thermalState != .critical, thermalState != .serious else {
            logger.warning("Thermal state \(String(describing: thermalState)) — refusing E4B load")
            throw GemScanError.thermalThrottled
        }

        let rss = currentRSSBytes()
        guard rss < maxRSSBytes else {
            logger.warning("RSS \(rss) exceeds limit — refusing E4B load")
            throw GemScanError.memoryPressure(currentBytes: rss, limitBytes: maxRSSBytes)
        }

        logger.info("Loading E4B model on demand")
        try await e4bBackend.loadModel(tier: .e4b)
        logger.info("E4B model loaded successfully")
    }

    // MARK: - System Helpers

    /// Returns the current resident set size of this process in bytes.
    ///
    /// Uses `mach_task_basic_info` to query the kernel for memory statistics.
    func currentRSSBytes() -> Int {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let result = withUnsafeMutablePointer(to: &info) { infoPtr in
            infoPtr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rawPtr in
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), rawPtr, &count)
            }
        }
        guard result == KERN_SUCCESS else {
            logger.warning("Failed to read task info, returning 0 for RSS")
            return 0
        }
        return Int(info.resident_size)
    }

    /// Returns the current thermal state of the device.
    func checkThermalState() -> ProcessInfo.ThermalState {
        return ProcessInfo.processInfo.thermalState
    }
}
