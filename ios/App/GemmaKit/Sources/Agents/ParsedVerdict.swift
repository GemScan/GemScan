import Foundation

/// A structured verdict parsed from grammar-constrained LLM JSON output.
///
/// Each agent's generation pass produces a JSON string that conforms to a
/// GBNF grammar. `ParsedVerdict` is the Swift-side representation of that
/// output, providing a type-safe bridge between raw model text and the
/// ``AgentResult`` that flows back through the pipeline.
public struct ParsedVerdict: Sendable {
    /// The scam classification verdict.
    public let verdict: ScamVerdict
    /// Confidence score in the range [0.0, 1.0].
    public let confidence: Double
    /// Short explanation as 1-2 bullets, total under 25 words combined.
    public let reasoning: [String]
    /// Names of MCP tools that were invoked during analysis.
    public let toolCalls: [String]
    /// Actionable user guidance (40-60 words). Empty string if the model
    /// omitted the field — older grammars did not require it.
    public let suggestion: String

    // MARK: - Initialization

    /// Creates a new parsed verdict with all fields.
    public init(
        verdict: ScamVerdict,
        confidence: Double,
        reasoning: [String],
        toolCalls: [String] = [],
        suggestion: String = ""
    ) {
        self.verdict = verdict
        self.confidence = confidence
        self.reasoning = reasoning
        self.toolCalls = toolCalls
        self.suggestion = suggestion
    }

    // MARK: - Factory

    /// Parses a grammar-constrained JSON string into a ``ParsedVerdict``.
    ///
    /// Expected JSON shape:
    /// ```json
    /// {
    ///   "verdict": "safe" | "suspicious" | "scam",
    ///   "confidence": 0.95,
    ///   "reasoning": ["Reason one.", "Reason two."],
    ///   "toolCalls": ["scam_patterns", "url_reputation"],
    ///   "suggestion": "What the user should do next."
    /// }
    /// ```
    ///
    /// The MLX backend doesn't enforce GBNF at sampling time (only llama.cpp
    /// does), so the model occasionally wraps the JSON in markdown fences or
    /// adds explanatory prose. We strip that by finding the first `{` and the
    /// matching last `}` in the raw output before attempting to parse.
    ///
    /// - Parameter jsonString: The raw JSON string from the model.
    /// - Returns: A fully populated ``ParsedVerdict``.
    /// - Throws: ``GemScanError/grammarViolation(raw:)`` if parsing fails.
    public static func parse(from jsonString: String) throws -> ParsedVerdict {
        let extracted = Self.extractJSONObject(from: jsonString)
        guard let data = extracted.data(using: .utf8) else {
            throw GemScanError.grammarViolation(raw: jsonString)
        }

        let parsed: [String: Any]
        do {
            guard let dict = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                throw GemScanError.grammarViolation(raw: jsonString)
            }
            parsed = dict
        } catch {
            throw GemScanError.grammarViolation(raw: jsonString)
        }

        guard let verdictRaw = parsed["verdict"] as? String,
              let verdict = ScamVerdict(rawValue: verdictRaw) else {
            throw GemScanError.grammarViolation(raw: jsonString)
        }

        guard let confidence = parsed["confidence"] as? Double else {
            throw GemScanError.grammarViolation(raw: jsonString)
        }

        guard let reasoning = parsed["reasoning"] as? [String] else {
            throw GemScanError.grammarViolation(raw: jsonString)
        }

        let toolCalls = parsed["toolCalls"] as? [String] ?? []
        let suggestion = parsed["suggestion"] as? String ?? ""

        return ParsedVerdict(
            verdict: verdict,
            confidence: confidence,
            reasoning: reasoning,
            toolCalls: toolCalls,
            suggestion: suggestion
        )
    }

    /// Returns the substring from the first `{` to the matching last `}` in
    /// `raw`, trimmed of surrounding whitespace. If no braces are found we
    /// return the trimmed input verbatim so `JSONSerialization` can raise a
    /// precise error.
    ///
    /// This is intentionally permissive — it lets us tolerate markdown
    /// fences (```json … ```), leading prose ("Here is the result:"), and
    /// trailing chatter that some chat-tuned models add despite a
    /// JSON-only instruction.
    private static func extractJSONObject(from raw: String) -> String {
        if let first = raw.firstIndex(of: "{"),
           let last = raw.lastIndex(of: "}"),
           first <= last {
            return String(raw[first...last])
        }
        return raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
