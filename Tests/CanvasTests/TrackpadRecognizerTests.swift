import XCTest
@testable import Canvas

final class TrackpadRecognizerTests: XCTestCase {
    private let four: Set<Int32> = [1, 2, 3, 4]

    /// Feeds centroids (trackpad widths, y up) for one four-finger touch, then lifts; returns every phase.
    /// The frames are `interval` apart, so a ten-step path at the default is a quick stroke.
    private func touch(_ path: [CGPoint], interval: Double = 0.01, swipeUp: Bool = false) -> [TrackpadPan.Phase] {
        var r = TrackpadRecognizer()
        r.swipeUpSeesAll = swipeUp
        var phases: [TrackpadPan.Phase] = []
        for (i, p) in path.enumerated() {
            phases += r.update(device: 1, fingers: four, centroid: p, now: Double(i) * interval)
        }
        phases += r.update(device: 1, fingers: [], centroid: .zero, now: Double(path.count) * interval)
        return phases
    }

    private func line(from a: CGPoint, to b: CGPoint, steps: Int = 10) -> [CGPoint] {
        (0...steps).map { i in
            let t = CGFloat(i) / CGFloat(steps)
            return CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
        }
    }

    private func travel(in phases: [TrackpadPan.Phase]) -> [CGVector] {
        phases.compactMap { if case .changed(let v) = $0 { v } else { nil } }
    }

    // MARK: Tap

    /// Four fingers landing together at `at`, still for `held` seconds, then lifting together.
    private func tap(held: Double, at start: Double = 0, drift: CGFloat = 0) -> [TrackpadPan.Phase] {
        var r = TrackpadRecognizer()
        var phases: [TrackpadPan.Phase] = []
        phases += r.update(device: 1, fingers: four, centroid: CGPoint(x: 0.5, y: 0.5), now: start)
        phases += r.update(device: 1, fingers: four, centroid: CGPoint(x: 0.5 + drift, y: 0.5), now: start + held / 2)
        phases += r.update(device: 1, fingers: four, centroid: CGPoint(x: 0.5 + drift, y: 0.5), now: start + held)
        phases += r.update(device: 1, fingers: [1, 2], centroid: CGPoint(x: 0.5 + drift, y: 0.5), now: start + held + 0.01)
        phases += r.update(device: 1, fingers: [], centroid: .zero, now: start + held + 0.02)
        return phases
    }

    func testAFourFingerTapIsSeeAllOnce() {
        XCTAssertEqual(tap(held: 0.12), [.seeAll])
    }

    func testAHandRestingOnTheTrackpadIsNotATap() {
        XCTAssertEqual(tap(held: 0.6), [])
    }

    func testFingersThatShiftedAreNotATap() {
        XCTAssertFalse(tap(held: 0.12, drift: 0.05).contains(.seeAll))
    }

    func testAFourthFingerJoiningAThreeFingerTapLateIsNotATap() {
        var r = TrackpadRecognizer()
        var phases: [TrackpadPan.Phase] = []
        phases += r.update(device: 1, fingers: [1, 2, 3], centroid: CGPoint(x: 0.5, y: 0.5), now: 0)
        phases += r.update(device: 1, fingers: four, centroid: CGPoint(x: 0.5, y: 0.5), now: 0.25)
        phases += r.update(device: 1, fingers: [], centroid: .zero, now: 0.3)
        XCTAssertEqual(phases, [])
    }

    func testAQuickStrokeUpPansLikeAnyDrag() {
        let phases = touch(line(from: CGPoint(x: 0.5, y: 0.2), to: CGPoint(x: 0.51, y: 0.5)))
        XCTAssertEqual(phases.first, .began)
        XCTAssertEqual(phases.last, .ended)
        XCTAssertFalse(phases.contains(.seeAll))
        // Plumb: the slight lean doesn't creep sideways.
        XCTAssertTrue(travel(in: phases).allSatisfy { $0.dx == 0 && $0.dy < 0 })
    }

