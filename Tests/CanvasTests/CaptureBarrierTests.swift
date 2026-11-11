import XCTest
import CoreGraphics
@testable import Canvas

/// The handoff resizes the real window and then puts it in front; the proxy's picture has to be of the new
/// size before that, or the app comes forward showing its old picture at 1:1 for a frame. The same on the
/// way back: the frame of the window as it was in use lands before the window is shrunk back, so the
/// restore can't photograph the size it is being put back to (#6 in the handoff).
@MainActor
final class CaptureBarrierTests: XCTestCase {
    func testWithAFrameToWaitForTheBarrierHoldsTheActivation() {
        var barrier = CaptureBarrier()
        XCTAssertEqual(barrier.begin(needed: true), .waitForFrame)
        XCTAssertTrue(barrier.isWaiting)
    }

    func testWithNothingToWaitForTheActivationGoesAtOnce() {
        var barrier = CaptureBarrier()
        XCTAssertEqual(barrier.begin(needed: false), .act)
        XCTAssertFalse(barrier.isWaiting)
    }

    func testTheBarrierWaitsOncePerHandoff() {
        var barrier = CaptureBarrier()
        XCTAssertEqual(barrier.begin(needed: true), .waitForFrame)
        XCTAssertEqual(barrier.begin(needed: true), .act, "a second ask doesn't queue another wait")
    }

    func testTheActivationRunsWhenTheFrameLands() {
        var barrier = CaptureBarrier()
        _ = barrier.begin(needed: true)
        XCTAssertEqual(barrier.frameLanded(), .act)
        XCTAssertFalse(barrier.isWaiting)
    }

    func testAFrameThatNeverComesStillLetsTheActivationRun() {
        // The window closed on the way, or its app never answered: the handoff can't wait for ever.
        var barrier = CaptureBarrier()
        _ = barrier.begin(needed: true)
        XCTAssertEqual(barrier.frameLanded(), .act)
        XCTAssertEqual(barrier.frameLanded(), .act, "and a late frame changes nothing")
    }
}
