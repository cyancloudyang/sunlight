import AppKit
import Carbon.HIToolbox

enum BookmarkKey {
    enum Action: Equatable { case jump(Int), save(Int) }

    static func action(keyCode: Int, modifiers: NSEvent.ModifierFlags) -> Action? {
        let keys = [kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3, kVK_ANSI_4, kVK_ANSI_5,
                    kVK_ANSI_6, kVK_ANSI_7, kVK_ANSI_8, kVK_ANSI_9]
        guard let index = keys.firstIndex(of: keyCode) else { return nil }
        let flags = modifiers.intersection([.command, .option, .control, .shift])
        switch flags {
        case []: return .jump(index + 1)
        case .control: return .save(index + 1)
        default: return nil
        }
    }
}
