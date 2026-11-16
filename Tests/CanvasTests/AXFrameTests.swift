import XCTest
import CoreGraphics
import ApplicationServices
@testable import Canvas

final class AXFrameTests: XCTestCase {
    private func point(_ x: CGFloat, _ y: CGFloat) -> AXValue {
        var p = CGPoint(x: x, y: y)
        return AXValueCreate(.cgPoint, &p)!
    }

    private func size(_ w: CGFloat, _ h: CGFloat) -> AXValue {
        var s = CGSize(width: w, height: h)
        return AXValueCreate(.cgSize, &s)!
    }

    func testParsesPositionAndSize() {
        let frame = AXFrame.parse([point(10, 20), size(800, 600)])
        XCTAssertEqual(frame, CGRect(x: 10, y: 20, width: 800, height: 600))
    }

    func testRejectsWrongCount() {
        XCTAssertNil(AXFrame.parse([]))
        XCTAssertNil(AXFrame.parse([point(0, 0)]))
        XCTAssertNil(AXFrame.parse([point(0, 0), size(1, 1), size(2, 2)]))
    }

    func testRejectsMismatchedTypes() {
        XCTAssertNil(AXFrame.parse([size(800, 600), size(800, 600)]))
        XCTAssertNil(AXFrame.parse([point(10, 20), point(10, 20)]))
    }

    func testRejectsABatchedErrorValue() {
        // A failed attribute in a batched read comes back as an AXValue of type axError, not a point.
        var err = AXError.cannotComplete
        let errorValue = AXValueCreate(.axError, &err)!
        XCTAssertNil(AXFrame.parse([errorValue, size(800, 600)]))
        XCTAssertNil(AXFrame.parse([point(10, 20), errorValue]))
    }
}