    func testStraightDownPansPlumb() {
        let phases = touch(line(from: CGPoint(x: 0.5, y: 0.5), to: CGPoint(x: 0.49, y: 0.2)))
        XCTAssertEqual(phases.first, .began)
        XCTAssertEqual(phases.last, .ended)
        XCTAssertFalse(phases.contains(.seeAll))
        // y down in the travel: the fingers went down the trackpad, so the content follows them down.
        XCTAssertTrue(travel(in: phases).allSatisfy { $0.dx == 0 && $0.dy > 0 })
    }

    func testAHandNudgingWithinTheSlopDoesNothing() {
        // Half a second on the trackpad, too long for a tap, moving less than the slop.
        let phases = touch(line(from: CGPoint(x: 0.5, y: 0.3), to: CGPoint(x: 0.5, y: 0.315)), interval: 0.05)
        XCTAssertEqual(phases, [])
    }

    // MARK: Swipe up (Settings › Trackpad)

    func testWithSwipeUpChosenAQuickStrokeUpBeginsEntryAndEndsIt() {
        let phases = touch(line(from: CGPoint(x: 0.5, y: 0.2), to: CGPoint(x: 0.51, y: 0.5)), swipeUp: true)
        XCTAssertEqual(phases.first, .began)
        XCTAssertEqual(phases.last, .entryEnded)
        XCTAssertEqual(phases.filter { $0 == .entryBegan }.count, 1)
        XCTAssertFalse(phases.contains(.seeAll))
        XCTAssertFalse(phases.contains(.ended))
        XCTAssertTrue(phases.contains { if case .entryProgress = $0 { true } else { false } })
    }

    func testWithSwipeUpChosenASlowSwipeUpStillBeginsEntry() {
        // Three seconds, far slower than a flick: a deliberate swipe up still opens the whole canvas.
        let phases = touch(line(from: CGPoint(x: 0.5, y: 0.1), to: CGPoint(x: 0.5, y: 0.8), steps: 30), interval: 0.1, swipeUp: true)
        XCTAssertEqual(phases.filter { $0 == .entryBegan }.count, 1)
        XCTAssertEqual(phases.last, .entryEnded)
    }

    func testEntryProgressRisesFromZeroToOneAndClamps() {
        // dragOrigin y=0.2; the entry begins at rise 0.035 (a hand's short stroke, not a shifting hand),
        // which is t=0 by definition, so the first frame it is seen on is near zero (and the camera does
        // not jump); full at rise 0.095 (t=1); past stays 1.
        let phases = touch(line(from: CGPoint(x: 0.5, y: 0.2), to: CGPoint(x: 0.5, y: 0.6), steps: 100), swipeUp: true)
        let ts = phases.compactMap { if case .entryProgress(let t) = $0 { t } else { nil } }
        XCTAssertEqual(ts.first ?? -1, 0, accuracy: 0.05)   // (one frame past the threshold at most)
        XCTAssertEqual(ts.last ?? -1, 1, accuracy: 0.001)
        XCTAssertTrue(zip(ts, ts.dropFirst()).allSatisfy { $0 <= $1 + 0.001 })  // monotonic up
        XCTAssertTrue(ts.allSatisfy { $0 >= 0 && $0 <= 1 })
    }

    func testEntryProgressScrubsBackWhenTheFingerReturns() {
        let up = line(from: CGPoint(x: 0.5, y: 0.2), to: CGPoint(x: 0.5, y: 0.45), steps: 10)
        let down = line(from: CGPoint(x: 0.5, y: 0.45), to: CGPoint(x: 0.5, y: 0.25), steps: 10)
        let ts = touch(up + down, swipeUp: true).compactMap { if case .entryProgress(let t) = $0 { t } else { nil } }
        XCTAssertGreaterThan(ts.max() ?? 0, ts.last ?? 1)  // came back down
    }

    func testWithSwipeUpChosenATapDoesNothing() {
        var r = TrackpadRecognizer()
        r.swipeUpSeesAll = true
        var phases: [TrackpadPan.Phase] = []
        phases += r.update(device: 1, fingers: four, centroid: CGPoint(x: 0.5, y: 0.5), now: 0)
        phases += r.update(device: 1, fingers: four, centroid: CGPoint(x: 0.5, y: 0.5), now: 0.1)
        phases += r.update(device: 1, fingers: [], centroid: .zero, now: 0.12)
        XCTAssertEqual(phases, [])
        XCTAssertFalse(phases.contains(.entryBegan))
    }

