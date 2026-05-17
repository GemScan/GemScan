import Foundation

/// Unique string identifiers for each agent in the pipeline.
///
/// Uses a caseless enum namespace to prevent instantiation while
/// providing compile-time–constant agent identifiers that match
/// the TypeScript `agentId` field in `AgentResult`.
public enum AgentID {
    /// The top-level orchestrator that delegates to specialist agents.
    public static let orchestrator = "orchestrator"
    /// Handles SMS and email text classification.
    public static let textAgent = "text-agent"
    /// Handles URL reputation and phishing checks.
    public static let urlAgent = "url-agent"
    /// Handles screenshot and image analysis via multimodal vision.
    public static let imageAgent = "image-agent"
}
