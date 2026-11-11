import XCTest
import CoreGraphics
@testable import Canvas

/// Hidden or asleep, the map's work stops — the listings, and the frames already on their way: a capture
/// started before the screen went away must not land in a proxy afterwards (#9 in the handoff).
final class LifecycleTests: XCTestCase {
    func testTheListingsRunWhileTheMapIsOnScreen() {
        XCTAssertTrue(CanvasController.mapWorkStaysOn(visible: true, asleep: false))
    }

    func testHiddenTheListingsStop() {
        XCTAssertFalse(CanvasController.mapWorkStaysOn(visible: false, asleep: false))
    }

    func testAsleepTheListingsStop() {
        XCTAssertFalse(CanvasController.mapWorkStaysOn(visible: true, asleep: true))
        XCTAssertFalse(CanvasController.mapWorkStaysOn(visible: false, asleep: true))
    }

    func testAFrameStartedInTheLifeItWasAskedForLands() {
        XCTAssertTrue(WindowProxy.acceptsCapture(startedIn: 7, current: 7))
    }

    func testAFrameFromBeforeTheScreenWentAwayIsDropped() {
        XCTAssertFalse(WindowProxy.acceptsCapture(startedIn: 7, current: 8))
    }
}
