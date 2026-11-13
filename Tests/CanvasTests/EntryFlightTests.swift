import XCTest
@testable import Canvas
import CoreGraphics

final class EntryFlightTests: XCTestCase {
    private let identity = Camera(origin: .zero, zoom: 1)

    func testCardsSelectsOnlyOnScreenWindowsWithAStoredPlace() {
        let snap = FrameSnapshot(frames: [1: CGRect(x: 100, y: 100, width: 400, height: 300),
                                          2: CGRect(x: 50, y: 50, width: 200, height: 200)],
                                 camera: identity)
        let stored: [CGWindowID: CGRect] = [1: CGRect(x: 1000, y: 1000, width: 400, height: 300),
                                            3: CGRect(x: 0, y: 0, width: 100, height: 100)]  // 3 off-screen
        let cards = EntryFlight.cards(snapshot: snap, stored: stored, insets: [1: 0, 2: 0], camera: identity)
        XCTAssertEqual(cards.count, 1)                     // only 1: on-screen AND stored
        XCTAssertEqual(cards[1]?.from, CGPoint(x: 100, y: 100))
        XCTAssertEqual(cards[1]?.to, CGPoint(x: 1000, y: 1000))
    }

    /// `from` is where the card has to sit on the canvas to look like the real window where it is: the
    /// real global point seen through the entry camera (`camera.toWorld`, as `WindowProxy.worldRect`).
    func testCardsFromIsTheRealOriginSeenThroughTheCamera() {
        let cam = Camera(origin: CGPoint(x: 20, y: 30), zoom: 1)
        let snap = FrameSnapshot(frames: [1: CGRect(x: 100, y: 100, width: 400, height: 300)], camera: cam)
        let stored: [CGWindowID: CGRect] = [1: CGRect(x: 1000, y: 1000, width: 400, height: 300)]
        let cards = EntryFlight.cards(snapshot: snap, stored: stored, insets: [1: 10], camera: cam)
        // content origin (110,110) through the camera, whose origin is (20,30): world (130,140).
        XCTAssertEqual(cards[1]?.from, CGPoint(x: 130, y: 140))
        // And back through the camera it lands on the real point: no jump at t=0.
        XCTAssertEqual(cam.toScreen(cards[1]!.from), CGPoint(x: 110, y: 110))
    }

    func testCardsFromIsTheRealOriginSeenThroughAZoomedOutCamera() {
        let cam = Camera(origin: CGPoint(x: -100, y: -50), zoom: 0.5)
        let snap = FrameSnapshot(frames: [1: CGRect(x: 100, y: 100, width: 400, height: 300)], camera: cam)
        let stored: [CGWindowID: CGRect] = [1: CGRect(x: 1000, y: 1000, width: 400, height: 300)]
        let cards = EntryFlight.cards(snapshot: snap, stored: stored, insets: [1: 0], camera: cam)
        XCTAssertEqual(cam.toScreen(cards[1]!.from), CGPoint(x: 100, y: 100))
    }

    func testCardsSkipsWindowsWithNoSize() {
        let snap = FrameSnapshot(frames: [1: CGRect(x: 100, y: 100, width: 0, height: 0)], camera: identity)
        let stored: [CGWindowID: CGRect] = [1: CGRect(x: 10, y: 10, width: 400, height: 300)]
        XCTAssertTrue(EntryFlight.cards(snapshot: snap, stored: stored, insets: [:], camera: identity).isEmpty)
    }

    func testCardsEmptyWhenNoWindowsOnScreen() {
        let snap = FrameSnapshot(frames: [:], camera: identity)
        XCTAssertTrue(EntryFlight.cards(snapshot: snap, stored: [1: CGRect(x: 0, y: 0, width: 10, height: 10)],
                                        insets: [:], camera: identity).isEmpty)
    }

    func testOriginLerpsAndClampsPastTheEnds() {
        let card = EntryFlight.Card(from: CGPoint(x: 0, y: 0), to: CGPoint(x: 100, y: 200))
        XCTAssertEqual(EntryFlight.origin(card, at: 0), CGPoint(x: 0, y: 0))
        XCTAssertEqual(EntryFlight.origin(card, at: 0.5), CGPoint(x: 50, y: 100))
        XCTAssertEqual(EntryFlight.origin(card, at: 1), CGPoint(x: 100, y: 200))
        XCTAssertEqual(EntryFlight.origin(card, at: 1.2), CGPoint(x: 100, y: 200))   // spring overshoot clamped
        XCTAssertEqual(EntryFlight.origin(card, at: -0.3), CGPoint(x: 0, y: 0))
    }

    func testCommittedAtOrAboveThreshold() {
        XCTAssertFalse(EntryFlight.committed(progress: 0.49, threshold: 0.5))
        XCTAssertTrue(EntryFlight.committed(progress: 0.5, threshold: 0.5))
        XCTAssertTrue(EntryFlight.committed(progress: 0.9, threshold: 0.5))
        XCTAssertEqual(EntryFlight.commitThreshold, 0.5)
    }

    func testVelocityIsProgressPerSecondFromTheLastSamples() {
        let v = EntryFlight.velocity([(0.2, 0.0), (0.4, 0.1), (0.6, 0.2)])
        XCTAssertEqual(v, 2.0, accuracy: 0.001)   // ~0.4 progress over 0.2 s
        XCTAssertEqual(EntryFlight.velocity([]), 0)
        XCTAssertEqual(EntryFlight.velocity([(0.5, 0.0)]), 0)
    }

    /// A finger that held still at the end of the stroke isn't a flick: only the last few samples count.
    func testVelocityUsesOnlyTheLastSamples() {
        let v = EntryFlight.velocity([(0.0, 0.0), (0.6, 0.6), (0.6, 0.9), (0.62, 0.95)])
        XCTAssertEqual(v, (0.62 - 0.6) / 0.35, accuracy: 0.001)
    }
}
