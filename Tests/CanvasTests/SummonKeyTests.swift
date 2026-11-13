import XCTest
import CoreGraphics
@testable import Canvas

/// F3 summons the canvas without takeover; a second key can be given to it when F3 is taken, set in
/// `Settings.summonBackupKey` and read by the tap on start (#5 in the handoff). Anything with a modifier
/// is somebody else's shortcut and passes; a held key is still one press.
final class SummonKeyTests: XCTestCase {
    private let f3: Int64 = 99
    private let missionControl: Int64 = 160
    private let backup: Int64 = 97   // F7, say

    private func summon(_ keyCode: Int64, state: inout KeyTap.State, autorepeat: Bool = false,
                        flags: CGEventFlags = []) -> KeyTap.Action {
        KeyTap.summonAction(keyCode: keyCode, flags: flags, state: &state, autorepeat: autorepeat,
                            timestamp: 1_000, summonKeys: KeyTap.summonKeys(backup: nil))
    }

    func testTheMacsKeySummonsTheCanvas() {
        var state = KeyTap.State()
        XCTAssertEqual(summon(missionControl, state: &state), .send(.missionControl))
    }

    func testF3SummonsTheCanvas() {
        var state = KeyTap.State()
        XCTAssertEqual(summon(f3, state: &state), .send(.missionControl))
    }

    func testAHeldKeyIsStillOnePress() {
        var state = KeyTap.State()
        XCTAssertEqual(summon(f3, state: &state), .send(.missionControl))
        XCTAssertEqual(summon(f3, state: &state, autorepeat: true), .swallow)
        XCTAssertEqual(summon(f3, state: &state), .swallow, "the key is down: no second press")
    }

    func testWithAModifierTheKeyIsSomebodyElses() {
        var state = KeyTap.State()
        XCTAssertEqual(summon(f3, state: &state, flags: .maskCommand), .pass)
        XCTAssertEqual(summon(missionControl, state: &state, flags: .maskAlternate), .pass)
        XCTAssertEqual(summon(backup, state: &state, flags: .maskControl), .pass)
    }

    func testABackupKeySummonsWhenItIsSet() {
        var state = KeyTap.State()
        let action = KeyTap.summonAction(keyCode: backup, flags: [], state: &state, timestamp: 1_000,
                                         summonKeys: KeyTap.summonKeys(backup: backup))
        XCTAssertEqual(action, .send(.missionControl))
    }

    func testWithNoBackupKeyThatKeyPasses() {
        var state = KeyTap.State()
        XCTAssertEqual(summon(backup, state: &state), .pass)
    }

    func testTheBackupKeyDoesNotReplaceTheMacsKeys() {
        let keys = KeyTap.summonKeys(backup: backup)
        XCTAssertTrue(keys.contains(f3))
        XCTAssertTrue(keys.contains(missionControl))
        XCTAssertTrue(keys.contains(backup))
    }
}
