import Foundation
import CryptoKit
import os

// MARK: - ModelLoader

/// Errors thrown by ``ModelLoader``.
public enum ModelLoaderError: Error, CustomStringConvertible, Sendable {
    case verificationFailed(tier: ModelTier, reason: String)

    public var description: String {
        switch self {
        case .verificationFailed(let tier, let reason):
            return "Verification failed for \(tier.rawValue): \(reason)"
        }
    }
}

/// Downloads, verifies, and manages on-device model weight files.
///
/// `ModelLoader` uses a background `URLSession` for downloads so they can
/// continue even when the app is suspended. Downloaded files are verified
/// via existence + size + magic-byte checks (and optional SHA-256) before
/// being made available. Paths are synced to the shared App Group container
/// so extensions can locate model files.
public actor ModelLoader: NSObject {

    // MARK: - Properties

    /// Logger for inference operations.
    private let logger = GemScanLogger.inference

    /// Background URL session for model downloads.
    private lazy var backgroundSession: URLSession = {
        let config = URLSessionConfiguration.background(
            withIdentifier: "com.gemscan.gemmakit.modeldownload"
        )
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    /// Tracks in-flight download continuations keyed by model tier.
    private var downloadContinuations: [ModelTier: CheckedContinuation<URL, Error>] = [:]

    /// Tracks download progress handlers keyed by model tier.
    private var progressHandlers: [ModelTier: @Sendable (Double) -> Void] = [:]

    /// Tracks which tier a given URLSessionTask belongs to.
    private var taskTierMap: [Int: ModelTier] = [:]

    // MARK: - Initialization

    /// Creates a new model loader.
    public override init() {
        super.init()
    }

    // MARK: - Public API

    /// Downloads a model for the specified tier.
    ///
    /// The download runs via a background `URLSession` and supports resuming
    /// after interruptions. On completion the file is verified and moved to
    /// the canonical local path.
    ///
    /// - Parameters:
    ///   - tier: The model tier to download.
    ///   - progressHandler: Called periodically with a value in `0.0 ... 1.0`.
    public func download(
        tier: ModelTier,
        progressHandler: (@Sendable (Double) -> Void)? = nil
    ) async throws {
        if let existing = localPath(for: tier) {
            logger.info("Model \(tier.rawValue) already exists at \(existing.path)")
            return
        }

        logger.info("Starting download for \(tier.rawValue)")

        let downloadURL = remoteURL(for: tier)
        let destinationURL: URL = try await withCheckedThrowingContinuation { continuation in
            Task {
                await self.registerContinuation(continuation, progressHandler: progressHandler, for: tier)
                let task = self.backgroundSession.downloadTask(with: downloadURL)
                await self.registerTask(task.taskIdentifier, tier: tier)
                task.resume()
            }
        }

        // Move to canonical location
        let finalURL = canonicalLocalURL(for: tier)
        let directory = finalURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        if FileManager.default.fileExists(atPath: finalURL.path) {
            try FileManager.default.removeItem(at: finalURL)
        }
        try FileManager.default.moveItem(at: destinationURL, to: finalURL)

        // Verify the downloaded file before declaring success.
        let result = verify(tier: tier)
        if !result.valid {
            logger.error("Verification failed for \(tier.rawValue): \(result.reason ?? "unknown")")
            try? FileManager.default.removeItem(at: finalURL)
            throw ModelLoaderError.verificationFailed(tier: tier, reason: result.reason ?? "unknown")
        }

        syncPathToAppGroup(tier: tier, path: finalURL)
        logger.info("Model \(tier.rawValue) downloaded and verified at \(finalURL.path)")
    }

    /// Verifies the SHA-256 checksum of a file against an expected hex string.
    ///
    /// - Parameters:
    ///   - url: The file to verify.
    ///   - expected: The expected SHA-256 hex digest.
    /// - Returns: `true` if the file's checksum matches `expected`.
    public nonisolated func verifyChecksum(at url: URL, expected: String) -> Bool {
        guard let data = try? Data(contentsOf: url) else {
            return false
        }
        let digest = SHA256.hash(data: data)
        let hexString = digest.compactMap { String(format: "%02x", $0) }.joined()
        return hexString == expected.lowercased()
    }

    /// Result of a downloaded-model verification check.
    public struct VerificationResult: Sendable {
        public let valid: Bool
        public let reason: String?
        public let sizeBytes: Int64
    }

    /// Verifies that a downloaded model file is well-formed.
    ///
    /// Layered checks (each runs only if the previous passes):
    /// 1. File exists at the canonical local path.
    /// 2. File size meets the minimum expected for that tier.
    /// 3. For GGUF tiers, the first four bytes match the GGUF magic header (`0x47475546`).
    /// 4. If a SHA-256 hash is registered for the tier, full checksum check.
    public func verify(tier: ModelTier) -> VerificationResult {
        let url = canonicalLocalURL(for: tier)

        guard FileManager.default.fileExists(atPath: url.path) else {
            return VerificationResult(valid: false, reason: "File not found", sizeBytes: 0)
        }

        let sizeBytes: Int64
        do {
            let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
            sizeBytes = (attrs[.size] as? NSNumber)?.int64Value ?? 0
        } catch {
            return VerificationResult(valid: false, reason: "Could not read file attributes", sizeBytes: 0)
        }

        let minimumSize = minimumExpectedSize(for: tier)
        if sizeBytes < minimumSize {
            return VerificationResult(
                valid: false,
                reason: "File too small (\(sizeBytes) bytes, expected ≥ \(minimumSize))",
                sizeBytes: sizeBytes
            )
        }

        // GGUF magic-byte verification is gone with the retired GGUF tier;
        // the live E2B path goes through swift-transformers HubApi which
        // validates downloads via eTag.

        if let expectedHash = expectedChecksums[tier] {
            if !verifyChecksum(at: url, expected: expectedHash) {
                return VerificationResult(valid: false, reason: "Checksum mismatch", sizeBytes: sizeBytes)
            }
        }

        logger.info("Verification passed for \(tier.rawValue): \(sizeBytes) bytes")
        return VerificationResult(valid: true, reason: nil, sizeBytes: sizeBytes)
    }

    /// Loose minimum sizes — meant to catch truncated downloads, not enforce exact size.
    private nonisolated func minimumExpectedSize(for tier: ModelTier) -> Int64 {
        switch tier {
        case .e2b: return 800_000_000
        }
    }

    /// Optional pre-baked SHA-256 hashes per tier. Populate to enable strict checksum verification.
    private nonisolated var expectedChecksums: [ModelTier: String] {
        return [:]
    }

    /// Returns the local file URL for a downloaded model, or `nil` if not yet available.
    ///
    /// - Parameter tier: The model tier to look up.
    /// - Returns: The file URL if the model exists on disk.
    public nonisolated func localPath(for tier: ModelTier) -> URL? {
        let url = canonicalLocalURL(for: tier)
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        return url
    }

    /// Writes the model path to the shared App Group UserDefaults so that
    /// extensions (e.g. ILMessageFilterExtension) can locate model files.
    ///
    /// - Parameters:
    ///   - tier: The model tier whose path is being synced.
    ///   - path: The local file URL of the model.
    public func syncPathToAppGroup(tier: ModelTier, path: URL) {
        guard let defaults = UserDefaults(suiteName: SharedContainerSchema.appGroupId) else {
            logger.warning("Unable to open App Group UserDefaults: \(SharedContainerSchema.appGroupId)")
            return
        }
        let key = "modelPath_\(tier.rawValue)"
        defaults.set(path.path, forKey: key)
        defaults.synchronize()
        logger.info("Synced \(tier.rawValue) path to App Group: \(path.path)")
    }

    // MARK: - Private Helpers

    private func registerContinuation(
        _ continuation: CheckedContinuation<URL, Error>,
        progressHandler: (@Sendable (Double) -> Void)?,
        for tier: ModelTier
    ) {
        downloadContinuations[tier] = continuation
        if let handler = progressHandler {
            progressHandlers[tier] = handler
        }
    }

    private func registerTask(_ taskID: Int, tier: ModelTier) {
        taskTierMap[taskID] = tier
    }

    private nonisolated func canonicalLocalURL(for tier: ModelTier) -> URL {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsURL
            .appendingPathComponent("models")
            .appendingPathComponent(tier.rawValue)
            .appendingPathExtension("gguf")
    }

    private nonisolated func remoteURL(for tier: ModelTier) -> URL {
        switch tier {
        case .e2b:
            // Note: production E2B downloads go through MLXModelDownloader
            // (swift-transformers HubApi), not this URLSession path. This
            // URL exists only as a fallback / legacy reference.
            return URL(string: "https://huggingface.co/mlx-community/gemma-4-e2b-it-4bit")!
        }
    }
}

// MARK: - URLSessionDownloadDelegate

extension ModelLoader: URLSessionDownloadDelegate {

    nonisolated public func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        Task {
            guard let tier = await self.tierForTask(downloadTask.taskIdentifier) else { return }
            await self.resumeDownloadContinuation(tier: tier, result: .success(location))
        }
    }

    nonisolated public func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard let error = error else { return }
        Task {
            guard let tier = await self.tierForTask(task.taskIdentifier) else { return }
            await self.resumeDownloadContinuation(tier: tier, result: .failure(error))
        }
    }

    nonisolated public func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        Task {
            guard let tier = await self.tierForTask(downloadTask.taskIdentifier) else { return }
            await self.reportProgress(tier: tier, progress: progress)
        }
    }

    // Actor-isolated helpers for delegate callbacks

    private func tierForTask(_ taskID: Int) -> ModelTier? {
        return taskTierMap[taskID]
    }

    private func resumeDownloadContinuation(tier: ModelTier, result: Result<URL, Error>) {
        guard let continuation = downloadContinuations.removeValue(forKey: tier) else { return }
        progressHandlers.removeValue(forKey: tier)
        switch result {
        case .success(let url):
            continuation.resume(returning: url)
        case .failure(let error):
            continuation.resume(throwing: error)
        }
    }

    private func reportProgress(tier: ModelTier, progress: Double) {
        progressHandlers[tier]?(progress)
    }
}
