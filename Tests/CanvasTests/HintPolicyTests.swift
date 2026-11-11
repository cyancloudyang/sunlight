import XCTest
@testable import Canvas

final class HintPolicyTests: XCTestCase {
    func testAlwaysShowsRegardlessOfEntriesSeen() {
        for n in [0, 1, 4, 5, 50, 1000] { XCTAssertTrue(HintPolicy.shows(mapEntriesSeen: n)) }
    }
}
