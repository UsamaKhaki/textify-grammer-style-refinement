import SwiftUI

struct RefinementCard: View {
    let label: String
    let shortcut: String
    let text: String
    let onPick: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: onPick) {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(label.uppercased())
                        .font(.caption.weight(.semibold))
                        .tracking(0.6)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(shortcut)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .frame(minWidth: 18, minHeight: 18)
                        .padding(.horizontal, 5)
                        .background(Color.primary.opacity(0.10))
                        .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color.primary.opacity(0.12)))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .foregroundStyle(.primary)
                }
                Text(text)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(hovering ? Color.accentColor.opacity(0.14) : Color.primary.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(hovering ? Color.accentColor.opacity(0.45) : Color.primary.opacity(0.08))
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
