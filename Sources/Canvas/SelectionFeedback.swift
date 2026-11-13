import AppKit

/// The name plate as the zoom and hover now are, as a pure function: a unit's banner from far out,
/// the small title near, nothing at 1:1 where the real window's title bar takes over. Hovering a
/// window names it at any zoom — the preselect reads as a unit's tooltip.
enum LabelPolicy {
    enum Mode { case hidden, compact, banner }

    static func mode(zoom: CGFloat, hovered: Bool) -> Mode {
        if hovered { return .compact }
        if zoom < 0.35 { return .banner }
        if zoom < 0.8 { return .compact }
        return .hidden
    }
}

/// The selection ring: a unit-command feedback, drawn once per event and gone in half a second.
/// No timers, no state — a keyframe animation that removes its own layer.
enum SelectionFeedback {
    /// The ring's rect around a frame: a constant outset, in the frame's own units.
    static func ringRect(for frame: CGRect) -> CGRect {
        frame.insetBy(dx: -6, dy: -6)
    }

    /// A ring pulsing outward around the proxy and fading — "here it is" on arrival and on return.
    @MainActor static func pulse(on proxy: WindowProxy) {
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
        let rect = ringRect(for: proxy.layer.bounds)
        let ring = CAShapeLayer()
        ring.frame = rect
        let radius = proxy.layer.cornerRadius + 6
        ring.path = CGPath(roundedRect: CGRect(origin: .zero, size: rect.size), cornerWidth: radius, cornerHeight: radius, transform: nil)
        ring.fillColor = nil
        ring.strokeColor = NSColor.controlAccentColor.cgColor
        ring.lineWidth = 2 / max(proxy.lastZoom, 0.05)   // about two pixels on screen at any zoom
        ring.zPosition = 2
        proxy.layer.addSublayer(ring)

        let grow = CABasicAnimation(keyPath: "transform.scale")
        grow.fromValue = 1
        grow.toValue = 1.12
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0.9
        fade.toValue = 0
        let pulse = CAAnimationGroup()
        pulse.animations = [grow, fade]
        pulse.duration = 0.6
        pulse.timingFunction = CAMediaTimingFunction(name: .easeOut)
        CATransaction.begin()
        CATransaction.setCompletionBlock { ring.removeFromSuperlayer() }
        ring.add(pulse, forKey: "pulse")
        CATransaction.commit()
    }
}