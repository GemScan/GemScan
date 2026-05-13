import Foundation

/// The on-device model tier used for inference.
///
/// GemScan runs every inference path on Gemma 4 E2B. There is no separate
/// background classifier (DistilBERT was retired) — the iOS app's
/// SMS / URL / image / voice analyses all flow through the same E2B
/// backend in the host app process. This is a single-case enum kept
/// around so call sites can keep their tier-tagged metrics, logs, and
/// AgentResult fields without a wider rename.
public enum ModelTier: String, Codable, Sendable {
    /// Gemma 4 E2B — the only on-device model (multimodal: text + vision + audio).
    /// Runs as the 4-bit MLX quant on iOS; ~3.4 GB working set.
    case e2b = "e2b"

    /// Expected peak RAM consumption in bytes for this model tier.
    public var expectedRAMBytes: Int {
        switch self {
        case .e2b:
            return 3_400 * 1_024 * 1_024
        }
    }
}
