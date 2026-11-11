import XCTest
@testable import Canvas

/// Entering a window: where it sits on screen at 1:1 and the camera that puts it there; and a
/// window's native place for any camera, the one answer the seam, kept windows and siblings share.
final class HandoffTests: XCTestCase {
    /// A 2000×1200 display with a 38 pt menu bar, view coordinates.
    private let visible = CGRect(x: 0, y: 38, width: 2000, height: 1162)
    private let scale: CGFloat = 2
    private let window = CGRect(x: 3000, y: 2000, width: 800, height: 600)

    private func plan(_ placement: Handoff.Placement, rect: CGRect? = nil, camera: Camera = Camera(origin: CGPoint(x: 2500, y: 1500), zoom: 0.5),
                      tiledArea: CGRect? = nil) -> Handoff.Plan {
        Handoff.plan(placement, rect: rect ?? window, camera: camera, visible: visible, scale: scale, tiledArea: tiledArea)
    }

    // MARK: Where the window goes

    func testCentredPutsTheWindowInTheMiddleOfTheVisibleArea() {
        let p = plan(.centered)
        XCTAssertEqual(p.origin, CGPoint(x: 600, y: 319))
        XCTAssertNil(p.inPlace)
        XCTAssertFalse(p.clicked)
    }

    func testAWindowBiggerThanTheScreenStartsAtTheTopLeft() {
        let p = plan(.centered, rect: CGRect(x: 0, y: 0, width: 2400, height: 1400))
        XCTAssertEqual(p.origin, CGPoint(x: 0, y: 38))
    }

    func testInPlaceKeepsTheTitleBarWhereItIsAndThePointUnderThePointer() {
        // At zoom 0.5 from (2500, 1500) the window's top-left is on screen at (250, 250).
        let point = CGPoint(x: 300, y: 400)   // on the proxy, 50 screen points in from its left edge
        let p = plan(.inPlace(around: point))
        // Grown to 1:1, the point's world x (3100) stays under the pointer: origin.x = 300 − 100.
        XCTAssertEqual(p.origin, CGPoint(x: 200, y: 250))
        XCTAssertNotNil(p.inPlace)
        XCTAssertFalse(p.clicked)
    }

    func testAClickKeepsTheClickedSpotUnderThePointer() {
        let p = plan(.clicked(at: CGPoint(x: 1000, y: 700), offset: CGPoint(x: 100, y: 50)))
        XCTAssertEqual(p.origin, CGPoint(x: 900, y: 650))
        XCTAssertEqual(p.inPlaceOrigin, p.origin)
        XCTAssertTrue(p.clicked)
        XCTAssertNotNil(p.inPlace)
    }

    func testAClickNearTheTopLandsTheWindowUnderTheMenuBarAndRemembersWhereItWasAsked() {
        // The clicked spot is 50 pt into the window, 20 pt from the top of the screen: the window's top
        // would be above the menu bar, so it lands right under it, and the plan keeps where it was asked.
        let p = plan(.clicked(at: CGPoint(x: 1000, y: 20), offset: CGPoint(x: 100, y: 50)))
        XCTAssertEqual(p.origin, CGPoint(x: 900, y: 38))
        XCTAssertEqual(p.inPlaceOrigin, CGPoint(x: 900, y: -30))
        XCTAssertEqual(p.inPlace, Camera(origin: CGPoint(x: 2100, y: 2030), zoom: 1))
        XCTAssertEqual(p.camera, Camera(origin: CGPoint(x: 2100, y: 1962), zoom: 1))
    }

    func testATiledWindowLinesUpWithItsArea() {
        // Tiled to the right half of an area that starts at (2800, 1900): the window's offset in it is (200, 100).
        let p = plan(.centered, tiledArea: CGRect(x: 2800, y: 1900, width: 1600, height: 1100))
        XCTAssertEqual(p.origin, CGPoint(x: 200, y: 138))
        XCTAssertNotNil(p.inPlace, "a tiled window keeps its place in its area")
    }

    // MARK: Filling the screen

