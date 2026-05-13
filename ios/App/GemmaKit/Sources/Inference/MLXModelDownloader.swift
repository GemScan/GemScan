import Foundation
import MLXLLM
import MLXLMCommon

/// Canonical MLX model identifiers for each tier.
///
/// Single source of truth used by both ``MLXInferenceBackend`` (at load time)
/// and the Capacitor `GemmaPlugin.downloadModels` path (at Settings-driven
/// pre-download time), so the bytes the user "downloads" are exactly the
/// bytes inference will consume.
public enum MLXModelRegistry {

    public static func configuration(for tier: ModelTier) -> ModelConfiguration {
        switch tier {
        case .e2b:
            return ModelConfiguration(id: "mlx-community/gemma-4-e2b-it-8bit")
        case .e4b:
            return ModelConfiguration(id: "mlx-community/gemma-4-e4b-it-8bit")
        case .distilbert:
            // DistilBERT is not an MLX model; the production SMS triage path
            // ships as bundled CoreML. This entry exists only so the switch
            // is exhaustive; callers that route through MLX for this tier
            // will fail at load time.
            return ModelConfiguration(id: "distilbert-base-uncased")
        }
    }
}

/// Resolves weights for an MLX tier via the HuggingFace hub, surfacing
/// `Foundation.Progress` so the JS UI can render a percentage bar.
///
/// First call to `preload(tier:)` downloads from the hub and populates the
/// app sandbox's HF cache. Subsequent calls (for the same tier) hit the cache
/// and complete in milliseconds without firing the progress handler.
public enum MLXModelDownloader {

    /// Pre-fetches the model so a later `analyse()` call doesn't have to.
    ///
    /// The returned ``ModelContainer`` is loaded into memory but not retained
    /// — `LLMModelFactory.shared` is responsible for caching the on-disk
    /// model files; in-memory residency is handled separately by the
    /// inference backend.
    ///
    /// - Parameters:
    ///   - tier: The MLX model tier to fetch (`.e2b` or `.e4b`).
    ///   - progressHandler: Foundation.Progress callback. Fired only on
    ///     cache-miss runs; cache-hit runs complete without progress events.
    /// - Throws: HF or filesystem errors from swift-transformers.
    @discardableResult
    public static func preload(
        tier: ModelTier,
        progressHandler: @Sendable @escaping (Progress) -> Void = { _ in }
    ) async throws -> ModelContainer {
        let configuration = MLXModelRegistry.configuration(for: tier)
        return try await LLMModelFactory.shared.loadContainer(
            configuration: configuration,
            progressHandler: progressHandler
        )
    }
}
