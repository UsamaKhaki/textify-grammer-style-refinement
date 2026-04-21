import SwiftUI

struct OriginalTextBox: View {
    @Binding var text: String
    var isBusy: Bool
    var onRefine: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text("ORIGINAL")
                    .font(.caption2.weight(.semibold))
                    .tracking(0.8)
                    .foregroundStyle(GlassTheme.textSecondary)
                Spacer()
                Button(action: onRefine) {
                    Label("Refine", systemImage: "arrow.clockwise")
                        .font(.caption.weight(.semibold))
                        .labelStyle(.titleAndIcon)
                        .foregroundStyle(GlassTheme.textPrimary)
                }
                .buttonStyle(.borderless)
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(isBusy || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .help("Refine again (⌘↵)")
            }
            TextEditor(text: $text)
                .font(.system(size: 12))
                .foregroundStyle(GlassTheme.textPrimary)
                .scrollContentBackground(.hidden)
                .tint(.white)
                .frame(minHeight: 40, maxHeight: 90)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }
}
