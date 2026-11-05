import XCTest
@testable import OemerCore

final class PlaceholderTests: XCTestCase {
    func testPyRound() {
        XCTAssertEqual(pyRound(2.5), 2)
        XCTAssertEqual(pyRound(3.5), 4)
        XCTAssertEqual(pyRound(-2.5), -2)
    }
}
