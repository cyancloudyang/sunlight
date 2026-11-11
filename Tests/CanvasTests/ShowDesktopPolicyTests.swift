import XCTest
@testable import Canvas

final class ShowDesktopPolicyTests: XCTestCase {
    /// Off (the default) keeps the canvas's own desktop floor: the camera flies to the snapshot.
    func testDefaultRevealsTheCanvasFloor() {
        XCTAssertEqual(ShowDesktopPolicy.reveal(realDesktop: false), .canvasFloor)
    }

    /// Opt-in reveals the real, interactive macOS desktop instead.
    func testOptInRevealsTheSystemDesktop() {
        XCTAssertEqual(ShowDesktopPolicy.reveal(realDesktop: true), .systemDesktop)
    }
}