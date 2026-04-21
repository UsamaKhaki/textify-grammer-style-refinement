import XCTest
@testable import Textify

final class RefinedTripleTests: XCTestCase {
    func testDecodesFromJSON() throws {
        let json = #"{"casual":"hey","professional":"Hello","concise":"Hi"}"#
        let data = Data(json.utf8)
        let triple = try JSONDecoder().decode(RefinedTriple.self, from: data)
        XCTAssertEqual(triple.casual, "hey")
        XCTAssertEqual(triple.professional, "Hello")
        XCTAssertEqual(triple.concise, "Hi")
    }

    func testRejectsMissingField() {
        let json = #"{"casual":"hey","professional":"Hello"}"#
        let data = Data(json.utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(RefinedTriple.self, from: data))
    }
}
