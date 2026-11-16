/// What Show Desktop reveals. The canvas's own floor is a snapshot of Finder's desktop the camera flies
/// to, the windows dimming over it (the default, and all that's possible without the system's help).
/// The real macOS desktop steps the canvas aside and triggers the system's own Show Desktop, so the
/// icons are the live, clickable ones.
enum DesktopReveal: Equatable {
    case canvasFloor
    case systemDesktop
}

enum ShowDesktopPolicy {
    /// Opt-in: off keeps the canvas floor (the working default); on reveals the real desktop. The real
    /// desktop needs the system's Show Desktop shortcut enabled (F11 by default) — see `Settings`.
    static func reveal(realDesktop: Bool) -> DesktopReveal {
        realDesktop ? .systemDesktop : .canvasFloor
    }
}