    func testWithSwipeUpChosenAHorizontalDragStillPans() {
        let phases = touch(line(from: CGPoint(x: 0.2, y: 0.5), to: CGPoint(x: 0.6, y: 0.52)), swipeUp: true)
        XCTAssertEqual(phases.first, .began)
        XCTAssertEqual(phases.last, .ended)
        XCTAssertFalse(phases.contains(.seeAll))
        XCTAssertFalse(phases.contains(.entryBegan))
    }

    func testWithSwipeUpChosenADiagonalDragStillPans() {
        let phases = touch(line(from: CGPoint(x: 0.2, y: 0.2), to: CGPoint(x: 0.5, y: 0.5)), swipeUp: true)
        XCTAssertEqual(phases.first, .began)
        XCTAssertFalse(phases.contains(.seeAll))
        XCTAssertFalse(phases.contains(.entryBegan))
    }

    // MARK: Real hands (A1/A2, 2026-11-16)

    /// Feeds one four-finger touch frame by frame, as the trackpad reports it: the time, the contacts
    /// still down, and the centroid. `stroke` below builds the frames of a hand's swipe.
    private func feed(_ list: [(Double, Set<Int32>, CGPoint)]) -> [TrackpadPan.Phase] {
        var r = TrackpadRecognizer()
        r.swipeUpSeesAll = true
        var phases: [TrackpadPan.Phase] = []
        for (now, ids, p) in list { phases += r.update(device: 1, fingers: ids, centroid: p, now: now) }
        return phases
    }

    /// A hand's swipe up from `start`: `rise` and `run` trackpad widths, over `steps` frames `interval`
    /// seconds apart, the first at `at`.
    private func stroke(from start: CGPoint, rise: CGFloat, run: CGFloat, steps: Int, at: Double = 0,
                        interval: Double = 0.008) -> [(Double, Set<Int32>, CGPoint)] {
        (0...steps).map { i in
            let f = CGFloat(i) / CGFloat(steps)
            return (at + Double(i) * interval, four, CGPoint(x: start.x + run * f, y: start.y + rise * f))
        }
    }

    private func progresses(_ phases: [TrackpadPan.Phase]) -> [CGFloat] {
        phases.compactMap { if case .entryProgress(let t) = $0 { t } else { nil } }
    }

    /// 2.2 cm up a built-in trackpad (0.167 widths), leaning 25° off vertical: the stroke a hand makes
    /// and the one the user's log showed moving the canvas a little instead of opening the overview.
    private func handSwipe(steps: Int = 40) -> [(Double, Set<Int32>, CGPoint)] {
        let rise: CGFloat = 0.167
        let run = rise * CGFloat(tan(25 * Double.pi / 180))
        return stroke(from: CGPoint(x: 0.5, y: 0.3), rise: rise, run: run, steps: steps)
    }

    func testAHandSwipeUpReachesWhatCommittedMeans() {
        let phases = feed(handSwipe() + [(0.34, Set<Int32>(), CGPoint.zero)])
        XCTAssertEqual(phases.filter { $0 == .entryBegan }.count, 1)
        let last = progresses(phases).last ?? 0
        XCTAssertTrue(EntryFlight.committed(progress: last, threshold: EntryFlight.commitThreshold))
    }

    func testAHandSwipeUpPulledBackOutGoesBackInstead() {
        var list = handSwipe(steps: 20)
        // The hand comes back down to a centimetre above where it started, then lifts.
        list += (0...20).map { i -> (Double, Set<Int32>, CGPoint) in
            let f = 1 - CGFloat(i) / 20
            return (0.17 + Double(i) * 0.008, four, CGPoint(x: 0.5 + 0.078 * f, y: 0.3 + 0.167 * f))
        }
        list.append((0.35, Set<Int32>(), CGPoint.zero))
        let phases = feed(list)
        XCTAssertEqual(phases.last, .entryEnded)
        XCTAssertLessThan(progresses(phases).last ?? 1, EntryFlight.commitThreshold)
    }

