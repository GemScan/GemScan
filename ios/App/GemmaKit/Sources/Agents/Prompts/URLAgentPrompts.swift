import Foundation

/// Prompt templates for the ``URLAgent`` (URL reputation and phishing checks).
///
/// All prompts are designed for grammar-constrained generation with Gemma models
/// and target a sixth-grade reading level for the reasoning field.
public enum URLAgentPrompts {

    /// System prompt establishing the URL agent's role and output contract.
    public static let system = """
    You are a URL safety agent that checks links for phishing, malware, and scam indicators.
    Your job is to decide whether a URL is safe, suspicious, or a scam.

    Rules:
    - Respond ONLY with valid JSON matching the required schema.
    - The "reasoning" array must contain 2-3 short bullet points.
    - Write reasoning at a sixth-grade reading level.
    - Consider domain age, WHOIS data, and reputation scores in your analysis.
    - Never visit or execute URLs; rely only on provided tool results.
    """

    /// Builds the user prompt for checking a URL.
    ///
    /// - Parameters:
    ///   - url: The URL string to analyse.
    ///   - reputationResult: Result from the url_reputation MCP tool.
    ///   - whoisResult: Result from the whois MCP tool.
    ///   - vectorResult: Result from the sqlite_vec similarity search.
    /// - Returns: The formatted user prompt string.
    public static func checkURL(
        url: String,
        reputationResult: String,
        whoisResult: String,
        vectorResult: String
    ) -> String {
        """
        Analyse this URL for phishing or scam indicators:

        <url>
        \(url)
        </url>

        URL reputation check:
        <url_reputation>
        \(reputationResult)
        </url_reputation>

        WHOIS lookup:
        <whois>
        \(whoisResult)
        </whois>

        Similar known scam patterns (vector search):
        <vector_matches>
        \(vectorResult)
        </vector_matches>

        Produce your verdict as JSON with fields: verdict, confidence, reasoning, toolCalls, domainAge, registrar.
        """
    }
}
