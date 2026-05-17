import Foundation
import UIKit
import Capacitor
import GemmaKit
import os

/// Capacitor bridge that exposes GemmaKit (`ModelLoader`, inference, MCP, agent
/// orchestration) to the JavaScript runtime.
///
/// The plugin is Swift-only and self-registers via ``CAPBridgedPlugin``, so no
/// Objective-C `.m` macro file is required. Methods declared in
/// ``pluginMethods`` are callable from JS via the `Capacitor.Plugins.GemmaPlugin`
/// proxy.
///
/// Events emitted via ``notifyListeners(_:data:)``:
/// - `downloadProgress` — fired periodically during ``downloadModels(_:)``
/// - `tokenStream` — reserved for future streaming-inference work
/// - `guardianModeChanged` — reserved for Guardian-mode state changes
@objc(GemmaPlugin)
public class GemmaPlugin: CAPPlugin, CAPBridgedPlugin {

    public let identifier = "GemmaPlugin"
    public let jsName = "GemmaPlugin"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "isReady", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "downloadModels", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "verifyModel", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "analyse", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "warmUp", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "getDeviceStatus", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "recordActivity", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "generateHaiku", returnType: CAPPluginReturnPromise),
    ]

    // MARK: - Components

    /// Logger for plugin lifecycle and bridged calls.
    private let logger = GemScanLogger.plugin

    /// Singleton-ish model loader shared across all plugin calls.
    private let modelLoader = ModelLoader()

    /// MCP client and orchestrator are lazily set up on first use of `analyse`.
    private var mcpClient: MCPClient?
    private var router: MessageRouter?
    private var inferenceEngine: InferenceEngine?
    private var setupTask: Task<Void, Error>?

    // MARK: - Idle unload lifecycle

    /// Unload models when no activity has been recorded for 15 minutes,
    /// regardless of foreground/background state. Activity includes incoming
    /// notifications from connected extensions, foreground returns, and any
    /// `analyse()` call. Models are reloaded on next activity.
    private let activeIdleUnloadSeconds: TimeInterval = 15 * 60

    /// Pending unload task. Cancelled and re-scheduled on every activity event
    /// so only the most recent intent is in flight.
    private var pendingUnloadTask: Task<Void, Never>?

    /// Lifecycle observer tokens. Removed on plugin deinit.
    private var lifecycleObservers: [NSObjectProtocol] = []

    // MARK: - Lifecycle

    public override func load() {
        logger.info("GemmaPlugin loading…")
        // Defer heavy setup until first analyse() call so the model-download
        // UX in Settings can run before any inference machinery is built.
        Task.detached { [weak self] in
            await self?.bootstrap()
        }
        registerLifecycleObservers()
    }

    deinit {
        for token in lifecycleObservers {
            NotificationCenter.default.removeObserver(token)
        }
    }

    /// One-time bootstrap of MCP servers. Idempotent.
    private func bootstrap() async {
        let client = MCPClient()
        await Self.registerMCPServers(with: client)
        self.mcpClient = client
        logger.info("GemmaPlugin bootstrap complete")
    }

    /// Sets up `UIApplication` lifecycle notifications so the idle-unload
    /// timer can be reset on foreground and cancelled on terminate.
    private func registerLifecycleObservers() {
        let center = NotificationCenter.default

        let willEnterForeground = center.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleWillEnterForeground()
        }

        let willTerminate = center.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.cancelPendingUnload(reason: "terminating")
        }

        lifecycleObservers = [willEnterForeground, willTerminate]
    }

    // MARK: Lifecycle handlers

    @MainActor
    private func handleWillEnterForeground() {
        // Foreground return is itself an activity — reset the idle timer.
        cancelPendingUnload(reason: "foreground")
        scheduleIdleUnload(delaySeconds: activeIdleUnloadSeconds)

        // If models were unloaded during background and we're now back, warm
        // E2B back up so the home screen feels responsive.
        Task { [weak self] in await self?.reloadIfUnloaded() }
    }

    // MARK: Activity entry point

    /// Records an activity event (incoming SMS analysed by the filter
    /// extension, share-sheet invocation, foreground return, JS analyse call,
    /// etc.). Resets the 15-minute idle timer and reloads models if they were
    /// unloaded.
    public func recordActivityNow() {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            self.cancelPendingUnload(reason: "activity")
            self.scheduleIdleUnload(delaySeconds: self.activeIdleUnloadSeconds)
            Task { [weak self] in await self?.reloadIfUnloaded() }
        }
    }

    // MARK: Timer scheduling

    @MainActor
    private func scheduleIdleUnload(delaySeconds: TimeInterval) {
        pendingUnloadTask?.cancel()
        pendingUnloadTask = makeUnloadTask(delaySeconds: delaySeconds, label: "idle")
        logger.info("Active: idle unload scheduled in \(Int(delaySeconds))s")
    }

    @MainActor
    private func makeUnloadTask(delaySeconds: TimeInterval, label: String) -> Task<Void, Never> {
        return Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
            } catch {
                return  // cancelled
            }
            await self?.performUnload(reason: label)
        }
    }

    @MainActor
    private func cancelPendingUnload(reason: String) {
        if pendingUnloadTask != nil {
            logger.info("Cancelling pending unload (\(reason))")
        }
        pendingUnloadTask?.cancel()
        pendingUnloadTask = nil
    }

    // MARK: Unload + reload

    private func performUnload(reason: String) async {
        if let engine = inferenceEngine {
            logger.info("Unloading models (\(reason))")
            await engine.unloadAllModels()
        } else {
            logger.info("Unload tick (\(reason)) — no engine resident")
        }
    }

    private func reloadIfUnloaded() async {
        guard let engine = inferenceEngine else { return }
        let e2bLoaded = await engine.isModelLoaded(tier: .e2b)
        if !e2bLoaded {
            logger.info("Activity arrived with E2B unloaded — warming up")
            try? await engine.warmLoadE2B()
        }
    }

    // MARK: - isReady

    @objc func isReady(_ call: CAPPluginCall) {
        Task {
            let tiers: [ModelTier] = [.e2b]
            let missing = tiers.filter { !Self.isModelCached(tier: $0) }
                              .map(\.rawValue)
            call.resolve([
                "ready": missing.isEmpty,
                "missingModels": missing,
            ])
        }
    }

    /// Returns whether the MLX weights for a tier are present in the local
    /// HuggingFace snapshot cache that `#hubDownloader()` writes into.
    /// Delegates to ``MLXModelRegistry/isCached(tier:)`` so the cache-layout
    /// knowledge lives next to the repo-ID registry.
    private static func isModelCached(tier: ModelTier) -> Bool {
        return MLXModelRegistry.isCached(tier: tier)
    }

    // MARK: - downloadModels

    @objc func downloadModels(_ call: CAPPluginCall) {
        guard let modelIds = call.getArray("modelIds", String.self) else {
            call.reject("Missing or invalid 'modelIds'")
            return
        }

        let tiers = modelIds.compactMap { ModelTier(rawValue: $0) }
        if tiers.count != modelIds.count {
            call.reject("Unknown model id in: \(modelIds)")
            return
        }

        Task {
            do {
                for tier in tiers {
                    // Only tier is .e2b. Fetch via swift-transformers HubApi
                    // so the bytes the user "downloads" are exactly the bytes
                    // inference will load from cache later.
                    try await MLXModelDownloader.preload(tier: tier) { [weak self] progress in
                        guard let self = self else { return }
                        self.notifyListeners(
                            "downloadProgress",
                            data: [
                                "modelId": tier.rawValue,
                                "progress": progress.fractionCompleted,
                                "bytesDownloaded": Int(progress.completedUnitCount),
                                "totalBytes": Int(progress.totalUnitCount),
                            ]
                        )
                    }
                    // Final 1.0 emit in case the underlying progress source
                    // stopped slightly before completion.
                    notifyListeners(
                        "downloadProgress",
                        data: [
                            "modelId": tier.rawValue,
                            "progress": 1.0,
                            "bytesDownloaded": -1,
                            "totalBytes": -1,
                        ]
                    )
                }
                call.resolve()
            } catch {
                // HuggingFace.HTTPClientError conforms to CustomStringConvertible
                // but its bridged NSError.localizedDescription drops the status
                // code and detail. String(describing:) preserves them.
                let detail = String(describing: error)
                self.logger.error("Download failed: \(detail)")
                call.reject(detail, nil, error)
            }
        }
    }

    // MARK: - verifyModel

    @objc func verifyModel(_ call: CAPPluginCall) {
        guard let modelIdString = call.getString("modelId"),
              let tier = ModelTier(rawValue: modelIdString) else {
            call.reject("Missing or unknown 'modelId'")
            return
        }

        Task {
            // swift-transformers HubApi validates downloads via the HF
            // backend's eTag and refuses to load partial/corrupt files, so
            // "verification" on iOS is just confirming the snapshot is on
            // disk where the loader will look for it. Without this check,
            // a Settings-side "Verified" can drift out of sync with what
            // analyse() finds in the cache.
            let cached = Self.isModelCached(tier: tier)
            call.resolve([
                "valid": cached,
                "sizeBytes": -1,
                "reason": cached ? "" : "Not downloaded",
            ])
        }
    }

    // MARK: - analyse

    @objc func analyse(_ call: CAPPluginCall) {
        // Capture the JS task dictionary now — Capacitor's CAPPluginCall is
        // bound to the WebView's serializer, so we re-encode it as JSON and
        // decode into a Swift AgentTask via Codable.
        guard let taskDict = call.options as? [String: Any],
              let payloadJSON = try? JSONSerialization.data(withJSONObject: taskDict) else {
            call.reject("Could not serialise task payload", "INVALID_TASK")
            return
        }

        Task { [weak self] in
            guard let self = self else { return }

            // Don't even try to set up the engine if the model bytes aren't
            // on disk — surface a clear "download first" error instead of
            // letting MLX throw a confusing missing-file error mid-load.
            guard Self.isModelCached(tier: .e2b) else {
                call.reject("Model e2b is not downloaded", "MODELS_NOT_READY")
                return
            }

            let task: AgentTask
            do {
                task = try JSONDecoder().decode(AgentTask.self, from: payloadJSON)
            } catch {
                self.logger.error("analyse: decode failed: \(String(describing: error))")
                call.reject("Could not decode AgentTask: \(error.localizedDescription)", "INVALID_TASK")
                return
            }

            do {
                let orchestrator = try await self.ensureOrchestratorReady()
                self.recordActivityNow()
                let result = try await orchestrator.dispatch(task: task)
                let resultData = try JSONEncoder().encode(result)
                guard let resultDict = try JSONSerialization.jsonObject(with: resultData) as? [String: Any] else {
                    call.reject("Could not serialise AgentResult", "RESULT_SERIALIZATION_FAILED")
                    return
                }
                call.resolve(resultDict)
            } catch {
                let detail = String(describing: error)
                self.logger.error("analyse failed: \(detail)")
                call.reject(detail, "ANALYSE_FAILED", error)
            }
        }
    }

    // MARK: - warmUp

    /// Eagerly bootstraps the InferenceEngine and loads E2B weights into RAM
    /// without dispatching any task. Intended to be called once after app
    /// launch so the Settings pill flips to "Active" and the first analyse()
    /// call doesn't pay the model-load cost.
    ///
    /// No-op if the model bytes aren't on disk yet — best-effort warm-up
    /// shouldn't fail the call site, which would otherwise have to special-case
    /// the "not downloaded yet" path.
    @objc func warmUp(_ call: CAPPluginCall) {
        Task { [weak self] in
            guard let self = self else { return }

            guard Self.isModelCached(tier: .e2b) else {
                self.logger.info("warmUp skipped — E2B weights not on disk yet")
                call.resolve()
                return
            }

            do {
                _ = try await self.ensureOrchestratorReady()
                self.recordActivityNow()
                call.resolve()
            } catch {
                let detail = String(describing: error)
                self.logger.error("warmUp failed: \(detail)")
                call.reject(detail, "WARMUP_FAILED", error)
            }
        }
    }

    /// Lazily creates the InferenceEngine + warms E2B + configures the
    /// OrchestratorAgent. Idempotent: concurrent callers share the same
    /// in-flight setup task.
    private func ensureOrchestratorReady() async throws -> OrchestratorAgent {
        if let existing = setupTask {
            try await existing.value
            return OrchestratorAgent.shared
        }

        let task = Task<Void, Error> { [weak self] in
            guard let self = self else { return }
            self.logger.info("Bootstrapping InferenceEngine + OrchestratorAgent")

            let backend = MLXInferenceBackend()
            let engine = InferenceEngine(e2bBackend: backend, modelLoader: self.modelLoader)
            self.inferenceEngine = engine

            // Warm-load E2B so the first dispatch doesn't pay the load cost.
            try await engine.warmLoadE2B()

            await OrchestratorAgent.shared.configure(inferenceEngine: engine)
            self.logger.info("OrchestratorAgent ready")
        }
        self.setupTask = task

        do {
            try await task.value
        } catch {
            // Reset on failure so the next call gets a fresh attempt.
            self.setupTask = nil
            self.inferenceEngine = nil
            throw error
        }
        return OrchestratorAgent.shared
    }

    // MARK: - generateHaiku

    @objc func generateHaiku(_ call: CAPPluginCall) {
        Task { [weak self] in
            guard let self = self else { return }

            guard Self.isModelCached(tier: .e2b) else {
                call.reject("Model e2b is not downloaded", "MODELS_NOT_READY")
                return
            }

            do {
                _ = try await self.ensureOrchestratorReady()
                self.recordActivityNow()
                guard let engine = self.inferenceEngine else {
                    call.reject("Inference engine unavailable", "ENGINE_UNAVAILABLE")
                    return
                }
                let prompt = """
                Write one short, funny haiku (5 lines, 5-7-5 syllables) about \
                vibe coding additions. Output only the haiku — no title, \
                no commentary, no quotes.
                """
                let haiku = try await engine.generate(
                    task: prompt,
                    modelTier: .e2b,
                    grammar: nil
                )
                call.resolve(["haiku": haiku.trimmingCharacters(in: .whitespacesAndNewlines)])
            } catch {
                let detail = String(describing: error)
                self.logger.error("generateHaiku failed: \(detail)")
                call.reject(detail, "HAIKU_FAILED", error)
            }
        }
    }

    // MARK: - recordActivity

    @objc func recordActivity(_ call: CAPPluginCall) {
        recordActivityNow()
        call.resolve()
    }

    // MARK: - getDeviceStatus

    @objc func getDeviceStatus(_ call: CAPPluginCall) {
        Task {
            let memory = ProcessInfo.processInfo.physicalMemory
            let thermal = thermalStateString(ProcessInfo.processInfo.thermalState)

            // "Loaded" means actually resident in RAM. If the engine isn't
            // instantiated yet (no analyse() call has happened), nothing is
            // loaded — even if the weights are on disk.
            var e2bLoaded = false
            if let engine = inferenceEngine {
                e2bLoaded = await engine.isModelLoaded(tier: .e2b)
            }

            let battery = await MainActor.run { () -> Double in
                UIDevice.current.isBatteryMonitoringEnabled = true
                let level = Double(UIDevice.current.batteryLevel)
                // batteryLevel returns -1 when monitoring is unsupported.
                return level >= 0 ? level : 1.0
            }

            call.resolve([
                "availableMemoryBytes": memory,
                "e2bLoaded": e2bLoaded,
                "thermalState": thermal,
                "batteryLevel": battery,
            ])
        }
    }

    private func thermalStateString(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal:  return "nominal"
        case .fair:     return "fair"
        case .serious:  return "serious"
        case .critical: return "critical"
        @unknown default: return "nominal"
        }
    }
}
