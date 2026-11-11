import XCTest
import CoreGraphics
@testable import Canvas

final class BackgroundFocusTests: XCTestCase {
    private typealias Spec = BackgroundSpec

    func testBlurBeginsRightBelowOneToOne() {
        // The picture starts to soften as soon as the camera leaves 1:1, not only below 0.9.
        XCTAssertGreaterThan(Spec.focus(forZoom: 0.95), 0)
        XCTAssertGreaterThan(Spec.focus(forZoom: 0.99), 0)
    }

    func testBlurReachesFullOnlyDeepInTheZoomOut() {
        // Still sharpening at 0.4; the ceiling is reached further out, so the fade spans the whole flight.
        XCTAssertLessThan(Spec.focus(forZoom: 0.4), 1)
        XCTAssertEqual(Spec.focus(forZoom: 0.3), 1)
        XCTAssertEqual(Spec.focus(forZoom: 0.0), 1)
    }

    func testFocusIsSharpAtOneToOneAndAbove() {
        XCTAssertEqual(Spec.focus(forZoom: 1.0), 0)
        XCTAssertEqual(Spec.focus(forZoom: 1.5), 0)
    }

    func testFocusClimbsSmoothlyAcrossTheBand() {
        let zooms: [CGFloat] = [1.0, 0.9, 0.8, 0.7, 0.6, 0.5, 0.4, 0.3, 0.2]
        let f = zooms.map { Spec.focus(forZoom: $0) }
        for i in 1..<f.count { XCTAssertGreaterThanOrEqual(f[i], f[i - 1]) }
        // A smoothstep interior: the middle of the band is strictly between its ends, no flat step.
        XCTAssertGreaterThan(Spec.focus(forZoom: 0.65), Spec.focus(forZoom: 0.85))
        XCTAssertLessThan(Spec.focus(forZoom: 0.65), Spec.focus(forZoom: 0.45))
    }

    func testTheLadderHasNoBigJumps() {
        // Adjacent blur levels stay close enough that a cross-fade reads as gradual blur, not a dissolve
        // between two distinct pictures. The old ladder jumped 28 → 60 in one step.
        let r = BackgroundPipeline.levelRadii
        for i in 1..<r.count { XCTAssertGreaterThan(r[i], r[i - 1]) }
        let maxGap = zip(r, r.dropFirst()).map { $1 - $0 }.max() ?? 0
        XCTAssertLessThanOrEqual(maxGap, 16)
    }

    func testBlurCeilingsKeepTheirRadii() {
        XCTAssertEqual(BackgroundPipeline.levelRadii[Spec.Blur.off.level], 0)
        XCTAssertEqual(BackgroundPipeline.levelRadii[Spec.Blur.soft.level], 28)
        XCTAssertEqual(BackgroundPipeline.levelRadii[Spec.Blur.deep.level], 60)
    }

    func testBlurPositionSpansTheCeiling() {
        var spec = Spec.default
        spec.blur = .deep
        spec.focusFollowsZoom = true
        XCTAssertEqual(spec.blurPosition(forZoom: 1.0), 0)
        XCTAssertEqual(spec.blurPosition(forZoom: 0.3), CGFloat(Spec.Blur.deep.level))
    }
}