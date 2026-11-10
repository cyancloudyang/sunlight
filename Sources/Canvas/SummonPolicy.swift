/// When the map steps off the screen: another app took the front and no handoff is in flight. A
/// handoff activates its app on purpose — the map stays until the flight lands.
enum SummonPolicy {
    static func hidesOnResign(frontIsSelf: Bool, handoffInFlight: Bool) -> Bool {
        !frontIsSelf && !handoffInFlight
    }
}