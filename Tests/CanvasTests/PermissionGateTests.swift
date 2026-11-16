import XCTest
@testable import Canvas

/// The gate the canvas asks before any work that needs one of its two permissions: a snapshot map
/// can't be drawn without Screen Recording, and no window can be driven without Accessibility.
final class PermissionGateTests: XCTestCase {
    func testNothingIsAllowedWithoutThePermissions() {
        let none = PermissionGate()
        for work in PermissionGate.Work.allCases {
            XCTAssertFalse(none.allows(work), "\(work)")
        }
    }

    func testScreenRecordingCarriesTheMapAndItsSnapshots() {
        let recording = PermissionGate(screenRecording: true)
        XCTAssertTrue(recording.allows(.map))
        XCTAssertTrue(recording.allows(.listWindows))
        XCTAssertTrue(recording.allows(.snapshot))
        XCTAssertFalse(recording.allows(.focus), "driving a window is Accessibility's business")
        XCTAssertFalse(recording.allows(.widgets))
    }

    func testAccessibilityCarriesFocusAndTheWidgetGallery() {
        let accessibility = PermissionGate(accessibility: true)
        XCTAssertTrue(accessibility.allows(.focus))
        XCTAssertTrue(accessibility.allows(.widgets))
        XCTAssertFalse(accessibility.allows(.map), "no map as snapshots without Screen Recording")
        XCTAssertFalse(accessibility.allows(.snapshot))
    }

    /// The wizard's order: Accessibility first, then Screen Recording, and nothing missing once both are on.
    func testTheMissingPageIsTheFirstPermissionInTheWizardsOrder() {
        XCTAssertEqual(PermissionGate().missingPage, .accessibility)
        XCTAssertEqual(PermissionGate(screenRecording: true).missingPage, .accessibility)
        XCTAssertEqual(PermissionGate(accessibility: true).missingPage, .screenRecording)
        XCTAssertNil(PermissionGate(accessibility: true, screenRecording: true).missingPage)
    }

    /// A grant that arrives after the canvas is up: the input and the capture both start.
    func testAGrantTurnsInputAndCaptureOn() {
        let before = PermissionGate()
        let after = PermissionGate(accessibility: true, screenRecording: true)
        let change = PermissionGate.Change(from: before, to: after)
        XCTAssertTrue(change.startInput)
        XCTAssertTrue(change.startCapture)
        XCTAssertFalse(change.stopInput)
        XCTAssertFalse(change.stopCapture)
        XCTAssertTrue(change.anything)
    }

    /// A permission taken away while the canvas is showing: both stop, and the map has to go.
    func testARevocationStopsWhatItCarried() {
        let before = PermissionGate(accessibility: true, screenRecording: true)
        let after = PermissionGate()
        let change = PermissionGate.Change(from: before, to: after)
        XCTAssertTrue(change.stopInput)
        XCTAssertTrue(change.stopCapture)
        XCTAssertFalse(change.startInput)
        XCTAssertFalse(change.startCapture)
        XCTAssertTrue(change.hideMap, "a map of stale snapshots with no way to refresh them isn't shown")
    }

    /// Losing Screen Recording alone stops the snapshots and takes the map away; the input stays.
    func testLosingScreenRecordingHidesTheMapButKeepsTheInput() {
        let change = PermissionGate.Change(from: PermissionGate(accessibility: true, screenRecording: true),
                                           to: PermissionGate(accessibility: true))
        XCTAssertTrue(change.stopCapture)
        XCTAssertTrue(change.hideMap)
        XCTAssertFalse(change.stopInput, "Accessibility is still granted")
    }

    /// Gaining Accessibility alone starts the input and leaves the capture alone.
    func testGainingAccessibilityStartsOnlyTheInput() {
        let change = PermissionGate.Change(from: PermissionGate(screenRecording: true),
                                           to: PermissionGate(accessibility: true, screenRecording: true))
        XCTAssertTrue(change.startInput)
        XCTAssertFalse(change.startCapture)
        XCTAssertFalse(change.anything == false)
    }

    func testNoChangeChangesNothing() {
        let same = PermissionGate(accessibility: true, screenRecording: true)
        let change = PermissionGate.Change(from: same, to: same)
        XCTAssertFalse(change.anything)
        XCTAssertFalse(change.hideMap)
    }
}
