import SwiftUI

struct GradientTheme: Identifiable, Equatable, Hashable {
    let id: String
    let name: String
    private let hexColors: [UInt32]

    var colors: [Color] { hexColors.map(Color.init(hex:)) }

    var gradient: LinearGradient {
        LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static let all: [GradientTheme] = [
        .init(id: "purple-dream", name: "Purple Dream", hexColors: [0x667EEA, 0x764BA2, 0xF093FB]),
        .init(id: "sunset",       name: "Sunset",       hexColors: [0xFF512F, 0xF09819]),
        .init(id: "ocean",        name: "Ocean",        hexColors: [0x2193B0, 0x6DD5ED]),
        .init(id: "aurora",       name: "Aurora",       hexColors: [0x00C6FF, 0x0072FF, 0x8E2DE2]),
        .init(id: "coral",        name: "Coral",        hexColors: [0xFF9A8B, 0xFF6A88, 0xFF99AC]),
        .init(id: "forest",       name: "Forest",       hexColors: [0x134E5E, 0x71B280]),
        .init(id: "peach",        name: "Peach",        hexColors: [0xFFDAB9, 0xFFA07A, 0xFF7F50]),
        .init(id: "midnight",     name: "Midnight",     hexColors: [0x0F2027, 0x203A43, 0x2C5364]),
        .init(id: "candy",        name: "Candy",        hexColors: [0xFF6CAB, 0x7366FF]),
        .init(id: "mint",         name: "Mint",         hexColors: [0x00F5A0, 0x00D9F5]),
        .init(id: "cosmic",       name: "Cosmic",       hexColors: [0xFC00FF, 0x00DBDE]),
        .init(id: "rose-gold",    name: "Rose Gold",    hexColors: [0xF7B2C2, 0xE5B887, 0xDDB892])
    ]

    static let defaultId = "purple-dream"

    static func byId(_ id: String) -> GradientTheme {
        all.first(where: { $0.id == id }) ?? all.first(where: { $0.id == defaultId })!
    }
}

extension Color {
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8)  & 0xFF) / 255
        let b = Double( hex        & 0xFF) / 255
        self = Color(red: r, green: g, blue: b)
    }
}
