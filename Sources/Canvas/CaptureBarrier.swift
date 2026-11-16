import Foundation

/// A step that waits for a frame before it runs: the handoff resizes the real window and only then puts it
/// in front, and the proxy must have a picture of the new size before that — otherwise the app comes
/// forward showing its old picture at 1:1 for a frame, which reads as a flash. The way back is the same in
/// reverse: the frame of the window as it was in use lands before the window is shrunk back (`restoreFocus`).
///
/// It waits once: a handoff asks for one frame, and the timeout that guards it (or the window closing on
/// the way) runs the step instead. `act` twice is harmless — the controller's step checks it is still the
/// handoff's business.
@MainActor
struct CaptureBarrier {
    enum Step: Equatable {
        /// Wait for the frame; the step runs when it lands (`frameLanded`).
        case waitForFrame
        /// Nothing to wait for: the step runs now.
        case act
    }

    private(set) var isWaiting = false

    /// Whether the step should wait for a frame first. `needed` is false when no frame could differ (the
    /// real window isn't being resized, or there is nothing to photograph).
    mutating func begin(needed: Bool) -> Step {
        guard needed, !isWaiting else { return .act }
        isWaiting = true
        return .waitForFrame
    }

    /// The frame came, or never will: the step it was holding back runs.
    mutating func frameLanded() -> Step {
        guard isWaiting else { return .act }
        isWaiting = false
        return .act
    }
}
