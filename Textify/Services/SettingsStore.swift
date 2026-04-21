import Foundation
import Combine

final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    private let defaults: UserDefaults
    private enum Keys {
        static let selectedProvider = "selectedProvider"
        static let closeAfterCopy = "closeAfterCopy"
        static let launchAtLogin = "launchAtLogin"
        static let gradientThemeId = "gradientThemeId"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    @Published var selectedProvider: ProviderKind = {
        let raw = UserDefaults.standard.string(forKey: Keys.selectedProvider) ?? ProviderKind.gemini.rawValue
        return ProviderKind(rawValue: raw) ?? .gemini
    }() {
        didSet { defaults.set(selectedProvider.rawValue, forKey: Keys.selectedProvider) }
    }

    @Published var closeAfterCopy: Bool = UserDefaults.standard.object(forKey: Keys.closeAfterCopy) as? Bool ?? true {
        didSet { defaults.set(closeAfterCopy, forKey: Keys.closeAfterCopy) }
    }

    @Published var launchAtLogin: Bool = UserDefaults.standard.bool(forKey: Keys.launchAtLogin) {
        didSet { defaults.set(launchAtLogin, forKey: Keys.launchAtLogin) }
    }

    @Published var gradientThemeId: String = UserDefaults.standard.string(forKey: Keys.gradientThemeId) ?? GradientTheme.defaultId {
        didSet { defaults.set(gradientThemeId, forKey: Keys.gradientThemeId) }
    }

    var gradientTheme: GradientTheme { GradientTheme.byId(gradientThemeId) }
}
