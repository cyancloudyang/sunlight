import XCTest
import CoreGraphics
@testable import Canvas

/// A focus grows the proxy to the screen and leaves the camera on the window for the visit. Written down
/// as they are — by the periodical remember, by a quit mid-visit — the map would come back to the place the
/// focus left it, not to the map the user made, and stay there (#4 in the handoff). What's remembered is the
/// rect and camera the window was entered from.
final class QuitDuringFocusTests: XCTestCase {
    private let mapRect = CGRect(x: 120, y: 240, width: 900, height: 640)
    private let grown = CGRect(x: 0, y: 0, width: 1512, height: 945)
    private let mapCamera = Camera(origin: CGPoint(x: -300, y: -120), zoom: 0.5)
    private let focusCamera = Camera(origin: CGPoint(x: 120, y: 240), zoom: 1)

    func testTheEnteredWindowsRectIsItsRectOnTheMap() {
        let saved = CanvasController.rememberedRect(entered: true, sameWindow: true,
                                                    mapRect: mapRect, worldRect: grown)
        XCTAssertEqual(saved, mapRect)
    }

    func testAGrownProxyWithNoSavedRectIsRememberedAsItIs() {
        // No saved rect: nothing was flown from (a window entered at 1:1 in place), so the rect is the place.
        let saved = CanvasController.rememberedRect(entered: true, sameWindow: false,
                                                    mapRect: mapRect, worldRect: grown)
        XCTAssertEqual(saved, grown)
    }

    func testANotEnteredProxyIsItsRect() {
        let saved = CanvasController.rememberedRect(entered: false, sameWindow: true,
                                                    mapRect: mapRect, worldRect: grown)
        XCTAssertEqual(saved, grown)
    }

    func testTheCameraIsTheOneTheWindowWasEnteredFrom() {
        XCTAssertEqual(CanvasController.rememberedCamera(entered: true, returnCamera: mapCamera, camera: focusCamera),
                       mapCamera)
    }

    func testWithNoWindowInUseTheCameraIsTheOneOnScreen() {
        XCTAssertEqual(CanvasController.rememberedCamera(entered: false, returnCamera: mapCamera, camera: focusCamera),
                       focusCamera)
    }

    func testAnEnteredWindowWithNoSavedCameraKeepsTheOneOnScreen() {
        // Entered in place at 1:1: the camera never left, and that's the one to remember.
        XCTAssertEqual(CanvasController.rememberedCamera(entered: true, returnCamera: nil, camera: focusCamera),
                       focusCamera)
    }
}
