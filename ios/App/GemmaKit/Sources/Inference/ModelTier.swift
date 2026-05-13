import Foundation

/// The on-device model tier used for inference.
///
/// Each tier maps to a specific model size and RAM budget.
public enum ModelTier: String, Codable, Sendable {
    /// Gemma 4 E2B — the primary on-device model (multimodal: text + vision + audio).
    /// Runs as the 4-bit MLX quant on iOS; ~3.4 GB working set.
    case e2b = "e2b"
    /// DistilBERT — ultra-light classifier for background extensions.
    case distilbert = "distilbert"

    /// Expected peak RAM consumption in bytes for this model tier.
    public var expectedRAMBytes: Int {
        switch self {
        case .e2b:
            return 3_400 * 1_024 * 1_024
        case .distilbert:
            return 5 * 1_024 * 1_024
        }
    }

    /// Whether this tier ships as a GGUF file (vs. Core ML / TFLite for distilbert).
    /// Used by ``ModelLoader/verify(tier:)`` to decide whether to check magic bytes.
    public var usesGGUFFormat: Bool {
        switch self {
        case .e2b:          return true
        case .distilbert:   return false
        }
    }
}