    func testFillScreenPlanUsesVisibleFrame() {
        let visible = CGRect(x: 0, y: 25, width: 1440, height: 875)
        let rect = CGRect(x: 2000, y: -1500, width: 900, height: 600)
        let plan = Handoff.plan(.fillScreen, rect: rect, camera: Camera(), visible: visible,
                                scale: 1, tiledArea: visible)
        XCTAssertEqual(plan.origin, visible.origin)  // pixelAligned 后仍重合
        // 相机把 worldRect 中心对准屏幕中心
        XCTAssertEqual(plan.camera.center(viewSize: visible.size).x, rect.midX, accuracy: 1)
        XCTAssertEqual(plan.camera.center(viewSize: visible.size).y, rect.midY, accuracy: 1)
    }

    func testOutcomeAbortsWhenWindowGone() {
        XCTAssertEqual(Handoff.outcome(windowAlive: false), .abortedWindowGone)
        XCTAssertEqual(Handoff.outcome(windowAlive: true), .completed)
    }

    func testSeamUsesActualFrameNotRequested() {
        let requested = CGRect(x: 0, y: 25, width: 1440, height: 875)
        let clamped = CGRect(x: 0, y: 25, width: 1024, height: 640)
        XCTAssertEqual(Handoff.seamRect(actualFrame: clamped, requested: requested), clamped)
    }

    func testFlightRectClampsAtTheEnds() {
        let from = CGRect(x: 0, y: 0, width: 100, height: 50)
        let to = CGRect(x: 100, y: 100, width: 200, height: 100)
        XCTAssertEqual(Handoff.flightRect(from: from, to: to, at: 0), from)
        XCTAssertEqual(Handoff.flightRect(from: from, to: to, at: 1), to)
        XCTAssertEqual(Handoff.flightRect(from: from, to: to, at: 0.5), CGRect(x: 50, y: 50, width: 150, height: 75))
        XCTAssertEqual(Handoff.flightRect(from: from, to: to, at: 1.1), to, "the spring overshoots; the rect must not breathe past full")
        XCTAssertEqual(Handoff.flightRect(from: from, to: to, at: -0.1), from)
    }

    // MARK: The camera

    func testTheCameraShowsTheWindowAtItsOrigin() {
        for placement: Handoff.Placement in [.centered, .inPlace(around: CGPoint(x: 300, y: 400)), .clicked(at: CGPoint(x: 1000, y: 700), offset: CGPoint(x: 100, y: 50))] {
            let p = plan(placement)
            XCTAssertEqual(p.camera.zoom, 1)
            let shown = p.camera.toScreen(window.origin)
            XCTAssertEqual(shown.x, p.origin.x, accuracy: 1e-9)
            XCTAssertEqual(shown.y, p.origin.y, accuracy: 1e-9)
        }
    }

    func testTheOriginIsOnThePixelGrid() {
        let p = plan(.inPlace(around: CGPoint(x: 300.3, y: 400.7)), camera: Camera(origin: CGPoint(x: 2500.37, y: 1500.11), zoom: 0.5))
        XCTAssertEqual((p.origin.x * scale).rounded(), p.origin.x * scale)
        XCTAssertEqual((p.origin.y * scale).rounded(), p.origin.y * scale)
    }

    func testNoWindowGoesAboveTheMenuBar() {
        // Clicked near the top: the window's top would be above the menu bar.
        let p = plan(.clicked(at: CGPoint(x: 1000, y: 10), offset: CGPoint(x: 100, y: 50)))
        XCTAssertEqual(p.origin.y, 38)
        // In place, the camera it would have ended at, before the menu bar had its say.
        XCTAssertEqual(p.inPlace?.toScreen(window.origin).y, -40)
        XCTAssertEqual(p.camera.toScreen(window.origin).y, 38)
    }

    // MARK: A window's native place

    func testTheNativePlaceIsTheCanvasPlaceThroughTheCameraToThePixel() {
        let camera = Camera(origin: CGPoint(x: 2500.3, y: 1500), zoom: 1)
        let origin = Handoff.nativeOrigin(of: CGPoint(x: 3000, y: 2000), at: camera, scale: 2, top: 38)
        XCTAssertEqual(origin, CGPoint(x: 499.5, y: 500))
    }

