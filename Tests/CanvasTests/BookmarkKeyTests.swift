import XCTest
import AppKit
import Carbon.HIToolbox
@testable import Canvas

final class BookmarkKeyTests: XCTestCase {
    func testPlainDigitsJump() {
        XCTAssertEqual(BookmarkKey.action(keyCode: kVK_ANSI_5, modifiers: []), .jump(5))
        XCTAssertEqual(BookmarkKey.action(keyCode: kVK_ANSI_1, modifiers: []), .jump(1))
        XCTAssertEqual(BookmarkKey.action(keyCode: kVK_ANSI_9, modifiers: []), .jump(9))
    }

    func testControlDigitsSave() {
        XCTAssertEqual(BookmarkKey.action(keyCode: kVK_ANSI_5, modifiers: [.control]), .save(5))
    }

    func testOtherKeysAndModifiersAreNil() {
        XCTAssertNil(BookmarkKey.action(keyCode: kVK_ANSI_A, modifiers: []))
        XCTAssertNil(BookmarkKey.action(keyCode: kVK_ANSI_5, modifiers: [.command]))
        XCTAssertNil(BookmarkKey.action(keyCode: kVK_ANSI_5, modifiers: [.option]))
        XCTAssertNil(BookmarkKey.action(keyCode: kVK_ANSI_5, modifiers: [.control, .shift]))
    }
}