/// When the map captures: only while it's on screen, and only for what an event asks for.
/// Hidden, idle with rotation off, asleep — nothing captures at all.
enum RefreshPolicy {
    enum Event { case mapShown, cameraSettled, focusReturned, tick }
    enum Action: Equatable { case refreshVisible, refreshPrimary, rotateOne }

    static func actions(for event: Event, mapVisible: Bool, rotationEnabled: Bool,
                        handoffInFlight: Bool) -> [Action] {
        guard mapVisible else { return [] }
        switch event {
        case .mapShown, .cameraSettled: return [.refreshVisible]
        case .focusReturned: return [.refreshPrimary]
        case .tick:
            if handoffInFlight { return [.refreshPrimary] }
            return rotationEnabled ? [.rotateOne] : []
        }
    }
}