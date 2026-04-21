import SwiftUI
import AppKit
import KeyboardShortcuts
import ServiceManagement

struct SettingsWindow: View {
    var body: some View {
        TabView {
            GeneralTab().tabItem { Label("General", systemImage: "gearshape") }
            ProviderTab().tabItem { Label("AI Provider", systemImage: "cpu") }
            ThemeTab().tabItem { Label("Theme", systemImage: "paintpalette") }
            AboutTab().tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 520, height: 460)
        .padding(20)
        .onAppear {
            // LSUIElement apps need explicit activation so keyboard events
            // (including ⌘V for pasting the API key) reach this window.
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

private struct GeneralTab: View {
    @EnvironmentObject private var settings: SettingsStore
    var body: some View {
        Form {
            Section {
                Toggle("Close window after copy", isOn: $settings.closeAfterCopy)
                Toggle("Launch at login", isOn: Binding(
                    get: { settings.launchAtLogin },
                    set: { newValue in
                        settings.launchAtLogin = newValue
                        applyLaunchAtLogin(newValue)
                    }
                ))
            }
            Section("Global hotkey") {
                KeyboardShortcuts.Recorder(for: .refineClipboard)
            }
        }
        .formStyle(.grouped)
    }

    private func applyLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else       { try SMAppService.mainApp.unregister() }
        } catch {
            // Surface silently for v1. User can retry via the toggle.
            NSLog("Launch-at-login toggle failed: \(error)")
        }
    }
}

private struct ProviderTab: View {
    @EnvironmentObject private var settings: SettingsStore
    @State private var keys: [ProviderKind: String] = [:]
    @State private var testMessage: String?
    @State private var testMessageIsError = false
    @State private var testing = false

    private let store = KeychainStore()

    var body: some View {
        Form {
            Picker("Provider", selection: $settings.selectedProvider) {
                ForEach(ProviderKind.allCases) { kind in
                    Text(kind.displayName).tag(kind)
                }
            }
            Section("API key for \(settings.selectedProvider.displayName)") {
                HStack {
                    SecureField("Paste your key", text: Binding(
                        get: { keys[settings.selectedProvider] ?? "" },
                        set: { keys[settings.selectedProvider] = $0 }
                    ))
                    Button("Paste") { pasteFromClipboard() }
                }
                HStack {
                    Button("Save") { save() }
                    Button("Test key") { Task { await test() } }
                        .disabled(testing || (keys[settings.selectedProvider]?.isEmpty ?? true))
                    if let msg = testMessage {
                        Text(msg).foregroundStyle(testMessageIsError ? .red : .green).font(.callout)
                    }
                }
            }
            if settings.selectedProvider == .gemini {
                Link("Get a free Gemini key →", destination: URL(string: "https://aistudio.google.com/app/apikey")!)
            }
            if settings.selectedProvider == .anthropic {
                Link("Get an Anthropic API key →", destination: URL(string: "https://console.anthropic.com/settings/keys")!)
            }
        }
        .formStyle(.grouped)
        .onAppear { loadKeyForCurrent() }
        .onChange(of: settings.selectedProvider) {
            testMessage = nil
            loadKeyForCurrent()
        }
    }

    private func loadKeyForCurrent() {
        keys[settings.selectedProvider] = (try? store.load(for: settings.selectedProvider)) ?? ""
    }

    private func pasteFromClipboard() {
        if let clipboardString = NSPasteboard.general.string(forType: .string) {
            let trimmed = clipboardString.trimmingCharacters(in: .whitespacesAndNewlines)
            keys[settings.selectedProvider] = trimmed
        }
    }

    private func save() {
        let raw = keys[settings.selectedProvider] ?? ""
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            if trimmed.isEmpty {
                try store.delete(for: settings.selectedProvider)
            } else {
                try store.save(trimmed, for: settings.selectedProvider)
            }
            testMessage = "Saved."
            testMessageIsError = false
        } catch {
            testMessage = "Save failed: \(error.localizedDescription)"
            testMessageIsError = true
        }
    }

    private func test() async {
        save() // persist before testing
        testing = true
        defer { testing = false }
        let kind = settings.selectedProvider
        let key = (try? store.load(for: kind)) ?? ""
        let provider: RefinementProvider
        switch kind {
        case .gemini:    provider = GeminiProvider(apiKey: key)
        case .openai:    provider = OpenAIProvider(apiKey: key)
        case .groq:      provider = GroqProvider(apiKey: key)
        case .anthropic: provider = AnthropicProvider(apiKey: key)
        }
        do {
            _ = try await provider.refine("hello")
            testMessage = "Key works ✓"
            testMessageIsError = false
        } catch let e as ProviderError {
            testMessage = e.errorDescription
            testMessageIsError = true
        } catch {
            testMessage = error.localizedDescription
            testMessageIsError = true
        }
    }
}

private struct ThemeTab: View {
    @EnvironmentObject private var settings: SettingsStore

    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pick a gradient for the refinement window")
                .font(.callout)
                .foregroundStyle(.secondary)
            ScrollView {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(GradientTheme.all) { theme in
                        ThemeSwatch(
                            theme: theme,
                            isSelected: settings.gradientThemeId == theme.id
                        ) {
                            settings.gradientThemeId = theme.id
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            Text("Changes apply instantly.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 4)
    }
}

private struct ThemeSwatch: View {
    let theme: GradientTheme
    let isSelected: Bool
    let onTap: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 7) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11)
                        .fill(theme.gradient)
                        .frame(height: 60)
                        .overlay(
                            RoundedRectangle(cornerRadius: 11)
                                .strokeBorder(
                                    isSelected ? Color.accentColor : Color.primary.opacity(hovering ? 0.25 : 0.1),
                                    lineWidth: isSelected ? 3 : 1
                                )
                        )
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.white, Color.accentColor)
                            .shadow(radius: 2)
                    }
                }
                Text(theme.name)
                    .font(.caption.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

private struct AboutTab: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Textify").font(.title2.bold())
            Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0")")
            Text("Grammar and style refinement at ⌘⇧T.").foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
