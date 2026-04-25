import Foundation

/// Prompt templates for the ``ImageAgent`` (screenshot and image analysis).
///
/// All prompts are designed for grammar-constrained generation with Gemma E4B
/// (multimodal vision) and target a sixth-grade reading level for reasoning.
public enum ImageAgentPrompts {

    /// System prompt establishing the image agent's role and output contract.
    public static let system = """
    You are a screenshot analysis agent that detects scam content in images.
    You can see the image directly and also receive OCR-extracted text and URLs.

    Rules:
    - Respond ONLY with valid JSON matching the required schema.
    - The "reasoning" array must contain 2-3 short bullet points.
    - Write reasoning at a sixth-grade reading level.
    - Look for fake login pages, urgent warnings, prize claims, and impersonation.
    - Cross-reference extracted URLs with reputation data.
    - Never include personal information visible in screenshots in your output.
    """

    /// Builds the user prompt for analysing a screenshot.
    ///
    /// - Parameters:
    ///   - ocrText: Text extracted from the image via reverse_image/extract_text_urls.
    ///   - extractedURLs: URLs found in the image OCR output.
    ///   - reputationResult: URL reputation results for extracted URLs.
    ///   - vectorResult: Result from the sqlite_vec similarity search.
    /// - Returns: The formatted user prompt string.
    public static func analyseScreenshot(
        ocrText: String,
        extractedURLs: [String],
        reputationResult: String,
        vectorResult: String
    ) -> String {
        let urlList = extractedURLs.isEmpty
            ? "No URLs found in image."
            : extractedURLs.map { "- \($0)" }.joined(separator: "\n")

        return """
        Analyse this screenshot for scam indicators. The image is provided as a vision input.

        OCR-extracted text:
        <ocr_text>
        \(ocrText)
        </ocr_text>

        URLs found in image:
        <extracted_urls>
        \(urlList)
        </extracted_urls>

        URL reputation results:
        <url_reputation>
        \(reputationResult)
        </url_reputation>

        Similar known scam patterns (vector search):
        <vector_matches>
        \(vectorResult)
        </vector_matches>

        Produce your verdict as JSON with fields: verdict, confidence, reasoning, toolCalls, ocrText.
        """
    }
}