    func testTheNativePlaceStaysBelowTheMenuBar() {
        let camera = Camera(origin: CGPoint(x: 0, y: 2000), zoom: 1)
        XCTAssertEqual(Handoff.nativeOrigin(of: CGPoint(x: 100, y: 1990), at: camera, scale: 2, top: 38), CGPoint(x: 100, y: 38))
    }

    func testTheSeamAndTheNativePlaceAgree() {
        // What the seam commits (`plan.origin`) is where `nativeOrigin` says the window sits at the plan's camera.
        for placement: Handoff.Placement in [.centered, .inPlace(around: CGPoint(x: 300, y: 400)), .clicked(at: CGPoint(x: 1000, y: 10), offset: CGPoint(x: 100, y: 50))] {
            let p = plan(placement)
            XCTAssertEqual(Handoff.nativeOrigin(of: window.origin, at: p.camera, scale: scale, top: visible.minY), p.origin)
        }
    }

    func testTheAligningCameraPutsTheProxyOverTheRealWindow() {
        let camera = Handoff.cameraAligning(window, with: CGRect(x: 600, y: 319, width: 800, height: 600))
        XCTAssertEqual(camera.toScreen(window.origin), CGPoint(x: 600, y: 319))
        XCTAssertEqual(camera.zoom, 1)
    }

    func testTheFixingCameraKeepsThePointUnderThePointerAtOneToOne() {
        let camera = Camera(origin: CGPoint(x: 2500, y: 1500), zoom: 0.5)
        let point = CGPoint(x: 700, y: 400)
        let fixing = Handoff.cameraFixing(point, at: camera)
        XCTAssertEqual(fixing.zoom, 1)
        XCTAssertEqual(fixing.toWorld(point), camera.toWorld(point))
        // The window drawn at (250, 250) 400×300 at the half zoom: the pointer is 450 pt in, 150 pt down
        // on it; at 1:1 its real frame starts 900 pt left and 300 pt up of the pointer.
        XCTAssertEqual(fixing.toScreen(window.origin), CGPoint(x: -200, y: 100))
    }

    func testACameraSeenFromGlobalAndBack() {
        let view = Camera(origin: CGPoint(x: 100, y: 200), zoom: 0.5)
        let display = CGPoint(x: -2000, y: 300)
        let global = view.global(viewOrigin: display)
        XCTAssertEqual(global.inView(viewOrigin: display), view)
        XCTAssertEqual(global.toScreen(CGPoint(x: 100, y: 200)), display, "the view's top-left is the display's origin")
    }
}

/// Entering a window leaves the map behind it: an opaque canvas is still on the screen around a window
/// that doesn't fill it — a fixed-size one, or one Accessibility clamps — unless it's taken off (#3).
/// `hideMapForForeignFront` can't be the one to do it: it wants no `activeProxy`, and an entered window
/// has one.
final class MapStepsAsideTests: XCTestCase {
    func testTheMapStepsOffOnceAWindowIsInFront() {
        XCTAssertTrue(CanvasController.mapStepsAside(entered: true, staysUp: false, paused: false,
                                                      otherWork: false, visible: true))
    }

    func testTheMapStaysUpForAnotherDisplay() {
        XCTAssertFalse(CanvasController.mapStepsAside(entered: true, staysUp: true, paused: false,
                                                       otherWork: false, visible: true))
    }

    func testTheMapStaysUpWhenOffInTheMenuBar() {
        XCTAssertFalse(CanvasController.mapStepsAside(entered: true, staysUp: false, paused: true,
                                                       otherWork: false, visible: true))
    }

    func testTheMapStaysUpWithTheWidgetEditorOrSetup() {
        XCTAssertFalse(CanvasController.mapStepsAside(entered: true, staysUp: false, paused: false,
                                                       otherWork: true, visible: true))
    }

    func testNothingHappensWithTheMapAlreadyOff() {
        XCTAssertFalse(CanvasController.mapStepsAside(entered: true, staysUp: false, paused: false,
                                                       otherWork: false, visible: false))
    }

    func testNoWindowEnteredNoStepAside() {
        XCTAssertFalse(CanvasController.mapStepsAside(entered: false, staysUp: false, paused: false,
                                                       otherWork: false, visible: true))
    }
}
