import Foundation

/// Prompt templates for the ``VoiceAgent`` (voice call analysis).
///
/// All prompts are designed for grammar-constrained generation with Gemma models
/// and target a sixth-grade reading level for the reasoning field.
public enum VoiceAgentPrompts {

    /// System prompt establishing the voice agent's role and output contract.
    public static let system = """
    You are a voice call analysis agent that detects scam phone calls.
    You receive a transcription from Whisper ASR and deepfake detection results
    from AudioSeal.

    Rules:
    - Respond ONLY with valid JSON matching the required schema.
    - The "reasoning" array must contain 2-3 short bullet points.
    - Write reasoning at a sixth-grade reading level.
    - Consider both the transcript content and the deepfake probability.
    - Synthetic voice with scam content is very high risk.
    - Never include phone numbers or personal information in your output.
    """

    /// Builds the user prompt for scoring a voice call.
    ///
    /// - Parameters:
    ///   - transcript: The Whisper ASR transcription of the audio.
    ///   - language: Detected language of the audio.
    ///   - deepfakeProbability: AudioSeal synthesis probability (0.0 = human, 1.0 = AI).
    ///   - deepfakeClassification: Human-readable classification from AudioSeal.
    ///   - phoneReputation: Result from the phone_reputation MCP tool.
    ///   - vectorResult: Result from the sqlite_vec similarity search.
    /// - Returns: The formatted user prompt string.
    public static func scoreVoice(
        transcript: String,
        language: String,
        deepfakeProbability: Double,
        deepfakeClassification: String,
        phoneReputation: String,
        vectorResult: String
    ) -> String {
        """
        Analyse this voice call for scam indicators.

        Transcription (language: \(language)):
        <transcript>
        \(transcript)
        </transcript>

        Deepfake detection:
        - Synthesis probability: \(String(format: "%.4f", deepfakeProbability))
        - Classification: \(deepfakeClassification)

        Phone number reputation:
        <phone_reputation>
        \(phoneReputation)
        </phone_reputation>

        Similar known scam patterns (vector search):
        <vector_matches>
        \(vectorResult)
        </vector_matches>

        Produce your verdict as JSON with fields: verdict, confidence, reasoning, toolCalls, isSynthetic, transcriptSnippet.
        """
    }
}
