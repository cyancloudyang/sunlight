import XCTest
@testable import Canvas

/// Stage Manager is read, never written: the write path went with takeover (#1 in the handoff).
final class StageManagerTests: XCTestCase {
    private func store(on: Bool, turnedOff: Bool = false) -> StageManager.Store {
        StageManager.Store(read: { on }, turnedOff: { turnedOff })
    }

    func testIsOnReadsTheSwitch() {
        XCTAssertTrue(StageManager.isOn(store(on: true)))
        XCTAssertFalse(StageManager.isOn(store(on: false)))
    }

    func testTheOldNoteIsRead() {
        XCTAssertTrue(StageManager.turnedOffBySunlight(store(on: false, turnedOff: true)))
        XCTAssertFalse(StageManager.turnedOffBySunlight(store(on: false)))
    }

    func testDescriptions() {
        XCTAssertEqual(StageManager.describe(on: false, turnedOffBySunlight: false), "off")
        XCTAssertEqual(StageManager.describe(on: true, turnedOffBySunlight: true), "on")
        XCTAssertTrue(StageManager.describe(on: false, turnedOffBySunlight: true).contains("earlier Sunlight"))
    }

    func testDescribeCurrentUsesTheStore() {
        XCTAssertEqual(StageManager.describeCurrent(store(on: true)), "on")
        XCTAssertEqual(StageManager.describeCurrent(store(on: false)), "off")
    }
}
