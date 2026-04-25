import Foundation
import os

/// Validates that agent-generated explanations meet a sixth-grade reading level.
///
/// Uses the Flesch-Kincaid Grade Level formula to compute readability.
/// Enforcement is soft: explanations that exceed the threshold are logged
/// as warnings but not rejected, ensuring the pipeline never drops a result
/// solely due to readability.
public struct ExplainerValidator {

    /// Maximum acceptable Flesch-Kincaid grade level.
    public static let gradeThreshold: Double = 6.0

    /// Logger for validation events.
    private static let logger = GemScanLogger.agents

    // MARK: - Public API

    /// Validates the readability of the given text.
    ///
    /// - Parameter text: The explanation text to validate.
    /// - Returns: A tuple of the computed grade level and whether it passes the threshold.
    public static func validate(text: String) -> (grade: Double, passes: Bool) {
        let grade = fleschKincaidGradeLevel(text: text)
        let passes = grade <= gradeThreshold

        if !passes {
            logger.warning(
                "Explanation exceeds grade-level threshold: \(String(format: "%.1f", grade)) > \(String(format: "%.1f", gradeThreshold))"
            )
        }

        return (grade: grade, passes: passes)
    }

    // MARK: - Flesch-Kincaid Computation

    /// Computes the Flesch-Kincaid Grade Level for the given text.
    ///
    /// Formula: 0.39 * (words / sentences) + 11.8 * (syllables / words) - 15.59
    ///
    /// - Parameter text: The input text.
    /// - Returns: The estimated US grade level. Lower values indicate simpler text.
    static func fleschKincaidGradeLevel(text: String) -> Double {
        let sentences = countSentences(in: text)
        let words = countWords(in: text)
        let syllables = countTotalSyllables(in: text)

        guard sentences > 0, words > 0 else {
            return 0.0
        }

        let wordsPerSentence = Double(words) / Double(sentences)
        let syllablesPerWord = Double(syllables) / Double(words)

        let grade = 0.39 * wordsPerSentence + 11.8 * syllablesPerWord - 15.59
        return max(0.0, grade)
    }

    /// Counts the number of sentences in the text.
    ///
    /// A sentence is delimited by `.`, `!`, or `?`.
    static func countSentences(in text: String) -> Int {
        let delimiters = CharacterSet(charactersIn: ".!?")
        let components = text.unicodeScalars.split { delimiters.contains($0) }
        let nonEmpty = components.filter { segment in
            segment.contains { !CharacterSet.whitespacesAndNewlines.contains($0) }
        }
        return max(1, nonEmpty.count)
    }

    /// Counts the number of words in the text.
    static func countWords(in text: String) -> Int {
        let words = text.split { $0.isWhitespace || $0.isNewline }
        return words.count
    }

    /// Counts total syllables across all words in the text.
    static func countTotalSyllables(in text: String) -> Int {
        let words = text.split { $0.isWhitespace || $0.isNewline }
        return words.reduce(0) { $0 + countSyllables(in: String($1)) }
    }

    /// Estimates the number of syllables in a single word.
    ///
    /// Uses a vowel-group heuristic with common English adjustments:
    /// - Silent trailing "e" is subtracted
    /// - Common suffixes like "le" after consonants add a syllable
    /// - Every word has at least one syllable
    static func countSyllables(in word: String) -> Int {
        let lowered = word.lowercased().filter { $0.isLetter }
        guard !lowered.isEmpty else { return 0 }

        let vowels: Set<Character> = ["a", "e", "i", "o", "u", "y"]
        var count = 0
        var previousWasVowel = false

        for char in lowered {
            let isVowel = vowels.contains(char)
            if isVowel, !previousWasVowel {
                count += 1
            }
            previousWasVowel = isVowel
        }

        // Silent trailing "e"
        if lowered.hasSuffix("e"), count > 1 {
            count -= 1
        }

        // Suffix "le" after a consonant adds a syllable (e.g. "table")
        if lowered.count >= 3, lowered.hasSuffix("le") {
            let index = lowered.index(lowered.endIndex, offsetBy: -3)
            let charBeforeLe = lowered[index]
            if !vowels.contains(charBeforeLe) {
                count += 1
            }
        }

        return max(1, count)
    }
}
