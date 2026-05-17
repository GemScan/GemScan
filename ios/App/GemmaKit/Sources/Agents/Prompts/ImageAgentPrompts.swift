import Foundation

/// Prompt templates for the ``ImageAgent`` (screenshot and image analysis).
///
/// Image analysis is a two-stage pipeline:
/// 1. **OCR** — handled by Apple's `VNRecognizeTextRequest` in ``ImageOCR``.
///    No LLM prompt is involved at this stage.
/// 2. **Classification** — the OCR'd text is fed back through the same
///    text-classification path used for pasted SMS / email, using the
///    prompt built by ``classifyExtractedText(extractedText:)`` here. This
///    keeps reasoning + suggestion output identical regardless of whether
///    the user pasted text or uploaded a screenshot.
public enum ImageAgentPrompts {

    /// Builds the user prompt for classifying text that was OCR'd out of a
    /// screenshot. Mirrors ``TextAgentPrompts/classifySMS`` but flags that
    /// the content came from OCR so the model tolerates minor recognition
    /// errors (rn → m, 0 → O, etc.) when judging legitimacy.
    public static func classifyExtractedText(extractedText: String) -> String {
        """
        The text below was extracted via OCR from a screenshot the user wants checked. Treat it as a single message — it may contain minor OCR errors (e.g. "rn" read as "m", "0" as "O"). Do not penalise the message for those errors.

        <message>
        \(extractedText)
        </message>

        Analyse this content for scam, phishing, or social-engineering indicators (urgent demands, prize claims, suspicious URLs, requests for credentials / payment / one-time codes, brand impersonation, etc.).

        Produce your verdict as JSON with fields: verdict, confidence, reasoning, toolCalls, suggestion, detectedLanguage.
        - verdict: exactly one of "safe", "suspicious", "scam".
        - reasoning: 1-2 bullets quoting or paraphrasing the SPECIFIC visible content (sender, link, phrase) that drove the verdict. Never use generic category labels alone.
        """
    }
}
