import Foundation

// GBNF root rules are intentionally kept as single lines to mirror the
// canonical grammar format that downstream parsers expect; splitting them
// across Swift source lines would not change the emitted grammar but would
// make the rule harder to compare against reference docs.
// swiftlint:disable line_length

/// GBNF grammar definitions for each agent's structured JSON output.
///
/// These grammars are fed to `LlamaCppInferenceBackend` at sampling time to
/// guarantee well-formed JSON, and used by `MLXInferenceBackend` for post-hoc
/// validation. Every agent's output must conform to the verdict schema:
/// `{ "verdict": ..., "confidence": ..., "reasoning": [...], "toolCalls": [...] }`
extension GrammarConstraint {

    // MARK: - Shared Verdict GBNF Fragment

    /// The shared GBNF rules for verdict, confidence, reasoning, and toolCalls.
    private static let verdictGBNF = """
    verdict    ::= "\"safe\"" | "\"suspicious\"" | "\"scam\""
    confidence ::= "0" "." [0-9]+  | "1" "." "0"+  | "0" | "1"
    reasoning  ::= "[" ws string (ws "," ws string)* ws "]"
    toolCalls  ::= "[" ws (string (ws "," ws string)*)? ws "]"
    string     ::= "\"" [^"]* "\""
    number     ::= [0-9]+ ("." [0-9]+)?
    ws         ::= [ \\t\\n]*
    """

    // MARK: - Agent Grammar Factories

    /// Grammar for ``TextAgent`` JSON output.
    ///
    /// Constrains the model to produce a verdict object with an optional
    /// `detectedLanguage` field for multilingual SMS/email analysis.
    public static func textAgentGrammar() -> GrammarConstraint {
        GrammarConstraint(
            name: "text_agent_verdict",
            rawGBNF: """
            root ::= "{" ws "\"verdict\"" ws ":" ws verdict ws "," ws "\"confidence\"" ws ":" ws confidence ws "," ws "\"reasoning\"" ws ":" ws reasoning ws "," ws "\"toolCalls\"" ws ":" ws toolCalls ws "," ws "\"detectedLanguage\"" ws ":" ws string ws "}"
            \(verdictGBNF)
            """
        )
    }

    /// Grammar for ``URLAgent`` JSON output.
    ///
    /// Constrains the model to produce a verdict with `domainAge` and
    /// `registrar` metadata extracted from WHOIS lookups.
    public static func urlAgentGrammar() -> GrammarConstraint {
        GrammarConstraint(
            name: "url_agent_verdict",
            rawGBNF: """
            root ::= "{" ws "\"verdict\"" ws ":" ws verdict ws "," ws "\"confidence\"" ws ":" ws confidence ws "," ws "\"reasoning\"" ws ":" ws reasoning ws "," ws "\"toolCalls\"" ws ":" ws toolCalls ws "," ws "\"domainAge\"" ws ":" ws number ws "," ws "\"registrar\"" ws ":" ws string ws "}"
            \(verdictGBNF)
            """
        )
    }

    /// Grammar for ``ImageAgent`` JSON output.
    ///
    /// Constrains the model to produce a verdict with `ocrText` containing
    /// any text extracted from the screenshot via OCR.
    public static func imageAgentGrammar() -> GrammarConstraint {
        GrammarConstraint(
            name: "image_agent_verdict",
            rawGBNF: """
            root ::= "{" ws "\"verdict\"" ws ":" ws verdict ws "," ws "\"confidence\"" ws ":" ws confidence ws "," ws "\"reasoning\"" ws ":" ws reasoning ws "," ws "\"toolCalls\"" ws ":" ws toolCalls ws "," ws "\"ocrText\"" ws ":" ws string ws "}"
            \(verdictGBNF)
            """
        )
    }

}

// swiftlint:enable line_length
