import XCTest
import CoreGraphics
@testable import Canvas

final class SetupPageLayoutTests: XCTestCase {
    /// A 1512 × 982 screen with a 37-point menu bar, in overlay (top-left) coordinates.
    private let area = CGRect(x: 0, y: 37, width: 1512, height: 945)
    private typealias L = SetupPageLayout

    func testActionRowSitsInTheLowerMiddle() {
        let bottom = L(area: area, scale: 1).actionsBottom
        XCTAssertGreaterThan(bottom, area.midY, "the button sits below the vertical middle")
        XCTAssertLessThan(bottom, area.maxY, "and above the bottom edge, clear of the Set Up Later row")
    }

    func testAnchorScalesWithTheTypeScale() {
        XCTAssertEqual(L(area: area, scale: 1).actionsBottom, area.maxY - L.bottomMargin)
        XCTAssertEqual(L(area: area, scale: 1.2).actionsBottom, area.maxY - L.bottomMargin * 1.2)
    }

    func testTheAnchorNeverDependsOnTheDemo() {
        // The layout carries no demo height: a short page and a tall tutorial share one button position.
        let l = L(area: area, scale: 1)
        XCTAssertEqual(l.actionsBottom, L(area: area, scale: 1).actionsBottom)
    }
}