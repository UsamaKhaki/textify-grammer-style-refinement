import SwiftUI
import AppKit

@MainActor
final class AppCoordinator: ObservableObject {
    let settings: SettingsStore
    private let clipboard = ClipboardService()
    private let keychain = KeychainStore()
    private var hotkey: HotkeyService?
    private var refinementWindow: NSWindow?

    init(settings: SettingsStore = .shared) {
        self.settings = settings
        self.hotkey = HotkeyService { [weak self] in
            MainActor.assumeIsolated { self?.onHotkey() }
        }
    }

    /// Menu-bar / hotkey entry point. Reads clipboard, opens a refinement window.
    func onHotkey() {
        let text = clipboard.readText()
        showRefinementWindow(initialText: text)
    }

    private func makeProvider(for kind: ProviderKind) -> RefinementProvider {
        let key = try? keychain.load(for: kind)
        switch kind {
        case .gemini:    return GeminiProvider(apiKey: key)
        case .openai:    return OpenAIProvider(apiKey: key)
        case .groq:      return GroqProvider(apiKey: key)
        case .anthropic: return AnthropicProvider(apiKey: key)
        }
    }

    func showRefinementWindow(initialText: String?) {
        // Close any existing window first so hot-pressing ⌘⇧T doesn't stack them.
        refinementWindow?.close()

        let vm = RefinementViewModel(
            clipboardText: initialText,
            providerKindResolver: { [settings] in settings.selectedProvider },
            providerFactory: { [weak self] kind in
                self?.makeProvider(for: kind) ?? GeminiProvider(apiKey: nil)
            }
        )

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 440),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.center()
        window.title = "Textify"
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true

        vm.onPick = { [weak self, weak window] chosen in
            self?.clipboard.writeText(chosen)
            if self?.settings.closeAfterCopy ?? true {
                window?.close()
            }
        }

        let root = RefinementWindow(
            vm: vm,
            openSettings: { [weak self] in self?.openSettings() },
            close: { [weak window] in window?.close() }
        )
        .environmentObject(settings)

        let hosting = NSHostingController(rootView: root)
        window.contentViewController = hosting
        refinementWindow = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)

        // Auto-kick refinement if we started from clipboard.
        if initialText != nil {
            Task { await vm.refine() }
        }
    }

    func openSettings() {
        if #available(macOS 14, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }
}
