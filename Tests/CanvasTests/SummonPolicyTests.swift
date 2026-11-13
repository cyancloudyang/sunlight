import XCTest
@testable import Canvas

final class SummonPolicyTests: XCTestCase {
    func testHidesOnlyWhenForeignFrontAndNoHandoff() {
        XCTAssertTrue(SummonPolicy.hidesOnResign(frontIsSelf: false, handoffInFlight: false))
        XCTAssertFalse(SummonPolicy.hidesOnResign(frontIsSelf: true, handoffInFlight: false))
        XCTAssertFalse(SummonPolicy.hidesOnResign(frontIsSelf: false, handoffInFlight: true))
        XCTAssertFalse(SummonPolicy.hidesOnResign(frontIsSelf: true, handoffInFlight: true))
    }
}