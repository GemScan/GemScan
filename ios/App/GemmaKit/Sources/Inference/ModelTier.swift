import Foundation

/// The on-device model tier used for inference.
///
/// Each tier maps to a specific model size and RAM budget.
public enum ModelTier: String, Codable, Sendable {
    /// Gemma 2B — lightweight triage model.
    case e2b = "e2b"
    /// Gemma 4B — full deep-scan model.
    case e4b = "e4b"
    /// DistilBERT — ultra-light classifier for background extensions.
    case distilbert = "distilbert"

    /// Expected peak RAM consumption in bytes for this model tier.
    public var expectedRAMBytes: Int {
        switch self {
        case .e2b:
            return 1_800 * 1_024 * 1_024
        case .e4b:
            return 3_200 * 1_024 * 1_024
        case .distilbert:
            return 5 * 1_024 * 1_024
        }
    }

    /// Whether this tier ships as a GGUF file (vs. Core ML / TFLite for distilbert).
    /// Used by ``ModelLoader/verify(tier:)`` to decide whether to check magic bytes.
    public var usesGGUFFormat: Bool {
        switch self {
        case .e2b, .e4b:    return true
        case .distilbert:   return false
        }
    }
}
