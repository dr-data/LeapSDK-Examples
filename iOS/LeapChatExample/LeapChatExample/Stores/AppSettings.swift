import SwiftUI

enum ThemeMode: String, CaseIterable {
    case system = "System"
    case dark = "Dark"
    case light = "Light"

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .dark: return .dark
        case .light: return .light
        }
    }
}

@Observable
class AppSettings {
    var themeMode: ThemeMode {
        didSet { save() }
    }

    init() {
        let raw = UserDefaults.standard.string(forKey: "themeMode") ?? "dark"
        self.themeMode = ThemeMode(rawValue: raw) ?? .dark
    }

    private func save() {
        UserDefaults.standard.set(themeMode.rawValue, forKey: "themeMode")
    }
}
