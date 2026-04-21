import SwiftUI

@main
struct TextifyApp: App {
    var body: some Scene {
        MenuBarExtra("Textify", systemImage: "t.square") {
            Button("Quit") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        }
    }
}
