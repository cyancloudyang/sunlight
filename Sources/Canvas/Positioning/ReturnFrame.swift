import CoreGraphics

/// The native frame the return to the map places the entered window by.
///
/// The window server's listing comes first: about a millisecond, and it never waits on the app. An
/// Accessibility frame is a round trip to a process that can be busy for the whole messaging timeout
/// (a second), holding the main thread — and the return flight — with it (measured 1336 ms on a busy
/// Weather). So Accessibility is only the fallback, which the caller reads lazily (`?? p.ax?.frame`)
/// when the listing can't place the window: no entry for it (Calendar's, at times, has none), or an
/// empty frame (a window mid-teardown, `FrameSnapshot.hasSize`).
enum ReturnFrame {
    /// The listing's frame when it's a real one, else nil so the caller falls back to Accessibility.
    static func fromListing(_ frame: CGRect?) -> CGRect? {
        guard let frame, FrameSnapshot.hasSize(frame) else { return nil }
        return frame
    }
}