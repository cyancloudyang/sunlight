import AppKit
import ApplicationServices

/// The two permissions the canvas asks for, and what it may do with each. Nothing else belongs here:
/// Tablecloth never changes system preferences, login items or other apps' settings, so a missing
/// permission is answered with the wizard's own page, never with a prompt to reshape the Mac.
struct PermissionGate: Equatable {
    var accessibility: Bool = false
    var screenRecording: Bool = false

    /// The Mac as it stands, read fresh each time: a grant made in System Settings has to be seen
    /// without a relaunch where the system allows it.
    static func current() -> PermissionGate {
        PermissionGate(accessibility: AXIsProcessTrusted(), screenRecording: CGPreflightScreenCaptureAccess())
    }

    /// The work that needs a permission. `.map` covers showing the canvas at all: it is snapshots, so
    /// without Screen Recording there is no map to show, not an empty one.
    enum Work: CaseIterable {
        case map, listWindows, snapshot, widgets, focus
    }

    func allows(_ work: Work) -> Bool {
        switch work {
        case .map, .listWindows, .snapshot: return screenRecording
        case .widgets, .focus: return accessibility
        }
    }

    /// The wizard page for the first permission that's missing, in the wizard's order.
    var missingPage: SetupFlow.Page? {
        if !accessibility { return .accessibility }
        if !screenRecording { return .screenRecording }
        return nil
    }

    /// What changed between two readings, as the canvas has to answer it: start or stop the input and
    /// the capture, and put a map that can no longer refresh itself away.
    struct Change {
        let startInput: Bool
        let stopInput: Bool
        let startCapture: Bool
        let stopCapture: Bool
        let hideMap: Bool

        init(from old: PermissionGate, to new: PermissionGate) {
            startInput = !old.accessibility && new.accessibility
            stopInput = old.accessibility && !new.accessibility
            startCapture = !old.screenRecording && new.screenRecording
            stopCapture = old.screenRecording && !new.screenRecording
            // The map is snapshots of other apps' windows: without the grant nothing can be freshened.
            hideMap = old.screenRecording && !new.screenRecording
        }

        var anything: Bool { startInput || stopInput || startCapture || stopCapture }
    }
}