    func testAHandLandingItsFingersOneAtATimeStillBeginsTheEntry() {
        var list: [(Double, Set<Int32>, CGPoint)] = []
        let start = CGPoint(x: 0.5, y: 0.3)
        var now = 0.0
        for n in 1...3 {
            list.append((now, Set((1...n).map { Int32($0) }), start))
            now += 0.08   // a hand rolling on: the fourth lands 0.24 s after the first
        }
        list += stroke(from: start, rise: 0.167, run: 0.078, steps: 40, at: now)
        list.append((now + 0.34, Set<Int32>(), CGPoint.zero))
        let phases = feed(list)
        XCTAssertEqual(phases.filter { $0 == .entryBegan }.count, 1)
        XCTAssertEqual(phases.last, .entryEnded)
    }

    func testAFourthFingerJoiningHalfASecondLateIsNotASwipeUp() {
        // Look Up (three fingers) with a fourth added half a second later, then a swipe: not one hand.
        var list: [(Double, Set<Int32>, CGPoint)] = []
        let start = CGPoint(x: 0.5, y: 0.3)
        list.append((0, [1, 2, 3], start))
        list.append((0.25, [1, 2, 3], start))
        list.append((0.5, four, start))
        list += stroke(from: start, rise: 0.167, run: 0.078, steps: 40, at: 0.51)
        list.append((0.85, Set<Int32>(), CGPoint.zero))
        let phases = feed(list)
        XCTAssertFalse(phases.contains(.entryBegan))
        XCTAssertEqual(phases.last, .ended)
    }

    func testATransientContactDropDoesNotEndTheEntry() {
        // The trackpad reports three contacts for one frame two thirds of the way up: the same touch.
        var list = handSwipe()
        list[27].1 = [1, 2, 3]
        list.append((0.34, Set<Int32>(), CGPoint.zero))
        let phases = feed(list)
        XCTAssertEqual(phases.filter { $0 == .entryBegan }.count, 1)
        XCTAssertEqual(phases.filter { $0 == .entryEnded }.count, 1)
        XCTAssertEqual(phases.last, .entryEnded)
        XCTAssertFalse(phases.contains(.ended))
    }

    func testTheEntryKeepsItsProgressAcrossATransientContactDrop() {
        var list = handSwipe()
        list[24].1 = [1, 2, 3]
        list[25].1 = [1, 2, 3]
        list.append((0.34, Set<Int32>(), CGPoint.zero))
        let ts = progresses(feed(list))
        let before = ts.prefix { $0 < 0.3 }.last ?? 0
        XCTAssertGreaterThan(before, 0, "the entry is under way before the drop")
        XCTAssertGreaterThan(ts.last ?? 0, 0.7, "and goes on over the rest of the stroke")
        XCTAssertTrue(zip(ts, ts.dropFirst()).allSatisfy { $0 <= $1 + 0.001 }, "upwards throughout")
    }

    func testAContactLostForLongerThanTheGraceEndsTheEntry() {
        var list: [(Double, Set<Int32>, CGPoint)] = []
        let start = CGPoint(x: 0.5, y: 0.3)
        for i in 0...60 {
            let f = CGFloat(i) / 60
            // Thirteen frames without the fourth finger, 0.104 s: the hand has left, not the trackpad.
            list.append((Double(i) * 0.008, (38...50).contains(i) ? [1, 2, 3] : four,
                         CGPoint(x: start.x + 0.078 * f, y: start.y + 0.167 * f)))
        }
        list.append((0.50, Set<Int32>(), CGPoint.zero))
        let phases = feed(list)
        XCTAssertEqual(phases.filter { $0 == .entryBegan }.count, 1)
        XCTAssertEqual(phases.filter { $0 == .entryEnded }.count, 1)
        XCTAssertNotEqual(phases.last, .entryEnded)
    }

