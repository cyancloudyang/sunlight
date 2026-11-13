import XCTest
@testable import Canvas

/// The one-time auto-arrange: windows grouped by app, each at its own size, never overlapping. It runs
/// once on the first canvas after this feature shipped — a fresh one, or a saved layout from before that
/// was never auto-arranged — then the user's moves win.
final class FirstArrangementTests: XCTestCase {
    private let screen = CGRect(x: 0, y: 25, width: 1512, height: 920)

    private func item(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, app: String) -> Tidy.Item {
        Tidy.Item(rect: CGRect(x: x, y: y, width: w, height: h), recency: nil, app: app)
    }

    func testTheFirstCanvasIsGroupedByAppAtEachWindowsOwnSize() {
        let o = FirstArrangement.options(spacing: 32)
        XCTAssertEqual(o.order, .app, "group an app's windows together")
        XCTAssertEqual(o.sizing, .keep, "never resize a window to arrange it")
        XCTAssertEqual(o.columns, 0, "auto columns")
        XCTAssertEqual(o.spacing, 32)
    }

    func testACanvasNeverAutoArrangedArrangesOnce() {
        // Fresh, or a saved layout from before this feature: neither has been auto-arranged, so both do once.
        XCTAssertTrue(FirstArrangement.shouldArrange(alreadyArranged: false))
    }

    func testOnceAutoArrangedTheUsersMovesWin() {
        XCTAssertFalse(FirstArrangement.shouldArrange(alreadyArranged: true), "after the one-time arrange the saved layout and the user's moves win")
    }

    func testOverlappingWindowsEndUpSeparatedAndGroupedByApp() {
        // Four windows piled on top of each other, two of them Mail.
        let items = [item(100, 100, 400, 300, app: "Mail"), item(150, 120, 500, 400, app: "Safari"),
                     item(200, 150, 400, 300, app: "Mail"), item(120, 110, 300, 200, app: "Notes")]
        let options = FirstArrangement.options(spacing: 32)
        let placed = Tidy.layout(items, options: options, screen: screen)
        // Nothing overlaps anymore, and nothing was resized.
        for a in placed.rects.indices {
            XCTAssertEqual(placed.rects[a].size, items[a].rect.size)
            for b in placed.rects.indices where a < b {
                XCTAssertFalse(placed.rects[a].intersects(placed.rects[b]), "\(a) and \(b) overlap")
            }
        }
        // Each app's windows fill the grid together, not scattered among the others.
        let order = Tidy.order(items, by: options.order)
        var seenApps = Set<String>()
        var lastApp = ""
        for i in order {
            let app = items[i].app
            if app != lastApp {
                XCTAssertFalse(seenApps.contains(app), "\(app) appears in more than one block")
                seenApps.insert(app)
                lastApp = app
            }
        }
    }
}