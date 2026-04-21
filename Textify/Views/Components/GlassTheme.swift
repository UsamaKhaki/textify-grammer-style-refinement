import SwiftUI

/// Colors + reusable view modifiers for the Glassmorphism / Liquid Glass theme.
enum GlassTheme {
    // Gradient stops: #667eea → #764ba2 → #f093fb
    static let gradient = LinearGradient(
        colors: [
            Color(red: 0x66 / 255, green: 0x7E / 255, blue: 0xEA / 255),
            Color(red: 0x76 / 255, green: 0x4B / 255, blue: 0xA2 / 255),
            Color(red: 0xF0 / 255, green: 0x93 / 255, blue: 0xFB / 255)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // White-alpha layers for the frosted shell
    static let panelFill  = Color.white.opacity(0.10)
    static let panelBorder = Color.white.opacity(0.25)

    static let cardFill       = Color.white.opacity(0.12)
    static let cardFillHover  = Color.white.opacity(0.22)
    static let cardBorder     = Color.white.opacity(0.25)
    static let cardBorderHover = Color.white.opacity(0.5)

    static let textPrimary    = Color.white
    static let textSecondary  = Color.white.opacity(0.72)
    static let textTertiary   = Color.white.opacity(0.55)
}

/// Card-style frosted panel.
struct GlassCardStyle: ViewModifier {
    var hovering: Bool = false
    func body(content: Content) -> some View {
        content
            .background(hovering ? GlassTheme.cardFillHover : GlassTheme.cardFill)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(hovering ? GlassTheme.cardBorderHover : GlassTheme.cardBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

extension View {
    func glassCard(hovering: Bool = false) -> some View {
        modifier(GlassCardStyle(hovering: hovering))
    }
}
