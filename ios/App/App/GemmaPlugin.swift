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
        CAPPluginMethod(name: "getDeviceStatus", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "setScreeningMode", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "recordActivity", returnType: CAPPluginReturnPromise),
    ]

    // MARK: - Screening modes

    public enum ScreeningMode: String, Sendable {
        case passive
        case active
        case guardianMode = "guardian"
    }

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

    // MARK: - Mode-aware unload lifecycle

    /// Passive mode: unload models 5 minutes after the app backgrounds.
    /// Foreground time doesn't count — the timer only runs while backgrounded.
    private let passiveBackgroundUnloadSeconds: TimeInterval = 5 * 60

    /// Active / Guardian mode: unload models when no activity has been recorded
    /// for 15 minutes, regardless of foreground/background state. Activity
    /// includes incoming notifications from connected extensions, foreground
    /// returns, and any `analyse()` call. Models are reloaded on next activity.
    private let activeIdleUnloadSeconds: TimeInterval = 15 * 60

    /// Current screening mode. Mirrors the JS-side store; updated via
    /// ``setScreeningMode(_:)``.
    private var currentScreeningMode: ScreeningMode = .active

    /// Pending unload task. Cancelled and re-scheduled on every state/activity
    /// change so only the most recent intent is in flight.
    private var pendingUnloadTask: Task<Void, Never>?

    /// Background-task handle that keeps iOS from suspending the process
    /// before the unload timer fires (passive mode only).
    private var unloadBackgroundTaskID: UIBackgroundTaskIdentifier = .invalid

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

    /// One-time bootstrap of MCP servers + CallKit. Idempotent.
    private func bootstrap() async {
        let client = MCPClient()
        await Self.registerMCPServers(with: client)
        self.mcpClient = client
        Self.configureCallKit()
        logger.info("GemmaPlugin bootstrap complete")
    }

    /// Sets up `UIApplication` lifecycle notifications so passive-mode and
    /// active/guardian-mode unload behaviour can be driven from app state.
    private func registerLifecycleObservers() {
        let center = NotificationCenter.default

        let didEnterBackground = center.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleDidEnterBackground()
        }

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
            // OS will reclaim memory anyway; cancel the timer so we don't leak
            // the background-task handle.
            self?.cancelPendingUnload(reason: "terminating")
        }

        lifecycleObservers = [didEnterBackground, willEnterForeground, willTerminate]
    }

    // MARK: Lifecycle handlers

    @MainActor
    private func handleDidEnterBackground() {
        switch currentScreeningMode {
        case .passive:
            // Passive: 5-minute timer that only runs while backgrounded.
            scheduleBackgroundUnload(delaySeconds: passiveBackgroundUnloadSeconds)
        case .active, .guardianMode:
            // Active/Guardian: idle timer continues from wherever it was; no
            // separate background-only timer. The same Task that started on
            // last activity will keep counting down even while we're backgrounded.
            break
        }
    }

    @MainActor
    private func handleWillEnterForeground() {
        // Foreground return is itself an activity — reset the active-mode
        // idle timer, and tear down any passive-mode background timer.
        cancelPendingUnload(reason: "foreground")
        switch currentScreeningMode {
        case .passive:
            break
        case .active, .guardianMode:
            scheduleIdleUnload(delaySeconds: activeIdleUnloadSeconds)
        }

        // If models were unloaded during background and we're now back, warm
        // E2B back up so the home screen feels responsive.
        Task { [weak self] in await self?.reloadIfUnloaded() }
    }

    // MARK: Mode + activity entry points

    /// Updates the current screening mode and adjusts the unload timer.
    public func updateScreeningMode(_ mode: ScreeningMode) {
        let previous = currentScreeningMode
        currentScreeningMode = mode
        logger.info("Screening mode: \(previous.rawValue) → \(mode.rawValue)")

        Task { @MainActor [weak self] in
            guard let self = self else { return }
            self.cancelPendingUnload(reason: "mode change")

            let appState = UIApplication.shared.applicationState
            switch mode {
            case .passive where appState == .background:
                self.scheduleBackgroundUnload(delaySeconds: self.passiveBackgroundUnloadSeconds)
            case .passive:
                break // foreground passive: nothing to schedule until backgrounded
            case .active, .guardianMode:
                self.scheduleIdleUnload(delaySeconds: self.activeIdleUnloadSeconds)
            }
        }
    }

    /// Records an activity event (incoming SMS analysed by the filter
    /// extension, share-sheet invocation, foreground return, JS analyse call,
    /// etc.). In active/guardian mode this resets the 15-minute idle timer
    /// and reloads models if they were unloaded.
    public func recordActivityNow() {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            switch self.currentScreeningMode {
            case .passive:
                // Activity doesn't extend the passive timer — but if the
                // extension woke the host app, we want to make sure models
                // are warm for the imminent analysis.
                Task { [weak self] in await self?.reloadIfUnloaded() }
            case .active, .guardianMode:
                self.cancelPendingUnload(reason: "activity")
                self.scheduleIdleUnload(delaySeconds: self.activeIdleUnloadSeconds)
                Task { [weak self] in await self?.reloadIfUnloaded() }
            }
        }
    }

    // MARK: Timer scheduling

    @MainActor
    private func scheduleBackgroundUnload(delaySeconds: TimeInterval) {
        pendingUnloadTask?.cancel()
        unloadBackgroundTaskID = UIApplication.shared.beginBackgroundTask(
            withName: "GemScanPassiveUnload"
        ) { [weak self] in
            Task { @MainActor in self?.endBackgroundTask() }
        }
        pendingUnloadTask = makeUnloadTask(delaySeconds: delaySeconds, label: "passive-bg")
        logger.info("Passive: model unload scheduled in \(Int(delaySeconds))s")
    }

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
        endBackgroundTask()
    }

    @MainActor
    private func endBackgroundTask() {
        guard unloadBackgroundTaskID != .invalid else { return }
        UIApplication.shared.endBackgroundTask(unloadBackgroundTaskID)
        unloadBackgroundTaskID = .invalid
    }

    // MARK: Unload + reload

    private func performUnload(reason: String) async {
        if let engine = inferenceEngine {
            logger.info("Unloading models (\(reason))")
            await engine.unloadAllModels()
        } else {
            logger.info("Unload tick (\(reason)) — no engine resident")
        }
        await MainActor.run { self.endBackgroundTask() }
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
            let tiers: [ModelTier] = [.e2b, .distilbert]
            var missing: [String] = []
            for tier in tiers {
                if await modelLoader.localPath(for: tier) == nil {
                    missing.append(tier.rawValue)
                }
            }
            call.resolve([
                "ready": missing.isEmpty,
                "missingModels": missing,
            ])
        }
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
                    switch tier {
                    case .e2b:
                        // MLX tier: fetch via swift-transformers HubApi so
                        // the bytes the user "downloads" are exactly the
                        // bytes inference will load from cache later.
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
                    case .distilbert:
                        // CoreML tier: still uses the URLSession path because
                        // it doesn't live on the HF MLX hub. (In production
                        // this model ships bundled inside the app.)
                        try await modelLoader.download(tier: tier) { [weak self] progress in
                            guard let self = self else { return }
                            self.notifyListeners(
                                "downloadProgress",
                                data: [
                                    "modelId": tier.rawValue,
                                    "progress": progress,
                                    "bytesDownloaded": -1,
                                    "totalBytes": -1,
                                ]
                            )
                        }
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
            switch tier {
            case .e2b:
                // swift-transformers HubApi validates downloads via the HF
                // backend's eTag and refuses to load partial/corrupt files,
                // so the JS-side verification step is a no-op for the MLX tier.
                call.resolve([
                    "valid": true,
                    "sizeBytes": -1,
                ])
            case .distilbert:
                let result = await modelLoader.verify(tier: tier)
                var payload: [String: Any] = [
                    "valid": result.valid,
                    "sizeBytes": result.sizeBytes,
                ]
                if let reason = result.reason {
                    payload["reason"] = reason
                }
                call.resolve(payload)
            }
        }
    }

    // MARK: - analyse

    @objc func analyse(_ call: CAPPluginCall) {
        // The full analyse() pipeline depends on InferenceEngine being
        // instantiated with backends (MLX or llama.cpp), which requires the
        // models to be downloaded first. This stub keeps the bridge contract
        // honest: if the engine isn't ready, JS gets a clear error rather
        // than a silent hang. Wire up engine init here when ready.
        Task {
            let tiers: [ModelTier] = [.e2b, .distilbert]
            var missing: [String] = []
            for tier in tiers {
                if await modelLoader.localPath(for: tier) == nil {
                    missing.append(tier.rawValue)
                }
            }
            if !missing.isEmpty {
                call.reject(
                    "Models not downloaded: \(missing.joined(separator: ", "))",
                    "MODELS_NOT_READY"
                )
                return
            }

            // Engine wiring goes here. For now, return a clear unimplemented error
            // so the JS analyse flow surfaces something actionable.
            call.reject("Inference pipeline not yet wired in native plugin", "NOT_IMPLEMENTED")
        }
    }

    // MARK: - setScreeningMode

    @objc func setScreeningMode(_ call: CAPPluginCall) {
        guard let modeStr = call.getString("mode"),
              let mode = ScreeningMode(rawValue: modeStr) else {
            call.reject("Invalid 'mode' (expected: passive, active, or guardian)")
            return
        }
        updateScreeningMode(mode)
        call.resolve()
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
                "screeningMode": "active",
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
