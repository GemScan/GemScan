import XCTest
@testable import GemmaKit

final class GemmaKitTests: XCTestCase {

    func testModelTierRawValues() {
        XCTAssertEqual(ModelTier.e2b.rawValue, "e2b")
        XCTAssertEqual(ModelTier.distilbert.rawValue, "distilbert")
    }

    func testModelTierExpectedRAM() {
        XCTAssertGreaterThan(ModelTier.e2b.expectedRAMBytes, ModelTier.distilbert.expectedRAMBytes)
    }

    func testGrammarConstraintValidation() {
        let grammar = GrammarConstraint.genericJSON()
        XCTAssertTrue(grammar.validate(output: "{\"key\": \"value\"}"))
        XCTAssertFalse(grammar.validate(output: "not json"))
        XCTAssertFalse(grammar.validate(output: ""))
    }

    func testTokenStreamYieldsValues() async {
        let tokenStream = TokenStream()
        tokenStream.continuation.yield("hello")
        tokenStream.continuation.yield(" world")
        tokenStream.continuation.finish()

        var collected = ""
        for await token in tokenStream {
            collected += token
        }
        XCTAssertEqual(collected, "hello world")
    }

    func testTriageLabelRawValues() {
        XCTAssertEqual(TriageLabel.safe.rawValue, "safe")
        XCTAssertEqual(TriageLabel.junk.rawValue, "junk")
        XCTAssertEqual(TriageLabel.promotion.rawValue, "promotion")
    }

    func testGemScanErrorDescriptions() {
        let error = GemScanError.thermalThrottled
        XCTAssertEqual(error.description, "Device is thermally throttled.")

        let memError = GemScanError.memoryPressure(currentBytes: 2_000_000_000, limitBytes: 1_500_000_000)
        XCTAssertTrue(memError.description.contains("2000"))
    }
}
