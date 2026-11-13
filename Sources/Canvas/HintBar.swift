import AppKit

enum HintPolicy {
    // The shortcuts stay on screen for as long as the map is up: the user asked to always see them.
    static func shows(mapEntriesSeen: Int) -> Bool { true }
}

@MainActor
final class HintBar: NSView {
    private let label = Chrome.label("滚轮缩放 · 拖拽平移 · 点击聚焦 · F3 返回 · 1–9 书签", size: 12)
    private var shown = false
    private var transition = 0

    init() {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = Chrome.card.cgColor
        layer?.cornerRadius = 18
        layer?.borderWidth = 1
        layer?.borderColor = Chrome.hairline.cgColor
        Chrome.glass(behind: self, radius: 18)
        label.alignment = .center
        addSubview(label)
        isHidden = true
    }

    required init?(coder: NSCoder) { fatalError() }
    override var isFlipped: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    func place(in visible: CGRect) {
        let width = min(label.fittingSize.width + 32, max(0, visible.width - 2 * (MinimapPanel.size.width + 24)))
        frame = CGRect(x: visible.midX - width / 2, y: visible.maxY - 48, width: width, height: 36)
        label.frame = bounds.insetBy(dx: 16, dy: 9)
    }

    func setShown(_ value: Bool) {
        guard value != shown, let layer else { return }
        shown = value
        transition += 1
        let current = transition
        let from = isHidden ? 0 : layer.presentation()?.opacity ?? layer.opacity
        layer.removeAnimation(forKey: "hint.fade")
        if value { isHidden = false }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        CATransaction.setCompletionBlock { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.transition == current, !value else { return }
                self.isHidden = true
            }
        }
        layer.opacity = value ? 1 : 0
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = from
        fade.toValue = layer.opacity
        fade.duration = 0.25
        layer.add(fade, forKey: "hint.fade")
        CATransaction.commit()
    }
}
