import Foundation

/// Constants for the shared App Group container used by the main app and extensions.
///
/// All keys are namespaced with `gemscan.` to avoid collisions with
/// system or third-party defaults stored in the same App Group container.
public enum SharedContainerSchema {
    /// The App Group identifier shared between the host app and extensions.
    public static let appGroupId = "group.com.gemscan"
    /// UserDefaults key for the path to the scam patterns bundle.
    public static let scamPatternsBundlePath = "gemscan.scamPatternsBundlePath"
    /// UserDefaults key for the user's preferred language code (BCP-47).
    public static let userLanguageCode = "gemscan.userLanguageCode"
    /// UserDefaults key for pending analysis tasks from extensions (array of dictionaries).
    public static let pendingAnalysisTasks = "gemscan.pendingAnalysisTasks"
    /// UserDefaults key for cached triage results (dictionary keyed by sender hash).
    public static let triageResultCache = "gemscan.triageResultCache"
    /// UserDefaults key for whether Guardian Mode is enabled.
    public static let guardianModeEnabled = "gemscan.guardianModeEnabled"
    /// UserDefaults key for the trusted contact identifier in Guardian Mode.
    public static let trustedContactId = "gemscan.trustedContactId"
    /// UserDefaults key for the last analysis timestamp (Unix ms).
    public static let lastAnalysisTimestamp = "gemscan.lastAnalysisTimestamp"
    /// UserDefaults key for the verdict history (array of encoded AgentResult).
    public static let verdictHistory = "gemscan.verdictHistory"
    /// UserDefaults key for the Safari content blocker list version string.
    public static let safariBlocklistVersion = "gemscan.safariBlocklistVersion"
}
