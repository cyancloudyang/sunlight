import XCTest
@testable import Canvas

@MainActor
final class KeyTapPassthroughTests: XCTestCase {
    /// A key the canvas posted itself (marked) goes straight on to the system: the Show Desktop
    /// shortcut it posts must not be caught here and re-triggered, which would loop.
    func testMarkedKeysPassThrough() {
        let mark = CanvasView.passedOnMark
        XCTAssertTrue(KeyTap.passesOn(userData: mark))
    }

    /// An ordinary key, unmarked, is the canvas's to intercept as ever.
    func testUnmarkedKeysAreTheCanvas() {
        let mark = CanvasView.passedOnMark
        XCTAssertFalse(KeyTap.passesOn(userData: 0))
        XCTAssertFalse(KeyTap.passesOn(userData: mark &+ 1))
    }
}