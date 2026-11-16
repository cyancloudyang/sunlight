import CoreGraphics
import XCTest
@testable import Canvas

/// With the private id symbol missing, a window is identified by its frame (#8 in the handoff): the match
/// must be the window at that frame, and no guess when nothing is there.
final class AXFrameMatchTests: XCTestCase {
    private let target = CGRect(x: 100, y: 200, width: 800, height: 600)

    func testAnExactFrameMatches() {
        XCTAssertEqual(AXFrames.bestMatch([target], to: target), 0)
    }

    func testAFrameWithinToleranceMatches() {
        let near = target.offsetBy(dx: 1, dy: -1)
        XCTAssertEqual(AXFrames.bestMatch([near], to: target), 0)
    }

    func testAFrameOutsideToleranceDoesNotMatch() {
        let off = target.offsetBy(dx: 3, dy: 0)
        XCTAssertNil(AXFrames.bestMatch([off], to: target))
    }

    func testASizeMismatchDoesNotMatch() {
        let wrong = CGRect(x: 100, y: 200, width: 900, height: 600)
        XCTAssertNil(AXFrames.bestMatch([wrong], to: target))
    }

    func testTheClosestOfSeveralFramesWins() {
        let off = target.offsetBy(dx: 5, dy: 0)
        let near = target.offsetBy(dx: 0, dy: 1.5)
        XCTAssertEqual(AXFrames.bestMatch([off, near], to: target), 1)
    }

    func testNoFramesMeansNoMatch() {
        XCTAssertNil(AXFrames.bestMatch([], to: target))
    }

    func testACustomToleranceIsHonoured() {
        let off = target.offsetBy(dx: 4, dy: 0)
        XCTAssertEqual(AXFrames.bestMatch([off], to: target, tolerance: 5), 0)
    }
}
