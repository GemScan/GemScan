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
    /// Human-readable reasoning bullets (2-3 items, sixth-grade reading level).
    public let reasoning: [String]
    /// Names of MCP tools that were invoked during analysis.
    public let toolCalls: [String]

    // MARK: - Initialization

    /// Creates a new parsed verdict with all fields.
    public init(
        verdict: ScamVerdict,
        confidence: Double,
        reasoning: [String],
        toolCalls: [String] = []
    ) {
        self.verdict = verdict
        self.confidence = confidence
        self.reasoning = reasoning
        self.toolCalls = toolCalls
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
    ///   "toolCalls": ["scam_patterns", "url_reputation"]
    /// }
    /// ```
    ///
    /// - Parameter jsonString: The raw JSON string from the model.
    /// - Returns: A fully populated ``ParsedVerdict``.
    /// - Throws: ``GemScanError/grammarViolation(raw:)`` if parsing fails.
    public static func parse(from jsonString: String) throws -> ParsedVerdict {
        guard let data = jsonString.data(using: .utf8) else {
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

        return ParsedVerdict(
            verdict: verdict,
            confidence: confidence,
            reasoning: reasoning,
            toolCalls: toolCalls
        )
    }
}
