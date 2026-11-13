import CoreGraphics

/// The geometry and policy of one gesture-driven entry: which cards fly, where each one starts and
/// ends, how far in it is, and whether letting go commits.
///
/// Deliberately no AppKit, no Core Animation, no view: the controller owns the showing and the spring,
/// this owns the numbers it shows. `from` is where a card has to sit on the canvas for the real window
/// to look like it hasn't moved — its real global origin seen through the entry camera — and `to` is
/// where the canvas remembers it (its stored world rect). One progress `t` moves the camera along the
/// path and every card along its own lerp, so the two never come apart.
enum EntryFlight {
    /// One window's card: from where it really is on screen, to where the canvas keeps it.
    struct Card: Equatable {
        let from: CGPoint
        let to: CGPoint
    }

    /// How far in the swipe has to get for a release to commit. Below it, letting go goes back.
    /// Tunable on the real device.
    static let commitThreshold: CGFloat = 0.5

    /// The cards that fly on entry.
    ///
    /// A card flies only if both ends are real: the window is on screen now (a frame with a size in
    /// `snapshot`) *and* the canvas has a place for it in `stored`. Everything else has nothing to fly
    /// between — a window off screen or minimised at entry has no real place to come from (it fades in
    /// where the canvas keeps it instead), and a window the canvas has never placed has nowhere to go.
    ///
    /// Origins only: world units are points at 1:1, so the size is the same at both ends.
    static func cards(snapshot: FrameSnapshot, stored: [CGWindowID: CGRect], insets: [CGWindowID: CGFloat],
                      camera: Camera) -> [CGWindowID: Card] {
        var cards: [CGWindowID: Card] = [:]
        for (id, storedRect) in stored {
            guard let frame = snapshot[id], FrameSnapshot.hasSize(frame) else { continue }
            let inset = insets[id] ?? 0
            let content = frame.insetBy(dx: inset, dy: inset)
            cards[id] = Card(from: camera.toWorld(content.origin), to: storedRect.origin)
        }
        return cards
    }

    /// The card's origin at progress `t`, clamped: the release spring overshoots about 4% past its end,
    /// and a card that rode that would breathe past its place (the camera may overshoot; the cards land).
    static func origin(_ card: Card, at t: CGFloat) -> CGPoint {
        let s = min(max(t, 0), 1)
        return CGPoint(x: card.from.x + (card.to.x - card.from.x) * s,
                       y: card.from.y + (card.to.y - card.from.y) * s)
    }

    /// Whether letting go at `progress` goes all the way in (or all the way back out).
    static func committed(progress: CGFloat, threshold: CGFloat) -> Bool {
        progress >= threshold
    }

    /// How fast the progress was moving as the fingers lifted, in progress per second: the release
    /// carries that on into the spring. Read from the last few samples only, so a hand that held still
    /// at the end of the stroke isn't read as a flick. Nil-safe: fewer than two samples is no velocity.
    static func velocity(_ samples: [(progress: CGFloat, time: CFTimeInterval)]) -> CGFloat {
        guard samples.count >= 2 else { return 0 }
        let recent = samples.suffix(3)
        guard let first = recent.first, let last = recent.last else { return 0 }
        return (last.progress - first.progress) / max(last.time - first.time, 0.001)
    }
}
