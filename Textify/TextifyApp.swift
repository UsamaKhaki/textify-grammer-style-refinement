import SwiftUI

@main
struct TextifyApp: App {
    @StateObject private var coordinator = AppCoordinator()
    @StateObject private var settings = SettingsStore.shared

    var body: some Scene {
        MenuBarExtra("Textify", systemImage: "t.square") {
            Button("Refine clipboard") { coordinator.onHotkey() }
                .keyboardShortcut("t", modifiers: [.command, .shift])
            Divider()
            Button("Settings…") { coordinator.openSettings() }
                .keyboardShortcut(",")
            Divider()
            Button("Quit Textify") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        }

        Settings {
            SettingsWindow()
                .environmentObject(settings)
        }
    }
}
