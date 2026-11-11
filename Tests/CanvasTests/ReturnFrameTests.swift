import XCTest
import CoreGraphics
@testable import Canvas

final class ReturnFrameTests: XCTestCase {
    func testARealListingFrameIsUsed() {
        let f = CGRect(x: 10, y: 20, width: 800, height: 600)
        XCTAssertEqual(ReturnFrame.fromListing(f), f)
    }

    func testNoListingEntryFallsBackToAccessibility() {
        XCTAssertNil(ReturnFrame.fromListing(nil))
    }

    func testAnEmptyListingFrameFallsBackToAccessibility() {
        XCTAssertNil(ReturnFrame.fromListing(CGRect(x: 10, y: 20, width: 0, height: 0)))
        XCTAssertNil(ReturnFrame.fromListing(CGRect(x: 0, y: 0, width: 0.5, height: 600)))
        XCTAssertNil(ReturnFrame.fromListing(CGRect(x: 0, y: 0, width: 800, height: 0.5)))
    }
}