import Foundation

/// Errors raised within the GemScan inference and agent pipeline.
///
/// All descriptions are PII-safe — they never expose raw email content,
/// task identifiers, or underlying error details.
public enum GemScanError: Error, CustomStringConvertible, Sendable {
    /// The requested model tier is not loaded in memory.
    case modelNotLoaded(tier: ModelTier)
    /// Inference exceeded the allowed time budget.
    case inferenceTimeout(taskId: String, limitMs: Int)
    /// The system rejected the request due to insufficient memory.
    case oomRejected(requestedBytes: Int, availableBytes: Int)
    /// The model produced output that violates the expected grammar.
    case grammarViolation(raw: String)
    /// An MCP tool call failed.
    case mcpToolFailed(server: String, tool: String, underlying: Error)
    /// Audio ingestion is not available.
    case audioIngestionUnavailable(reason: String)
    /// The device thermal state is too high to safely run inference.
    case thermalThrottled
    /// Resident memory exceeds the safe limit for loading or running a model.
    case memoryPressure(currentBytes: Int, limitBytes: Int)
    /// The model weights file could not be found on disk.
    case modelFileNotFound(tier: ModelTier)
    /// Loading the model failed for a backend-specific reason.
    case modelLoadFailed(reason: String)
    /// Text generation exceeded the allowed timeout.
    case generationTimeout(seconds: TimeInterval)
    /// Tokenization of the input text failed.
    case tokenizationFailed
    /// Audio decoding or conversion failed.
    case audioDecodingFailed(reason: String)
    /// Model checksum verification failed after download.
    case checksumMismatch
    /// A generic inference error with a freeform message.
    case inferenceError(message: String)

    public var description: String {
        switch self {
        case let .modelNotLoaded(tier):
            return "Model tier '\(tier.rawValue)' is not loaded."
        case let .inferenceTimeout(_, limitMs):
            return "Inference timed out after \(limitMs) ms."
        case let .oomRejected(requestedBytes, availableBytes):
            return "OOM rejected: requested \(requestedBytes) bytes but only \(availableBytes) bytes available."
        case let .grammarViolation(raw):
            let truncated = raw.count > 50 ? String(raw.prefix(50)) + "…" : raw
            return "Grammar violation: \(truncated)"
        case let .mcpToolFailed(server, tool, _):
            return "MCP tool '\(tool)' on server '\(server)' failed."
        case let .audioIngestionUnavailable(reason):
            return "Audio ingestion unavailable: \(reason)"
        case .thermalThrottled:
            return "Device is thermally throttled."
        case let .memoryPressure(current, limit):
            return "Memory pressure: using \(current / 1_000_000) MB of \(limit / 1_000_000) MB limit."
        case let .modelFileNotFound(tier):
            return "Model file for '\(tier.rawValue)' not found on disk."
        case let .modelLoadFailed(reason):
            return "Model load failed: \(reason)"
        case let .generationTimeout(seconds):
            return "Generation timed out after \(Int(seconds)) seconds."
        case .tokenizationFailed:
            return "Failed to tokenize input text."
        case let .audioDecodingFailed(reason):
            return "Audio decoding failed: \(reason)"
        case .checksumMismatch:
            return "Downloaded model checksum does not match expected value."
        case let .inferenceError(message):
            return message
        }
    }
}
