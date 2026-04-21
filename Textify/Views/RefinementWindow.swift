import SwiftUI

struct RefinementWindow: View {
    @ObservedObject var vm: RefinementViewModel
    @EnvironmentObject private var settings: SettingsStore
    var openSettings: () -> Void
    var close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(16)
        .frame(width: 560, height: 440)
        .background(.background)
        .focusable()
        .onKeyPress(.escape) { close(); return .handled }
        .onKeyPress(.init("1")) { vm.pick(1); return .handled }
        .onKeyPress(.init("2")) { vm.pick(2); return .handled }
        .onKeyPress(.init("3")) { vm.pick(3); return .handled }
    }

    @ViewBuilder
    private var content: some View {
        switch vm.state {
        case .empty:
            emptyView
        case .loading:
            OriginalTextBox(text: vm.original)
            loadingView
        case .result(let triple):
            OriginalTextBox(text: vm.original)
            resultsView(triple)
        case .error(let err):
            OriginalTextBox(text: vm.original.isEmpty ? "(no clipboard text)" : vm.original)
            errorView(err)
        }
        Spacer(minLength: 0)
        footer
    }

    private var emptyView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Paste your message here")
                .font(.callout)
                .foregroundStyle(.secondary)
            TextEditor(text: $vm.original)
                .font(.system(size: 13))
                .frame(minHeight: 160)
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.primary.opacity(0.12)))
            HStack {
                Spacer()
                Button("Refine") { Task { await vm.refine() } }
                    .keyboardShortcut(.return, modifiers: [.command])
                    .buttonStyle(.borderedProminent)
                    .disabled(vm.original.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 8) {
            ForEach(0..<3) { _ in
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.primary.opacity(0.05))
                    .overlay(ProgressView().controlSize(.small))
                    .frame(height: 68)
            }
        }
    }

    private func resultsView(_ t: RefinedTriple) -> some View {
        VStack(spacing: 8) {
            RefinementCard(label: "Casual",       shortcut: "1", text: t.casual)       { vm.pick(1) }
            RefinementCard(label: "Professional", shortcut: "2", text: t.professional) { vm.pick(2) }
            RefinementCard(label: "Concise",      shortcut: "3", text: t.concise)      { vm.pick(3) }
        }
    }

    private func errorView(_ err: ProviderError) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(err.errorDescription ?? "Something went wrong")
                .foregroundStyle(.primary)
            HStack {
                switch err {
                case .missingKey, .unauthorized:
                    Button("Open Settings", action: openSettings).buttonStyle(.borderedProminent)
                case .network, .timeout, .rateLimited, .server, .malformedResponse:
                    Button("Retry") { Task { await vm.refine() } }.buttonStyle(.borderedProminent)
                }
                Spacer()
            }
        }
        .padding(14)
        .background(Color.red.opacity(0.08))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.red.opacity(0.3)))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var footer: some View {
        HStack {
            Text("Press 1/2/3 to copy").font(.caption).foregroundStyle(.secondary)
            Spacer()
            Text("Esc to close").font(.caption).foregroundStyle(.secondary)
        }
    }
}
