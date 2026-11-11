import XCTest
import CoreGraphics
@testable import Canvas

/// The ⌘Tab flight rises visibly even between nearby windows: a higher-ρ van Wijk arc pulls the camera
/// back further on the way, so the hop reads as fly-up-and-land rather than a flat smear. The default
/// arc (focus dive, return, snap) is untouched.
final class FlightArcTests: XCTestCase {
    private let viewSize = CGSize(width: 1512, height: 982)

    private func minZoom(from: Camera, to: Camera, rho: CGFloat) -> CGFloat {
        let path = CameraPath(from: from, to: to, viewSize: viewSize, rho: rho)
        return stride(from: CGFloat(0), through: 1, by: 0.02).map { path.camera(at: $0).zoom }.min() ?? 1
    }

    func testTheSwitcherArcPullsBackFurtherThanTheDefault() {
        let from = Camera(center: CGPoint(x: 0, y: 0), zoom: 1, viewSize: viewSize)
        let to = Camera(center: CGPoint(x: 800, y: 0), zoom: 1, viewSize: viewSize)
        let standard = minZoom(from: from, to: to, rho: CameraPath.rho)
        let switcher = minZoom(from: from, to: to, rho: CameraPath.switcherRho)
        // A nearby hop barely rises on the default arc; the switcher arc rises clearly more.
        XCTAssertLessThan(switcher, standard)
        XCTAssertLessThan(switcher, 0.9)
    }

    func testTheArcStillLandsOnTheTarget() {
        let from = Camera(center: CGPoint(x: 0, y: 0), zoom: 1, viewSize: viewSize)
        let to = Camera(center: CGPoint(x: 800, y: -300), zoom: 0.8, viewSize: viewSize)
        let path = CameraPath(from: from, to: to, viewSize: viewSize, rho: CameraPath.switcherRho)
        let landed = path.camera(at: 1)
        XCTAssertEqual(landed.zoom, to.zoom, accuracy: 1e-6)
        XCTAssertEqual(landed.center(viewSize: viewSize).x, to.center(viewSize: viewSize).x, accuracy: 1e-3)
        XCTAssertEqual(landed.center(viewSize: viewSize).y, to.center(viewSize: viewSize).y, accuracy: 1e-3)
    }

    func testTheDefaultArcIsUnchanged() {
        let from = Camera(center: CGPoint(x: 0, y: 0), zoom: 1, viewSize: viewSize)
        let to = Camera(center: CGPoint(x: 800, y: 0), zoom: 1, viewSize: viewSize)
        let implicit = CameraPath(from: from, to: to, viewSize: viewSize)
        let explicit = CameraPath(from: from, to: to, viewSize: viewSize, rho: CameraPath.rho)
        for t in stride(from: CGFloat(0), through: 1, by: 0.1) {
            XCTAssertEqual(implicit.camera(at: t).zoom, explicit.camera(at: t).zoom, accuracy: 1e-9)
        }
    }

    func testAPureZoomDoesNotDriftSideways() {
        let from = Camera(center: CGPoint(x: 100, y: 100), zoom: 1, viewSize: viewSize)
        let to = Camera(center: CGPoint(x: 100, y: 100), zoom: 0.4, viewSize: viewSize)
        let path = CameraPath(from: from, to: to, viewSize: viewSize, rho: CameraPath.switcherRho)
        for t in stride(from: CGFloat(0), through: 1, by: 0.1) {
            let c = path.camera(at: t).center(viewSize: viewSize)
            XCTAssertEqual(c.x, 100, accuracy: 1e-6)
            XCTAssertEqual(c.y, 100, accuracy: 1e-6)
        }
    }
}