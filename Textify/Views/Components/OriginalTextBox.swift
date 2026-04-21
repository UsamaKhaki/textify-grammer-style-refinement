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
                    .tracking(0.6)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(action: onRefine) {
                    Label("Refine", systemImage: "arrow.clockwise")
                        .font(.caption)
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.borderless)
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(isBusy || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .help("Refine again (⌘↵)")
            }
            TextEditor(text: $text)
                .font(.system(size: 12))
                .scrollContentBackground(.hidden)
                .frame(minHeight: 40, maxHeight: 90)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.04))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.primary.opacity(0.08)))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
