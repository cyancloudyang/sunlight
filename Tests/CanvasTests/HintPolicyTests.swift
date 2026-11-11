import XCTest
@testable import Canvas

final class HintPolicyTests: XCTestCase {
    func testShowsForFirstFiveEntries() {
        for n in 0..<5 { XCTAssertTrue(HintPolicy.shows(mapEntriesSeen: n)) }
        XCTAssertFalse(HintPolicy.shows(mapEntriesSeen: 5))
        XCTAssertFalse(HintPolicy.shows(mapEntriesSeen: 50))
    }
}
