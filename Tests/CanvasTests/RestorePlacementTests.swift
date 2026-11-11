import XCTest
import CoreGraphics
@testable import Canvas

/// Windows come back a few at a time, and the entries they are matched against are all known from the
/// start. Matching each batch on its own let the arrival order decide who got which place: two windows of
/// the same title, the second one arriving first, swapped. The whole picture is matched again whenever a
/// batch arrives, and what it disagrees with is corrected — except the windows the user has moved since
/// (#10 in the handoff).
@MainActor
final class RestorePlacementTests: XCTestCase {
    func testABatchIsPlacedByTheWholePicture() {
        let result = RestorePlacement.reconcile(kept: [:],
                                                pairing: [(entry: 101, window: 101), (entry: 102, window: 102)],
                                                pinned: [])
        XCTAssertEqual(result.moves, [101: 101, 102: 102])
        XCTAssertEqual(result.filled, [101, 102])
    }

    func testTheWindowThatArrivedFirstGivesUpThePlaceThatWasNotIts() {
        // 102 came first and took entry 101; 101 arrives, and the whole picture says otherwise.
        let result = RestorePlacement.reconcile(kept: [102: 101],
                                                pairing: [(entry: 101, window: 101), (entry: 102, window: 102)],
                                                pinned: [])
        XCTAssertEqual(result.moves, [101: 101, 102: 102], "both are corrected, not just the newcomer")
        XCTAssertEqual(result.filled, [101, 102])
    }

    func testAWindowAlreadyInTheRightPlaceIsNotTouched() {
        let result = RestorePlacement.reconcile(kept: [101: 101],
                                                pairing: [(entry: 101, window: 101)],
                                                pinned: [])
        XCTAssertTrue(result.moves.isEmpty, "nothing to move: the picture agrees")
        XCTAssertEqual(result.filled, [101])
    }

    func testAWindowTheUserHasMovedKeepsItsPlace() {
        let result = RestorePlacement.reconcile(kept: [102: 101],
                                                pairing: [(entry: 101, window: 101), (entry: 102, window: 102)],
                                                pinned: [102])
        XCTAssertFalse(result.moves.keys.contains(102), "the user's window is not moved back")
        XCTAssertEqual(result.filled, [101], "its place stays taken")
    }

    func testAFreedPlaceGoesBackToTheOpenOnes() {
        // A window that had entry 101 was closed while the restore was still running.
        let result = RestorePlacement.reconcile(kept: [:],
                                                pairing: [(entry: 102, window: 102)],
                                                pinned: [])
        XCTAssertEqual(result.moves, [102: 102])
        XCTAssertEqual(result.filled, [102], "101 is not filled, so it stays open for a window still coming")
    }

    func testAWindowIsStillWhereTheRestorePutIt() {
        XCTAssertFalse(RestorePlacement.userHasMoved(placedAt: CGPoint(x: 10, y: 10), now: CGPoint(x: 10.5, y: 10.5)))
        XCTAssertTrue(RestorePlacement.userHasMoved(placedAt: CGPoint(x: 10, y: 10), now: CGPoint(x: 10, y: 200)))
        XCTAssertFalse(RestorePlacement.userHasMoved(placedAt: nil, now: CGPoint(x: 10, y: 10)),
                       "never placed by the restore: nothing to compare with")
    }
}
