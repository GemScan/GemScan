import XCTest
@testable import GemmaKit

final class GemmaKitTests: XCTestCase {

    func testModelTierRawValues() {
        XCTAssertEqual(ModelTier.e2b.rawValue, "e2b")
    }

    func testModelTierExpectedRAM() {
        // E2B 4-bit working set is ~3.4 GB
        XCTAssertGreaterThan(ModelTier.e2b.expectedRAMBytes, 3_000_000_000)
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

    func testGemScanErrorDescriptions() {
        let error = GemScanError.thermalThrottled
        XCTAssertEqual(error.description, "Device is thermally throttled.")

        let memError = GemScanError.memoryPressure(currentBytes: 2_000_000_000, limitBytes: 1_500_000_000)
        XCTAssertTrue(memError.description.contains("2000"))
    }
}
