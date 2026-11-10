import XCTest
@testable import Canvas

final class RefreshPolicyTests: XCTestCase {
    func testHiddenMapNeverCaptures() {
        for event: RefreshPolicy.Event in [.mapShown, .cameraSettled, .focusReturned, .tick] {
            XCTAssertTrue(RefreshPolicy.actions(for: event, mapVisible: false, rotationEnabled: true, handoffInFlight: true).isEmpty)
            XCTAssertTrue(RefreshPolicy.actions(for: event, mapVisible: false, rotationEnabled: false, handoffInFlight: false).isEmpty)
        }
    }

    func testEntryAndSettleRefreshVisible() {
        XCTAssertEqual(RefreshPolicy.actions(for: .mapShown, mapVisible: true, rotationEnabled: false, handoffInFlight: false), [.refreshVisible])
        XCTAssertEqual(RefreshPolicy.actions(for: .cameraSettled, mapVisible: true, rotationEnabled: true, handoffInFlight: true), [.refreshVisible])
    }

    func testReturnRefreshesPrimary() {
        XCTAssertEqual(RefreshPolicy.actions(for: .focusReturned, mapVisible: true, rotationEnabled: true, handoffInFlight: true), [.refreshPrimary])
    }

    func testIdleTickWithRotationOffDoesNothing() {
        XCTAssertTrue(RefreshPolicy.actions(for: .tick, mapVisible: true, rotationEnabled: false, handoffInFlight: false).isEmpty)
    }

    func testRotationAndHandoffTicks() {
        XCTAssertEqual(RefreshPolicy.actions(for: .tick, mapVisible: true, rotationEnabled: true, handoffInFlight: false), [.rotateOne])
        XCTAssertEqual(RefreshPolicy.actions(for: .tick, mapVisible: true, rotationEnabled: false, handoffInFlight: true), [.refreshPrimary])
        XCTAssertEqual(RefreshPolicy.actions(for: .tick, mapVisible: true, rotationEnabled: true, handoffInFlight: true), [.refreshPrimary])
    }

    func testRotationDefaultsOff() async {
        await MainActor.run {
            UserDefaults.standard.removeObject(forKey: "TableclothSnapshotRotation")
            XCTAssertFalse(Settings.snapshotRotation)
        }
    }
}