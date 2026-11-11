import Foundation

/// Stage Manager, as Diagnose sees it. Read only.
///
/// An earlier Sunlight turned Stage Manager off while it ran (`com.apple.WindowManager GloballyEnabled`)
/// because the two can't share a Mac: with it on, macOS hides every other app's windows into the strip
/// whenever one app comes forward. The snapshots-on-a-map canvas has no such argument with it, so
/// Tablecloth reads the setting and reports it, and changes nothing.
enum StageManager {
    static let domain = "com.apple.WindowManager"
    static let key = "GloballyEnabled"
    /// In Sunlight's own defaults: an earlier version turned it off and meant to turn it back on.
    static let turnedOffKey = "stageManager.turnedOff"

    /// Where the switch and the old note about it live. The real Mac's in `.mac`; tests pass their own.
    struct Store {
        var read: () -> Bool
        var turnedOff: () -> Bool

        static var mac: Store {
            Store(read: {
                      CFPreferencesAppSynchronize(domain as CFString)
                      return CFPreferencesGetAppBooleanValue(key as CFString, domain as CFString, nil)
                  },
                  turnedOff: { UserDefaults.standard.bool(forKey: turnedOffKey) })
        }
    }

    /// Stage Manager is on right now.
    static func isOn(_ store: Store = .mac) -> Bool { store.read() }

    /// An earlier Sunlight turned it off and meant to turn it back on.
    static func turnedOffBySunlight(_ store: Store = .mac) -> Bool { store.turnedOff() }

    /// One line for Diagnose and `--status`.
    static func describe(on: Bool, turnedOffBySunlight: Bool) -> String {
        switch (on, turnedOffBySunlight) {
        case (true, _): return "on"
        case (false, true): return "off, turned off by an earlier Sunlight; turn it back on in Control Center if you want it"
        case (false, false): return "off"
        }
    }

    static func describeCurrent(_ store: Store = .mac) -> String {
        describe(on: store.read(), turnedOffBySunlight: store.turnedOff())
    }
}
