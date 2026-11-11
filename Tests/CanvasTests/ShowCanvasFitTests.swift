import XCTest
import CoreGraphics
@testable import Canvas

/// Coming back from a window, the canvas flies to the camera it was entered from (`focusReturnCamera`) and
/// the real window is put back where it was. Fitting everything at the same moment sends the camera
/// somewhere else — the flight is cut, and the user lands on a picture they never made (#5 in the handoff).
final class ShowCanvasFitTests: XCTestCase {
    func testFittingEverythingIsWhatSummoningTheCanvasFromTheMapDoes() {
        XCTAssertTrue(CanvasController.showFitsAll(requested: true, returningToMap: false))
    }

    func testComingBackFromAWindowKeepsTheCameraItWasEnteredFrom() {
        XCTAssertFalse(CanvasController.showFitsAll(requested: true, returningToMap: true))
    }

    func testWhenNothingAsksForAFitNothingFits() {
        XCTAssertFalse(CanvasController.showFitsAll(requested: false, returningToMap: false))
        XCTAssertFalse(CanvasController.showFitsAll(requested: false, returningToMap: true))
    }
}
