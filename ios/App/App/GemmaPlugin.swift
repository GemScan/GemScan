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
    ]

    // MARK: - Components

    /// Logger for plugin lifecycle and bridged calls.
    private let logger = GemScanLogger.plugin

    /// Singleton-ish model loader shared across all plugin calls.
    private let modelLoader = ModelLoader()

    /// MCP client and orchestrator are lazily set up on first use of `analyse`.
    private var mcpClient: MCPClient?
    private var router: MessageRouter?
    private var setupTask: Task<Void, Error>?

    // MARK: - Lifecycle

    public override func load() {
        logger.info("GemmaPlugin loading…")
        // Defer heavy setup until first analyse() call so the model-download
        // UX in Settings can run before any inference machinery is built.
        Task.detached { [weak self] in
            await self?.bootstrap()
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

    // MARK: - isReady

    @objc func isReady(_ call: CAPPluginCall) {
        Task {
            let tiers: [ModelTier] = [.e2b, .e4b, .distilbert]
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
                    try await modelLoader.download(tier: tier) { [weak self] progress in
                        guard let self = self else { return }
                        self.notifyListeners(
                            "downloadProgress",
                            data: [
                                "modelId": tier.rawValue,
                                "progress": progress,
                                // bytesDownloaded / totalBytes are reported by the
                                // URLSession delegate but not surfaced through the
                                // current ModelLoader callback signature; emit -1
                                // sentinels so the JS side can tolerate them.
                                "bytesDownloaded": -1,
                                "totalBytes": -1,
                            ]
                        )
                    }
                    // Emit a final 1.0 in case the URLSession delegate stopped
                    // calling slightly before completion.
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
                self.logger.error("Download failed: \(error.localizedDescription)")
                call.reject(error.localizedDescription, nil, error)
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

    // MARK: - analyse

    @objc func analyse(_ call: CAPPluginCall) {
        // The full analyse() pipeline depends on InferenceEngine being
        // instantiated with backends (MLX or llama.cpp), which requires the
        // models to be downloaded first. This stub keeps the bridge contract
        // honest: if the engine isn't ready, JS gets a clear error rather
        // than a silent hang. Wire up engine init here when ready.
        Task {
            let tiers: [ModelTier] = [.e2b, .e4b, .distilbert]
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

    // MARK: - getDeviceStatus

    @objc func getDeviceStatus(_ call: CAPPluginCall) {
        Task {
            let memory = ProcessInfo.processInfo.physicalMemory
            let thermal = thermalStateString(ProcessInfo.processInfo.thermalState)

            let e2bLoaded = await modelLoader.localPath(for: .e2b) != nil
            let e4bLoaded = await modelLoader.localPath(for: .e4b) != nil

            let battery = await MainActor.run { () -> Double in
                UIDevice.current.isBatteryMonitoringEnabled = true
                let level = Double(UIDevice.current.batteryLevel)
                // batteryLevel returns -1 when monitoring is unsupported.
                return level >= 0 ? level : 1.0
            }

            call.resolve([
                "availableMemoryBytes": memory,
                "e2bLoaded": e2bLoaded,
                "e4bLoaded": e4bLoaded,
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
