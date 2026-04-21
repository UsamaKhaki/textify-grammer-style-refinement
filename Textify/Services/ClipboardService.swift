import AppKit

final class ClipboardService {
    private let pasteboard: NSPasteboard

    init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    /// Returns the clipboard text if present and not just whitespace, else nil.
    func readText() -> String? {
        guard let raw = pasteboard.string(forType: .string) else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : raw
    }

    /// Replace the pasteboard contents with the given string.
    func writeText(_ text: String) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
