import XCTest
@testable import Canvas

final class SettingsTests: XCTestCase {
    func testMapEntryCountStartsAtZeroAndPersists() async {
        await MainActor.run {
            let defaults = UserDefaults.standard
            let saved = defaults.object(forKey: "TableclothMapEntries")
            defer { defaults.set(saved, forKey: "TableclothMapEntries") }
            defaults.removeObject(forKey: "TableclothMapEntries")
            XCTAssertEqual(Settings.tableclothMapEntries, 0)
            Settings.tableclothMapEntries = 5
            XCTAssertEqual(defaults.integer(forKey: "TableclothMapEntries"), 5)
            XCTAssertEqual(Settings.tableclothMapEntries, 5)
        }
    }

    func testRendererIsAlwaysCapture() async {
        await MainActor.run {
            XCTAssertEqual(Settings.renderer, .capture)
        }
    }

    func testNeverStreams() async {
        await MainActor.run {
            XCTAssertFalse(Settings.capturesStream)
            XCTAssertEqual(CanvasController.maxStreams, 0)
        }
    }

    func testCommandLineCanDisableLayoutPersistenceWithoutChangingSavedPreferences() async {
        await MainActor.run {
            let defaults = UserDefaults.standard
            let original = defaults.volatileDomain(forName: UserDefaults.argumentDomain)
            defer { defaults.setVolatileDomain(original, forName: UserDefaults.argumentDomain) }
            var arguments = original
            // NSArgumentDomain contains strings for flags passed to a development/test launch.
            arguments["CanvasRemember"] = "NO"
            defaults.setVolatileDomain(arguments, forName: UserDefaults.argumentDomain)
            XCTAssertFalse(Settings.rememberCanvas)
            arguments["CanvasRemember"] = "YES"
            defaults.setVolatileDomain(arguments, forName: UserDefaults.argumentDomain)
            XCTAssertTrue(Settings.rememberCanvas)
        }
    }

    func testSwitcherEdgeDefaultsToBottomAndRoundTrips() async {
        await MainActor.run {
            let defaults = UserDefaults.standard
            let saved = defaults.object(forKey: "SwitcherEdge")
            defer { defaults.set(saved, forKey: "SwitcherEdge") }
            defaults.removeObject(forKey: "SwitcherEdge")
            XCTAssertEqual(Settings.switcherEdge, .bottom)
            for edge in SwitcherEdge.allCases {
                Settings.switcherEdge = edge
                XCTAssertEqual(Settings.switcherEdge, edge)
            }
            defaults.set("diagonal", forKey: "SwitcherEdge")
            XCTAssertEqual(Settings.switcherEdge, .bottom)
        }
    }

    func testRealDesktopDefaultsOffAndRoundTrips() async {
        await MainActor.run {
            let defaults = UserDefaults.standard
            let saved = defaults.object(forKey: "CanvasRealDesktop")
            defer { defaults.set(saved, forKey: "CanvasRealDesktop") }
            defaults.removeObject(forKey: "CanvasRealDesktop")
            // Off keeps the working canvas floor; the real desktop is opt-in.
            XCTAssertFalse(Settings.realDesktopOnShowDesktop)
            Settings.realDesktopOnShowDesktop = true
            XCTAssertTrue(Settings.realDesktopOnShowDesktop)
            Settings.realDesktopOnShowDesktop = false
            XCTAssertFalse(Settings.realDesktopOnShowDesktop)
        }
    }

    func testDidAutoArrangeDefaultsOffAndRoundTrips() async {
        await MainActor.run {
            let defaults = UserDefaults.standard
            let saved = defaults.object(forKey: "CanvasDidAutoArrange")
            defer { defaults.set(saved, forKey: "CanvasDidAutoArrange") }
            defaults.removeObject(forKey: "CanvasDidAutoArrange")
            // Never arranged yet: the first canvas after this feature shipped arranges once, saved layout or not.
            XCTAssertFalse(Settings.didAutoArrange)
            Settings.didAutoArrange = true
            XCTAssertTrue(Settings.didAutoArrange)
        }
    }

    func testSeeAllGestureDefaultsToSwipeUpAndRoundTrips() async {
        await MainActor.run {
            let defaults = UserDefaults.standard
            let saved = defaults.object(forKey: "CanvasSeeAllGesture")
            defer { defaults.set(saved, forKey: "CanvasSeeAllGesture") }
            defaults.removeObject(forKey: "CanvasSeeAllGesture")
            // Out of the box an upward four-finger swipe is See All; the other drags stay pans.
            XCTAssertEqual(Settings.seeAllGesture, .swipeUp)
            Settings.seeAllGesture = .tap
            XCTAssertEqual(Settings.seeAllGesture, .tap)
            Settings.seeAllGesture = .swipeUp
            XCTAssertEqual(Settings.seeAllGesture, .swipeUp)
        }
    }

    func testGestureEntryDefaultsOnAndRoundTrips() async {
        await MainActor.run {
            let defaults = UserDefaults.standard
            let saved = defaults.object(forKey: "CanvasGestureEntry")
            defer { defaults.set(saved, forKey: "CanvasGestureEntry") }
            defaults.removeObject(forKey: "CanvasGestureEntry")
            // Out of the box the swipe up drives the pull-back itself; off, entry is the plain See All flight.
            XCTAssertTrue(Settings.gestureEntry)
            Settings.gestureEntry = false
            XCTAssertFalse(Settings.gestureEntry)
            Settings.gestureEntry = true
            XCTAssertTrue(Settings.gestureEntry)
        }
    }

    func testGestureEntryPostsAChangeNotification() async {
        await MainActor.run {
            let defaults = UserDefaults.standard
            let saved = defaults.object(forKey: "CanvasGestureEntry")
            defer { defaults.set(saved, forKey: "CanvasGestureEntry") }
            var posted = 0
            let token = NotificationCenter.default.addObserver(forName: Settings.gestureEntryDidChange,
                                                              object: nil, queue: nil) { _ in posted += 1 }
            defer { NotificationCenter.default.removeObserver(token) }
            Settings.gestureEntry = false
            XCTAssertEqual(posted, 1)
            Settings.gestureEntry = true
            XCTAssertEqual(posted, 2)
        }
    }
}
