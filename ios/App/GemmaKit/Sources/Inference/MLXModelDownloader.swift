import Foundation
import MLXLLM
import MLXLMCommon
import MLXHuggingFace
import HuggingFace
import Tokenizers

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
            // 4-bit (3.4 GB) is the largest gemma-4-e2b quant that fits in iOS's
            // memory budget. Requires com.apple.developer.kernel.increased-memory-limit
            // on the app to raise the per-process cap above the default ~2 GB.
            return ModelConfiguration(id: "mlx-community/gemma-4-e2b-it-4bit")
        }
    }

    /// HuggingFace repo ID (`org/repo`) used by ``configuration(for:)`` for a
    /// tier. Exposed as a plain string so callers outside GemmaKit don't have
    /// to import MLXLMCommon just to inspect the cache path.
    public static func repoID(for tier: ModelTier) -> String {
        switch tier {
        case .e2b:
            return "mlx-community/gemma-4-e2b-it-4bit"
        }
    }

    /// Returns whether the weights for `tier` are present in the local
    /// HuggingFace snapshot cache that `#hubDownloader()` populates.
    ///
    /// On iOS the cache lives at
    /// `<sandbox>/Library/Caches/huggingface/hub/<kind>--<ns>--<repo>/`, with
    /// `refs/main` containing the commit hash and the model files materialised
    /// under `snapshots/<commit>/`. We probe `config.json` of the snapshot
    /// `refs/main` points to — every HF model repo has one, and `cachedFilePath`
    /// only returns a non-nil URL when the snapshot file is actually on disk.
    public static func isCached(tier: ModelTier) -> Bool {
        guard let repo = Repo.ID(rawValue: repoID(for: tier)) else {
            return false
        }
        return HubCache.default.cachedFilePath(
            repo: repo,
            kind: .model,
            revision: "main",
            filename: "config.json"
        ) != nil
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
    ///   - tier: The MLX model tier to fetch (`.e2b`).
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
            from: #hubDownloader(),
            using: #huggingFaceTokenizerLoader(),
            configuration: configuration,
            progressHandler: progressHandler
        )
    }
}