    func testANaturalSwipeUpEntersAndCommits() {
        // The rises the user's log showed for a hand's natural swipe up (0.070, 0.084, 0.100 widths):
        // each has to begin the entry, and the release has to be over the commit threshold, or the view
        // always went back out and the swipe up never opened anything.
        for rise in [CGFloat(0.070), 0.084, 0.100] {
            let phases = feed(stroke(from: CGPoint(x: 0.5, y: 0.3), rise: rise, run: rise * 0.35, steps: 20)
                              + [(0.30, Set<Int32>(), CGPoint.zero)])
            XCTAssertEqual(phases.filter { $0 == .entryBegan }.count, 1, "rise \(rise)")
            XCTAssertEqual(phases.last, .entryEnded, "rise \(rise)")
            let last = progresses(phases).last ?? 0
            XCTAssertTrue(EntryFlight.committed(progress: last, threshold: EntryFlight.commitThreshold),
                          "rise \(rise) released at t \(last)")
        }
        // 0.047, the shortest the log showed: a light push, short of the halfway point — it goes back.
        let light = feed(stroke(from: CGPoint(x: 0.5, y: 0.3), rise: 0.047, run: 0.016, steps: 12)
                         + [(0.30, Set<Int32>(), CGPoint.zero)])
        XCTAssertEqual(light.filter { $0 == .entryBegan }.count, 1)
        XCTAssertLessThan(progresses(light).last ?? 1, EntryFlight.commitThreshold)
    }

    func testAnUpwardSwipePullsBackFromTheStartWithoutPanningFirst() {
        // The report: the window slid up unscaled, and only then did the view pull back. The pan came
        // first, on the frames before the swipe was recognised. A hand's swipe up is the entry from its
        // first frame: not one .changed on the way.
        let phases = feed(handSwipe() + [(0.34, Set<Int32>(), CGPoint.zero)])
        XCTAssertTrue(travel(in: phases).isEmpty, "the canvas never panned: \(travel(in: phases))")
        guard let began = phases.firstIndex(of: .began),
              let entrance = phases.firstIndex(of: .entryBegan) else {
            return XCTFail("no swipe up in \(phases)")
        }
        // Right behind the drag's onset: a few frames of the hand's travel, not a stroke's length.
        XCTAssertLessThanOrEqual(entrance - began, 6, "the entry begins with the hand, not after a pan")
        let ts = progresses(phases)
        XCTAssertEqual(ts.first ?? -1, 0, accuracy: 0.05, "and from the camera it was already on")
        XCTAssertTrue(zip(ts, ts.dropFirst()).allSatisfy { $0 <= $1 + 0.001 }, "upwards throughout")
    }

    func testAnUpwardPushUnderTheRecognitionDistanceHoldsTheCanvasStill() {
        // Two millimetres up, a tenth of a trackpad width: under the rise a swipe up needs. Not a pan
        // either — the canvas waits for the hand to say which it is, so no entry ever starts from a
        // canvas another frame of the same touch has already moved.
        var list = stroke(from: CGPoint(x: 0.5, y: 0.3), rise: 0.02, run: 0.01, steps: 10)
        list.append((0.20, Set<Int32>(), CGPoint.zero))
        let phases = feed(list)
        XCTAssertEqual(phases.first, .began)
        XCTAssertEqual(phases.last, .ended)
        XCTAssertFalse(phases.contains { if case .changed = $0 { true } else { false } })
        XCTAssertFalse(phases.contains(.entryBegan))
    }

    // MARK: Drag

    func testHorizontalDragPansLevel() {
        let phases = touch(line(from: CGPoint(x: 0.2, y: 0.5), to: CGPoint(x: 0.6, y: 0.55)))
        XCTAssertEqual(phases.first, .began)
        XCTAssertEqual(phases.last, .ended)
        let travel = travel(in: phases)
        XCTAssertFalse(travel.isEmpty)
        XCTAssertTrue(travel.allSatisfy { $0.dy == 0 && $0.dx > 0 })
        XCTAssertFalse(phases.contains(.seeAll))
    }

    func testDiagonalDragPansFreely() {
        let phases = touch(line(from: CGPoint(x: 0.2, y: 0.2), to: CGPoint(x: 0.5, y: 0.5)))
        XCTAssertEqual(phases.first, .began)
        XCTAssertTrue(phases.contains { if case .changed(let v) = $0 { v.dx > 0 && v.dy < 0 } else { false } })
        XCTAssertFalse(phases.contains(.seeAll))
    }

