import XCTest
@testable import Canvas

/// The name plate as the zoom and hover now are: a banner from far out, the small title near,
/// nothing at 1:1 where the real title bar takes over.
final class LabelPolicyTests: XCTestCase {
    func testModes() {
        XCTAssertEqual(LabelPolicy.mode(zoom: 1.0, hovered: false), .hidden)
        XCTAssertEqual(LabelPolicy.mode(zoom: 0.5, hovered: false), .compact)
        XCTAssertEqual(LabelPolicy.mode(zoom: 0.2, hovered: false), .banner)
        XCTAssertEqual(LabelPolicy.mode(zoom: 1.0, hovered: true), .compact)
        XCTAssertEqual(LabelPolicy.mode(zoom: 0.35, hovered: false), .compact)  // 边界归 compact
        XCTAssertEqual(LabelPolicy.mode(zoom: 0.8, hovered: false), .hidden)   // 边界归 hidden
    }
}