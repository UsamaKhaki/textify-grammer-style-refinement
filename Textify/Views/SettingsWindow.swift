import SwiftUI
import KeyboardShortcuts
import ServiceManagement

struct SettingsWindow: View {
    var body: some View {
        TabView {
            GeneralTab().tabItem { Label("General", systemImage: "gearshape") }
            ProviderTab().tabItem { Label("AI Provider", systemImage: "cpu") }
            AboutTab().tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 480, height: 380)
        .padding(20)
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
                SecureField("Paste your key", text: Binding(
                    get: { keys[settings.selectedProvider] ?? "" },
                    set: { keys[settings.selectedProvider] = $0 }
                ))
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
        case .gemini: provider = GeminiProvider(apiKey: key)
        case .openai: provider = OpenAIProvider(apiKey: key)
        case .groq:   provider = GroqProvider(apiKey: key)
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
