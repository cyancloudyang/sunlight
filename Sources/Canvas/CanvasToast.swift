import AppKit

/// A line over the canvas that fades after a moment: a bookmark saved, the add-on paused. A glass
/// card centred along the top.
@MainActor
enum CanvasToast {
    private static let margin: CGFloat = 12

    static func show(_ message: String, in overlay: NSView, for seconds: TimeInterval = 4) {
        let label = Chrome.label(message, size: 13, weight: .medium)
        let size = label.fittingSize
        let height: CGFloat = 36
        let width = min(size.width + 32, overlay.bounds.width - 2 * margin)
        let card = NSView(frame: CGRect(x: (overlay.bounds.width - width) / 2, y: margin, width: width, height: height))
        card.wantsLayer = true
        card.layer?.backgroundColor = Chrome.card.cgColor
        card.layer?.cornerRadius = height / 2
        card.layer?.borderWidth = 1
        card.layer?.borderColor = Chrome.hairline.cgColor
        Chrome.glass(behind: card, radius: height / 2)
        label.frame = CGRect(x: 16, y: (height - size.height) / 2, width: width - 32, height: size.height)
        label.alignment = .center
        card.addSubview(label)
        card.alphaValue = 0
        overlay.addSubview(card)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            card.animator().alphaValue = 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
            MainActor.assumeIsolated {
                NSAnimationContext.runAnimationGroup({ context in
                    context.duration = 0.6
                    card.animator().alphaValue = 0
                }, completionHandler: {
                    MainActor.assumeIsolated { card.removeFromSuperview() }
                })
            }
        }
    }
}