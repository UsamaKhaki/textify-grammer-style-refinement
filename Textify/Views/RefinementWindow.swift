import SwiftUI

struct RefinementWindow: View {
    @ObservedObject var vm: RefinementViewModel
    @EnvironmentObject private var settings: SettingsStore
    var openSettings: () -> Void
    var close: () -> Void

    var body: some View {
        ZStack {
            settings.gradientTheme.gradient
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .padding(16)
        }
        .frame(width: 560, height: 440)
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
            originalBox(isBusy: true)
            loadingView
        case .result:
            originalBox(isBusy: false)
            if case .result(let triple) = vm.state { resultsView(triple) }
        case .error(let err):
            originalBox(isBusy: false)
            errorView(err)
        }
        Spacer(minLength: 0)
        footer
    }

    private var emptyView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Paste your message here")
                .font(.callout)
                .foregroundStyle(GlassTheme.textSecondary)
            TextEditor(text: $vm.original)
                .font(.system(size: 13))
                .foregroundColor(.white)
                .scrollContentBackground(.hidden)
                .tint(.white)
                .frame(minHeight: 160)
                .padding(10)
                .glassCard()
            HStack {
                Spacer()
                Button("Refine") { Task { await vm.refine() } }
                    .keyboardShortcut(.return, modifiers: [.command])
                    .buttonStyle(.borderedProminent)
                    .tint(.white.opacity(0.3))
                    .foregroundStyle(.white)
                    .disabled(vm.original.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func originalBox(isBusy: Bool) -> some View {
        OriginalTextBox(
            text: $vm.original,
            isBusy: isBusy,
            onRefine: { Task { await vm.refine() } }
        )
    }

    private var loadingView: some View {
        VStack(spacing: 8) {
            ForEach(0..<3) { _ in
                RoundedRectangle(cornerRadius: 14)
                    .fill(GlassTheme.cardFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(GlassTheme.cardBorder, lineWidth: 1)
                    )
                    .overlay(ProgressView().controlSize(.small).tint(.white))
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
                .foregroundStyle(GlassTheme.textPrimary)
            HStack {
                switch err {
                case .missingKey, .unauthorized:
                    Button("Open Settings", action: openSettings)
                        .buttonStyle(.borderedProminent)
                        .tint(.white.opacity(0.3))
                        .foregroundStyle(.white)
                case .network, .timeout, .rateLimited, .server, .malformedResponse:
                    Button("Retry") { Task { await vm.refine() } }
                        .buttonStyle(.borderedProminent)
                        .tint(.white.opacity(0.3))
                        .foregroundStyle(.white)
                }
                Spacer()
            }
        }
        .padding(14)
        .background(Color.red.opacity(0.18))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.white.opacity(0.4), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var footer: some View {
        HStack {
            Text("Press 1/2/3 to copy").font(.caption).foregroundStyle(GlassTheme.textTertiary)
            Spacer()
            Text("Esc to close").font(.caption).foregroundStyle(GlassTheme.textTertiary)
        }
    }
}
