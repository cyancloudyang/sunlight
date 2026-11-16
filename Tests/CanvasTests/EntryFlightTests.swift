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

    // MARK: Release momentum (Q6 — velocity via fly)

    /// A hand that sped up all the way to the lift is a flick, and the release keeps it: progress per
    /// second becomes the entry path's own units per second (one unit of progress is one path length),
    /// which is exactly what `fly` takes — it divides by the release path's own length itself
    /// (`Spring v0 = speed / length`), so nothing is divided here.
    func testReleaseSpeedCarriesAnAcceleratingFlick() {
        let samples: [(progress: CGFloat, time: CFTimeInterval)] = [(0.0, 0.0), (0.3, 0.08), (0.6, 0.15)]
        let v = EntryFlight.velocity(samples)
        XCTAssertGreaterThan(v, 0)
        let speed = EntryFlight.releaseSpeed(velocity: v, entryLength: 400)
        XCTAssertEqual(speed, v * 400, accuracy: 0.001)
        XCTAssertGreaterThan(speed, 0)   // same way the hand was going: in, toward the overview
    }

    /// Holding still and letting go is not a flick: the spring starts from rest, as it does today.
    func testReleaseSpeedIsZeroWhenTheHandHeldStill() {
        let still: [(progress: CGFloat, time: CFTimeInterval)] = [(0.5, 0.0), (0.5, 0.1), (0.5, 0.2)]
        let v = EntryFlight.velocity(still)
        XCTAssertEqual(v, 0, accuracy: 0.001)
        XCTAssertEqual(EntryFlight.releaseSpeed(velocity: v, entryLength: 400), 0, accuracy: 0.001)
    }

    /// Letting go on the way back out keeps the sign: the release starts off still carried outward, so
    /// it gives the camera back a little before coming home.
    func testReleaseSpeedKeepsTheSignOfARetractingHand() {
        let back: [(progress: CGFloat, time: CFTimeInterval)] = [(0.8, 0.0), (0.6, 0.1), (0.4, 0.2)]
        let speed = EntryFlight.releaseSpeed(velocity: EntryFlight.velocity(back), entryLength: 400)
        XCTAssertEqual(speed, -2.0 * 400, accuracy: 0.001)
    }

    /// A violent scrape can measure faster than the release can usefully fly: the carried rate is capped
    /// so a bad sample can't fling the camera past its target.
    func testReleaseSpeedIsCapped() {
        XCTAssertEqual(EntryFlight.releaseSpeed(velocity: 500, entryLength: 400),
                       EntryFlight.maxProgressRate * 400, accuracy: 0.001)
        XCTAssertEqual(EntryFlight.releaseSpeed(velocity: -500, entryLength: 400),
                       -EntryFlight.maxProgressRate * 400, accuracy: 0.001)
    }

    /// No measured path means nothing to carry: a release with no entry geometry starts from rest.
    func testReleaseSpeedWithoutAnEntryPathIsZero() {
        XCTAssertEqual(EntryFlight.releaseSpeed(velocity: 3, entryLength: 0), 0)
    }
}
