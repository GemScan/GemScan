import Foundation

/// Prompt templates for the ``TextAgent`` (SMS and email classification).
///
/// All prompts are designed for grammar-constrained generation with Gemma models
/// and target a sixth-grade reading level for the reasoning field.
public enum TextAgentPrompts {

    /// System prompt establishing the text agent's role and output contract.
    public static let system = """
    You are a scam detection agent that analyses SMS messages and emails.
    Your job is to decide whether a message is safe, suspicious, or a scam.

    Rules:
    - Respond ONLY with valid JSON matching the required schema.
    - The "reasoning" array must contain 2-3 short bullet points.
    - Write reasoning at a sixth-grade reading level.
    - Never include personal information in your output.
    - If the message language is not English, still classify it and note the language.
    """

    /// Builds the user prompt for classifying an SMS message.
    ///
    /// - Parameters:
    ///   - messageContent: The SMS text content to classify.
    ///   - toolResults: Formatted string of MCP tool call results.
    ///   - language: Optional BCP-47 language hint.
    /// - Returns: The formatted user prompt string.
    public static func classifySMS(
        messageContent: String,
        toolResults: String,
        language: String?
    ) -> String {
        let languageHint = language.map { "Message language hint: \($0)\n" } ?? ""
        return """
        \(languageHint)Analyse this SMS message for scam indicators:

        <message>
        \(messageContent)
        </message>

        Tool results from prior checks:
        <tool_results>
        \(toolResults)
        </tool_results>

        Produce your verdict as JSON with fields: verdict, confidence, reasoning, toolCalls, detectedLanguage.
        """
    }

    /// Builds the user prompt for classifying an email.
    ///
    /// - Parameters:
    ///   - emailContent: The email body text to classify.
    ///   - toolResults: Formatted string of MCP tool call results.
    ///   - language: Optional BCP-47 language hint.
    /// - Returns: The formatted user prompt string.
    public static func classifyEmail(
        emailContent: String,
        toolResults: String,
        language: String?
    ) -> String {
        let languageHint = language.map { "Email language hint: \($0)\n" } ?? ""
        return """
        \(languageHint)Analyse this email for scam, phishing, or social engineering indicators:

        <email>
        \(emailContent)
        </email>

        Tool results from prior checks:
        <tool_results>
        \(toolResults)
        </tool_results>

        Produce your verdict as JSON with fields: verdict, confidence, reasoning, toolCalls, detectedLanguage.
        """
    }
}
