import Foundation

/// Prompt templates for the ``JudgeAgent`` (PhishDebate adjudication).
///
/// The judge uses a three-pass debate pattern: defence counsel argues
/// the message is safe, prosecution rebuts, then the judge renders a
/// final verdict. All prompts target Gemma E4B.
public enum JudgeAgentPrompts {

    /// System prompt establishing the judge agent's role and output contract.
    public static let system = """
    You are an impartial judge agent that adjudicates disputed scam verdicts.
    You receive conflicting assessments from specialist agents and must render
    a final, well-reasoned verdict using the PhishDebate pattern.

    Rules:
    - Respond ONLY with valid JSON matching the required schema.
    - The "reasoning" array must contain 2-3 short bullet points.
    - Write reasoning at a sixth-grade reading level.
    - Consider both defence and prosecution arguments fairly.
    - Your verdict is final and cannot be appealed.
    """

    /// Builds the defence counsel prompt (Pass 1 of PhishDebate).
    ///
    /// - Parameters:
    ///   - originalContent: Summary of the original message/URL/image.
    ///   - agentResults: Formatted specialist agent results.
    ///   - scamPatterns: Matching scam patterns from the database.
    /// - Returns: The formatted defence prompt string.
    public static func defenceCounsel(
        originalContent: String,
        agentResults: String,
        scamPatterns: String
    ) -> String {
        """
        You are the DEFENCE COUNSEL. Argue why this content is SAFE and not a scam.
        Consider innocent explanations for any suspicious indicators.

        Original content summary:
        <content>
        \(originalContent)
        </content>

        Specialist agent assessments:
        <agent_results>
        \(agentResults)
        </agent_results>

        Known scam patterns for reference:
        <scam_patterns>
        \(scamPatterns)
        </scam_patterns>

        Present your defence arguments as a JSON array of strings.
        """
    }

    /// Builds the prosecution rebuttal prompt (Pass 2 of PhishDebate).
    ///
    /// - Parameters:
    ///   - originalContent: Summary of the original message/URL/image.
    ///   - defenceArguments: Arguments produced by the defence counsel pass.
    ///   - agentResults: Formatted specialist agent results.
    ///   - scamPatterns: Matching scam patterns from the database.
    /// - Returns: The formatted prosecution prompt string.
    public static func prosecutionRebuttal(
        originalContent: String,
        defenceArguments: String,
        agentResults: String,
        scamPatterns: String
    ) -> String {
        """
        You are the PROSECUTION. Rebut the defence's arguments and explain why
        this content IS a scam or is suspicious.

        Original content summary:
        <content>
        \(originalContent)
        </content>

        Defence arguments:
        <defence>
        \(defenceArguments)
        </defence>

        Specialist agent assessments:
        <agent_results>
        \(agentResults)
        </agent_results>

        Known scam patterns for reference:
        <scam_patterns>
        \(scamPatterns)
        </scam_patterns>

        Present your prosecution arguments as a JSON array of strings.
        """
    }

    /// Builds the final verdict prompt (Pass 3 of PhishDebate).
    ///
    /// - Parameters:
    ///   - originalContent: Summary of the original message/URL/image.
    ///   - defenceArguments: Arguments from the defence counsel.
    ///   - prosecutionArguments: Arguments from the prosecution rebuttal.
    ///   - vectorResult: Similar known scam patterns from vector search.
    /// - Returns: The formatted final verdict prompt string.
    public static func finalVerdict(
        originalContent: String,
        defenceArguments: String,
        prosecutionArguments: String,
        vectorResult: String
    ) -> String {
        """
        You are the JUDGE. After hearing both sides, render your final verdict.

        Original content summary:
        <content>
        \(originalContent)
        </content>

        Defence arguments:
        <defence>
        \(defenceArguments)
        </defence>

        Prosecution arguments:
        <prosecution>
        \(prosecutionArguments)
        </prosecution>

        Similar known scam patterns (vector search):
        <vector_matches>
        \(vectorResult)
        </vector_matches>

        Produce your final verdict as JSON with fields: verdict, confidence, reasoning, toolCalls, defenceArguments, prosecutionArguments.
        """
    }
}
