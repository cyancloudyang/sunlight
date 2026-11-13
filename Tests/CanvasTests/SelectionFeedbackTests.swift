import XCTest
@testable import Canvas

/// The selection ring's geometry: a constant outset around the window's frame.
final class SelectionFeedbackTests: XCTestCase {
    func testRingRectInsetsOutward() {
        let r = CGRect(x: 10, y: 20, width: 100, height: 50)
        XCTAssertEqual(SelectionFeedback.ringRect(for: r), CGRect(x: 4, y: 14, width: 112, height: 62))
    }
}