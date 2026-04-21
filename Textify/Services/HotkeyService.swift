import KeyboardShortcuts
import AppKit

extension KeyboardShortcuts.Name {
    static let refineClipboard = Self("refineClipboard", default: .init(.t, modifiers: [.command, .shift]))
}

final class HotkeyService {
    /// Register an action to run each time the global hotkey fires.
    /// KeyboardShortcuts.onKeyUp delivers on the main thread.
    init(onTriggered: @escaping () -> Void) {
        KeyboardShortcuts.onKeyUp(for: .refineClipboard, action: onTriggered)
    }
}
