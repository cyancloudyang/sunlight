import XCTest
@testable import Canvas

@MainActor
final class PreviewModeTests: XCTestCase {
    func testPreviewModeIsAFreshInstallWithoutScreenCaptureMode() {
        XCTAssertTrue(Settings.previewMode(liveWindowsEverLoaded: false, screenCapture: false))
        XCTAssertFalse(Settings.previewMode(liveWindowsEverLoaded: true, screenCapture: false))
        XCTAssertFalse(Settings.previewMode(liveWindowsEverLoaded: false, screenCapture: true))
        XCTAssertFalse(Settings.previewMode(liveWindowsEverLoaded: true, screenCapture: true))
    }

    /// Tablecloth is a snapshot map: no combination of defaults ever streams.
    func testStreamsAreAlwaysOff() {
        let defaults = UserDefaults.standard
        let original = defaults.volatileDomain(forName: UserDefaults.argumentDomain)
        defer { defaults.setVolatileDomain(original, forName: UserDefaults.argumentDomain) }
        var arguments = original
        for (capture, loaded) in [("NO", "NO"), ("NO", "YES"), ("YES", "NO"), ("YES", "YES")] {
            arguments["ScreenCaptureMode"] = capture
            arguments["LiveWindowsEverLoaded"] = loaded
            defaults.setVolatileDomain(arguments, forName: UserDefaults.argumentDomain)
            XCTAssertFalse(Settings.capturesStream)
            XCTAssertEqual(CanvasController.maxStreams, 0)
        }
    }
}
