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
}