    // MARK: Spread

    /// One four-finger touch with the centroid held still and the fingers' spread going from `a` to `b`.
    private func spreading(from a: CGFloat, to b: CGFloat, steps: Int = 10) -> [TrackpadPan.Phase] {
        var r = TrackpadRecognizer()
        var phases: [TrackpadPan.Phase] = []
        for i in 0...steps {
            let spread = a + (b - a) * CGFloat(i) / CGFloat(steps)
            phases += r.update(device: 1, fingers: four, centroid: CGPoint(x: 0.5, y: 0.3), spread: spread, now: 0)
        }
        phases += r.update(device: 1, fingers: [], centroid: .zero, now: 0)
        return phases
    }

    func testSpreadingTheFingersIsShowDesktopOnce() {
        XCTAssertEqual(spreading(from: 0.06, to: 0.3), [.spread])
    }

    func testPinchingThemTogetherDoesNothing() {
        XCTAssertEqual(spreading(from: 0.3, to: 0.06), [])
    }

    func testASmallSpreadIsNotOne() {
        XCTAssertEqual(spreading(from: 0.1, to: 0.13), [])
    }

    /// A thumb and three fingers on a 16 cm trackpad, measured as `TrackpadPan.frame` measures them:
    /// the thumb moves down and left, the fingers up and right, each point by `cm` centimetres.
    private func hand(parted cm: CGFloat) -> (centroid: CGPoint, spread: CGFloat) {
        let w: CGFloat = 16
        let d = cm / w
        let points = [CGPoint(x: 0.40 - d * 0.7, y: 0.30 - d * 0.7),
                      CGPoint(x: 0.50 + d * 0.3, y: 0.55 + d * 0.9),
                      CGPoint(x: 0.58 + d * 0.5, y: 0.58 + d * 0.8),
                      CGPoint(x: 0.66 + d * 0.8, y: 0.54 + d * 0.6)]
        let c = CGPoint(x: points.map(\.x).reduce(0, +) / 4, y: points.map(\.y).reduce(0, +) / 4)
        let s = points.map { hypot($0.x - c.x, $0.y - c.y) }.reduce(0, +) / 4
        return (c, s)
    }

    func testARealHandSpreadingTwoCentimetresIsShowDesktop() {
        var r = TrackpadRecognizer()
        var phases: [TrackpadPan.Phase] = []
        for i in 0...10 {
            let h = hand(parted: 2 * CGFloat(i) / 10)
            phases += r.update(device: 1, fingers: four, centroid: h.centroid, spread: h.spread, now: Double(i) * 0.02)
        }
        phases += r.update(device: 1, fingers: [], centroid: .zero, now: 0.3)
        XCTAssertEqual(phases, [.spread])
    }

    func testAPanWithTheHandHeldTheSameStillPans() {
        var r = TrackpadRecognizer()
        var phases: [TrackpadPan.Phase] = []
        for p in line(from: CGPoint(x: 0.2, y: 0.5), to: CGPoint(x: 0.6, y: 0.5)) {
            phases += r.update(device: 1, fingers: four, centroid: p, spread: 0.1, now: 0)
        }
        XCTAssertEqual(phases.first, .began)
        XCTAssertFalse(phases.contains(.spread))
    }
}

extension TrackpadRecognizerTests {
    /// Sunlight off: the Mac's own four-finger swipes go through, so the Dock-control events aren't dropped.
    func testDockControlIsLeftAloneWhileInactive() {
        var r = TrackpadRecognizer()
        r.active = false
        _ = r.update(device: 1, fingers: [1, 2, 3, 4], centroid: CGPoint(x: 0.5, y: 0.5), now: 10)
        XCTAssertEqual(r.dropDockControlUntil, 0)
        var on = TrackpadRecognizer()
        _ = on.update(device: 1, fingers: [1, 2, 3, 4], centroid: CGPoint(x: 0.5, y: 0.5), now: 10)
        XCTAssertGreaterThan(on.dropDockControlUntil, 10)
    }
}
