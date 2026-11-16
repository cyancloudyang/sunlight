import AppKit

/// What an earlier Sunlight changed on the Mac: a handful of Dock, Finder and widget preferences, and the
/// snapshot it took before writing them. Read only now — Tablecloth changes no preference — kept so the
/// uninstall can tell what a snapshot still owes back (#1 in the handoff).
enum SystemPrefs {
    struct Pref {
        let domain: String
        let key: String
        /// nil is what an earlier takeover deleted, so the system default applied.
        let desired: Any?
        var id: String { "\(domain)|\(key)" }
    }

    static let dock = "com.apple.dock"
    static let finder = "com.apple.finder"
    static let widgets = "com.apple.widgets"
    static let absent = "<absent>"

    static let managed: [Pref] = [
        // The Dock: auto-hide only. It still slides out at the screen edge after the system's own delay;
        // clearing the delay also undoes the never-ending one an earlier build wrote (or one set by hand).
        Pref(domain: dock, key: "autohide", desired: true),
        Pref(domain: dock, key: "autohide-delay", desired: nil),
        // Mission Control, App Exposé and Show Desktop: gestures and hot corners can't be swallowed by a key tap.
        Pref(domain: dock, key: "showMissionControlGestureEnabled", desired: false),
        Pref(domain: dock, key: "showAppExposeGestureEnabled", desired: false),
        Pref(domain: dock, key: "showDesktopGestureEnabled", desired: false),
        Pref(domain: dock, key: "wvous-tl-corner", desired: 1),
        Pref(domain: dock, key: "wvous-tr-corner", desired: 1),
        Pref(domain: dock, key: "wvous-bl-corner", desired: 1),
        Pref(domain: dock, key: "wvous-br-corner", desired: 1),
        // Managed-preferences switch for Mission Control; honoured on some releases, harmless on others.
        Pref(domain: dock, key: "mcx-expose-disabled", desired: true),
        // Widgets: never dimmed. Notification Center dims desktop widgets to monochrome whenever an app is
        // in front of the desktop, and the canvas always is, so every widget proxy would be grey. This is
        // Desktop & Dock › Dim widgets on desktop: 0 Automatically, 1 Never, 2 Always. No restart:
        // System Settings changes it without one and posts no notification for it (unlike the Dock's
        // `com.apple.dock.prefchanged`), so Notification Center watches the key itself.
        Pref(domain: widgets, key: "widgetAppearance", desired: 1),
    ]

    /// Prefs takeover used to manage and no longer does. A Mac taken over by an earlier build has
    /// takeover's value in force and the user's own in the snapshot: the next apply puts the user's back
    /// and drops it from the snapshot (`retiredInSnapshot`), and a revert puts it back as well.
    static let retired: [Pref] = [
        // Finder's desktop icons, off until the desktop came back as the canvas's floor (`DesktopFloor`).
        Pref(domain: finder, key: "CreateDesktop", desired: false),
    ]

    static func current(_ p: Pref) -> Any? {
        CFPreferencesCopyAppValue(p.key as CFString, p.domain as CFString)
    }

    /// Records the current value of every managed pref not already in `existing`. A pref added to
    /// `managed` since takeover was first applied still holds the user's own value, so recording it on
    /// the next apply is as good as having recorded it then.
    static func snapshot(adding existing: [String: Any] = [:]) -> [String: Any] {
        var s = existing
        for p in managed where s[p.id] == nil { s[p.id] = current(p) ?? absent }
        return s
    }

    /// The retired prefs a snapshot still holds, each with the user's own value to put back (nil: the key
    /// was absent), and the snapshot without them.
    static func retiredInSnapshot(_ snapshot: [String: Any]) -> (restore: [(Pref, Any?)], remaining: [String: Any]) {
        var remaining = snapshot
        var restore: [(Pref, Any?)] = []
        for p in retired {
            guard let saved = remaining.removeValue(forKey: p.id) else { continue }
            restore.append((p, (saved as? String) == absent ? nil : saved))
        }
        return (restore, remaining)
    }

    static func describeCurrent() -> String {
        managed.map { p in
            let v = current(p).map { "\($0)" } ?? absent
            return "  \(p.domain) \(p.key) = \(v)"
        }.joined(separator: "\n")
    }
}
