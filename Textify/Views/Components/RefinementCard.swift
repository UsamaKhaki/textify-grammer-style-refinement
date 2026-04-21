import SwiftUI

struct RefinementCard: View {
    let label: String
    let shortcut: String
    let text: String
    let onPick: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: onPick) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(label.uppercased())
                        .font(.caption.weight(.semibold))
                        .tracking(0.8)
                        .foregroundStyle(GlassTheme.textSecondary)
                    Spacer()
                    Text(shortcut)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 1)
                        .foregroundStyle(GlassTheme.textPrimary)
                        .background(Color.white.opacity(0.25))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                Text(text)
                    .font(.system(size: 13))
                    .foregroundStyle(GlassTheme.textPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(hovering: hovering)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
