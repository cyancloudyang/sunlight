import Foundation
import CoreGraphics

/// A layout restore opens apps and their windows come back a few at a time, while every entry of the
/// layout is known from the start. Placing each batch against what was still open let the arrival order
/// decide: two windows of the same title, the second one arriving first, were given each other's places,
/// and the same two arriving together were given them by window ID — two different canvases for the same
/// set of windows (#10 in the handoff).
///
/// So the places given out are matched again against the whole picture every time a batch arrives, and a
/// window that the picture now puts somewhere else is moved there. The window the user has moved since is
/// theirs and keeps what it holds (`userHasMoved`), which is also what keeps a later batch from undoing a
/// gesture.
@MainActor
enum RestorePlacement {
    struct Result: Equatable {
        /// Which entry each window should hold now. A window whose entry is unchanged isn't listed.
        var moves: [CGWindowID: Int]
        /// The entries that now have a window: the rest stay open for windows still coming.
        var filled: Set<Int>
    }

    /// - kept: the entry each window on the canvas holds now, as this restore gave it out.
    /// - pairing: what the whole picture says, surest first (`Layout.match` over every entry still open or
    ///   given out, and every window that could fill one).
    /// - pinned: windows the user has moved since: they keep their entry, and their entry stays taken.
    static func reconcile(kept: [CGWindowID: Int], pairing: [(entry: Int, window: CGWindowID)],
                          pinned: Set<CGWindowID>) -> Result {
        var moves: [CGWindowID: Int] = [:]
        var filled = Set<Int>()

        // What the user placed is theirs: it keeps its entry, and that entry is taken.
        for (window, entry) in kept where pinned.contains(window) {
            filled.insert(entry)
        }

        // Then the picture's own order, surest first. An entry already taken is out, and so is a window the
        // user has moved: the pairing never overrides a gesture.
        for pair in pairing where !filled.contains(pair.entry) && !pinned.contains(pair.window) {
            if kept[pair.window] != pair.entry {
                moves[pair.window] = pair.entry
            }
            filled.insert(pair.entry)
        }
        return Result(moves: moves, filled: filled)
    }

    /// Whether the window is no longer where the restore put it: one moved by more than a point is the
    /// user's, and a later batch leaves it alone. `placedAt` is nil for a window the restore didn't place.
    static func userHasMoved(placedAt: CGPoint?, now: CGPoint) -> Bool {
        guard let placedAt else { return false }
        return hypot(now.x - placedAt.x, now.y - placedAt.y) > 1
    }
}
