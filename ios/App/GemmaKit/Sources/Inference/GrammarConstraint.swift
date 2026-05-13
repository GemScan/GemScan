import Foundation

// MARK: - GrammarConstraint

/// Represents a GBNF grammar that constrains model output to a specific format.
///
/// Grammar constraints are used by ``LlamaCppInferenceBackend`` at sampling time
/// to guarantee structured output, and by ``MLXInferenceBackend`` for post-hoc
/// validation.
public struct GrammarConstraint: Sendable {

    /// A human-readable name for this grammar (used in logging).
    public let name: String

    /// The raw GBNF grammar string.
    public let rawGBNF: String

    // MARK: - Initialization

    /// Creates a grammar constraint with the given name and GBNF definition.
    ///
    /// - Parameters:
    ///   - name: A descriptive name for logging purposes.
    ///   - rawGBNF: The GBNF grammar string.
    public init(name: String, rawGBNF: String) {
        self.name = name
        self.rawGBNF = rawGBNF
    }

    // MARK: - Factory Methods

    /// Grammar for the gem grading agent's JSON output.
    ///
    /// Expects output like: `{"color": "D", "clarity": "VS1", "cut": "Excellent", "carat": 1.25}`
    public static func gemGrading() -> GrammarConstraint {
        GrammarConstraint(
            name: "gem_grading",
            rawGBNF: """
            root    ::= "{" ws "\"color\"" ws ":" ws string ws "," ws "\"clarity\"" ws ":" ws string ws "," ws "\"cut\"" ws ":" ws string ws "," ws "\"carat\"" ws ":" ws number ws "}"
            string  ::= "\"" [a-zA-Z0-9]+ "\""
            number  ::= [0-9]+ ("." [0-9]+)?
            ws      ::= [ \\t\\n]*
            """
        )
    }

    /// Grammar for the image description agent's JSON output.
    ///
    /// Expects output like: `{"description": "A round brilliant diamond", "tags": ["diamond", "round"]}`
    public static func imageDescription() -> GrammarConstraint {
        GrammarConstraint(
            name: "image_description",
            rawGBNF: """
            root        ::= "{" ws "\"description\"" ws ":" ws string ws "," ws "\"tags\"" ws ":" ws array ws "}"
            string      ::= "\"" [^"]* "\""
            array       ::= "[" ws (string (ws "," ws string)*)? ws "]"
            ws          ::= [ \\t\\n]*
            """
        )
    }

    /// Grammar for the audio analysis agent's JSON output.
    ///
    /// Expects output like: `{"transcription": "hello world", "language": "en", "isSynthetic": false}`
    public static func audioAnalysis() -> GrammarConstraint {
        GrammarConstraint(
            name: "audio_analysis",
            rawGBNF: """
            root    ::= "{" ws "\"transcription\"" ws ":" ws string ws "," ws "\"language\"" ws ":" ws string ws "," ws "\"isSynthetic\"" ws ":" ws boolean ws "}"
            string  ::= "\"" [^"]* "\""
            boolean ::= "true" | "false"
            ws      ::= [ \\t\\n]*
            """
        )
    }

    /// Grammar for generic JSON object output.
    public static func genericJSON() -> GrammarConstraint {
        GrammarConstraint(
            name: "generic_json",
            rawGBNF: """
            root   ::= object
            object ::= "{" ws (pair (ws "," ws pair)*)? ws "}"
            pair   ::= string ws ":" ws value
            array  ::= "[" ws (value (ws "," ws value)*)? ws "]"
            value  ::= string | number | object | array | "true" | "false" | "null"
            string ::= "\"" [^"]* "\""
            number ::= "-"? [0-9]+ ("." [0-9]+)?
            ws     ::= [ \\t\\n]*
            """
        )
    }

    // MARK: - Validation

    /// Validates whether the given output string conforms to this grammar.
    ///
    /// This performs a best-effort heuristic check (e.g. verifying valid JSON
    /// structure) rather than a full GBNF parse.
    ///
    /// - Parameter output: The generated text to validate.
    /// - Returns: `true` if the output appears to conform to the grammar.
    public func validate(output: String) -> Bool {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)

        // Basic JSON structure check for all current grammars
        guard trimmed.hasPrefix("{"), trimmed.hasSuffix("}") else {
            return false
        }

        // Attempt to parse as JSON
        guard let data = trimmed.data(using: .utf8) else {
            return false
        }

        do {
            _ = try JSONSerialization.jsonObject(with: data, options: [])
            return true
        } catch {
            return false
        }
    }
}
