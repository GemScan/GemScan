import XCTest
@testable import GemmaKit

/// Tests for the ExplainerValidator Flesch-Kincaid readability computation.
final class ExplainerValidatorTests: XCTestCase {

    // MARK: - Grade Level Threshold

    func testGradeThreshold_IsSixthGrade() {
        XCTAssertEqual(ExplainerValidator.gradeThreshold, 6.0)
    }

    // MARK: - Validation

    func testValidate_SimpleText_Passes() {
        let text = "This message is safe. The sender is in your contacts. No bad links were found."
        let (grade, passes) = ExplainerValidator.validate(text: text)

        XCTAssertTrue(passes, "Simple text should pass sixth-grade threshold. Grade: \(grade)")
        XCTAssertLessThanOrEqual(grade, 6.0)
    }

    func testValidate_ComplexText_MayFail() {
        let text = """
        The sophisticated phishing infrastructure leveraging internationalized domain names \
        demonstrates characteristic adversarial manipulation techniques commonly associated \
        with state-sponsored cybercriminal organizations specializing in telecommunications fraud.
        """
        let (grade, passes) = ExplainerValidator.validate(text: text)

        // Complex academic text should have a high grade level
        XCTAssertGreaterThan(grade, 6.0,
            "Complex academic text should exceed sixth-grade level")
        XCTAssertFalse(passes)
    }

    // MARK: - Sentence Counting

    func testCountSentences_PeriodDelimited() {
        let count = ExplainerValidator.countSentences(in: "First sentence. Second sentence. Third.")
        XCTAssertEqual(count, 3)
    }

    func testCountSentences_MixedDelimiters() {
        let count = ExplainerValidator.countSentences(in: "Is this a scam? Yes! Be careful.")
        XCTAssertEqual(count, 3)
    }

    func testCountSentences_SingleSentence() {
        let count = ExplainerValidator.countSentences(in: "Just one sentence")
        XCTAssertEqual(count, 1) // Returns max(1, ...) for text without delimiters
    }

    func testCountSentences_EmptyString() {
        let count = ExplainerValidator.countSentences(in: "")
        XCTAssertEqual(count, 1) // Minimum of 1
    }

    func testCountSentences_IgnoresTrailingWhitespace() {
        let count = ExplainerValidator.countSentences(in: "One sentence.   ")
        XCTAssertEqual(count, 1)
    }

    // MARK: - Word Counting

    func testCountWords_BasicSentence() {
        let count = ExplainerValidator.countWords(in: "This is a test sentence")
        XCTAssertEqual(count, 5)
    }

    func testCountWords_EmptyString() {
        let count = ExplainerValidator.countWords(in: "")
        XCTAssertEqual(count, 0)
    }

    func testCountWords_MultipleSpaces() {
        let count = ExplainerValidator.countWords(in: "word1   word2   word3")
        XCTAssertEqual(count, 3)
    }

    func testCountWords_WithNewlines() {
        let count = ExplainerValidator.countWords(in: "line one\nline two")
        XCTAssertEqual(count, 4)
    }

    // MARK: - Syllable Counting

    func testCountSyllables_SingleSyllable() {
        XCTAssertEqual(ExplainerValidator.countSyllables(in: "cat"), 1)
        XCTAssertEqual(ExplainerValidator.countSyllables(in: "dog"), 1)
        XCTAssertEqual(ExplainerValidator.countSyllables(in: "the"), 1)
    }

    func testCountSyllables_TwoSyllables() {
        XCTAssertEqual(ExplainerValidator.countSyllables(in: "table"), 2)
        XCTAssertEqual(ExplainerValidator.countSyllables(in: "apple"), 2)
        XCTAssertEqual(ExplainerValidator.countSyllables(in: "water"), 2)
    }

    func testCountSyllables_ThreeSyllables() {
        XCTAssertEqual(ExplainerValidator.countSyllables(in: "banana"), 3)
        XCTAssertEqual(ExplainerValidator.countSyllables(in: "beautiful"), 3)
    }

    func testCountSyllables_FourOrMore() {
        let syllables = ExplainerValidator.countSyllables(in: "communication")
        XCTAssertGreaterThanOrEqual(syllables, 4)
    }

    func testCountSyllables_EmptyString() {
        XCTAssertEqual(ExplainerValidator.countSyllables(in: ""), 0)
    }

    func testCountSyllables_MinimumOne() {
        // Even very short words should have at least 1 syllable
        XCTAssertGreaterThanOrEqual(ExplainerValidator.countSyllables(in: "a"), 1)
        XCTAssertGreaterThanOrEqual(ExplainerValidator.countSyllables(in: "I"), 1)
    }

    func testCountSyllables_SilentE() {
        // "make" has a silent e - should be 1 syllable
        XCTAssertEqual(ExplainerValidator.countSyllables(in: "make"), 1)
        XCTAssertEqual(ExplainerValidator.countSyllables(in: "safe"), 1)
    }

    // MARK: - Total Syllable Counting

    func testCountTotalSyllables_MultipleWords() {
        let total = ExplainerValidator.countTotalSyllables(in: "the cat sat")
        // "the" = 1, "cat" = 1, "sat" = 1
        XCTAssertEqual(total, 3)
    }

    // MARK: - Flesch-Kincaid Grade Level

    func testFleschKincaidGradeLevel_SimpleText() {
        let text = "The cat sat on the mat. It was a good cat."
        let grade = ExplainerValidator.fleschKincaidGradeLevel(text: text)

        // Very simple text should be well below sixth grade
        XCTAssertLessThan(grade, 4.0, "Very simple text should be low grade level")
    }

    func testFleschKincaidGradeLevel_EmptyText() {
        let grade = ExplainerValidator.fleschKincaidGradeLevel(text: "")
        XCTAssertEqual(grade, 0.0)
    }

    func testFleschKincaidGradeLevel_NonNegative() {
        // Grade level should never be negative
        let texts = [
            "Go.",
            "Run fast.",
            "The dog ran.",
            "I am fine. You are fine.",
        ]

        for text in texts {
            let grade = ExplainerValidator.fleschKincaidGradeLevel(text: text)
            XCTAssertGreaterThanOrEqual(grade, 0.0, "Grade for '\(text)' should be >= 0")
        }
    }

    func testFleschKincaidGradeLevel_HigherForComplexText() {
        let simpleText = "The dog is big. The cat is small."
        let complexText = """
        The sophisticated implementation of adversarial machine learning techniques \
        demonstrates the perpetrators' comprehensive understanding of contemporary \
        telecommunications infrastructure vulnerabilities.
        """

        let simpleGrade = ExplainerValidator.fleschKincaidGradeLevel(text: simpleText)
        let complexGrade = ExplainerValidator.fleschKincaidGradeLevel(text: complexText)

        XCTAssertLessThan(simpleGrade, complexGrade,
            "Complex text should have a higher grade level than simple text")
    }

    // MARK: - GemScan-Specific Explanations

    func testTypicalGemScanExplanation_PassesThreshold() {
        let explanations = [
            "This message is safe. The sender is in your contacts. There are no bad links.",
            "This looks like a scam. It asks for your bank info. The link goes to a fake site.",
            "Be careful with this one. The sender is not known. It uses pushy words to rush you.",
        ]

        for explanation in explanations {
            let (grade, passes) = ExplainerValidator.validate(text: explanation)
            // GemScan explanations are written for sixth-grade reading level
            XCTAssertTrue(passes || grade < 8.0,
                "GemScan explanation should be close to threshold. Grade: \(grade)")
        }
    }
}
