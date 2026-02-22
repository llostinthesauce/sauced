import SwiftUI

// MARK: - Theme Definition

enum AppTheme: String, CaseIterable, Identifiable {
    case light   = "Light"
    case dark    = "Dark"
    case breeze  = "Breeze"

    var id: String { rawValue }

    var colorScheme: ColorScheme {
        switch self {
        case .light:  return .light
        case .dark:   return .dark
        case .breeze: return .dark
        }
    }

    /// Primary tint used for section headers, row icons, etc.
    var primaryAccent: Color {
        switch self {
        case .light:  return .purple
        case .dark:   return .purple
        case .breeze: return Color(red: 0.0, green: 0.75, blue: 0.72)
        }
    }

    /// 9-color array for the MeshGradient player background.
    var meshColors: [Color] {
        switch self {
        case .light:
            return [
                .purple, .indigo, .purple,
                .indigo, Color(red: 0.55, green: 0.35, blue: 0.85), .indigo,
                .indigo, .purple, .indigo
            ]
        case .dark:
            return [
                .purple, .indigo, .blue,
                .blue, .black.opacity(0.8), .indigo,
                .black, .black, .purple
            ]
        case .breeze:
            return [
                Color(red: 0.0, green: 0.75, blue: 0.72),
                Color(red: 0.0, green: 0.55, blue: 0.75),
                Color(red: 0.1, green: 0.65, blue: 0.60),
                Color(red: 0.0, green: 0.40, blue: 0.60),
                Color(red: 0.0, green: 0.30, blue: 0.40),
                Color(red: 0.0, green: 0.55, blue: 0.70),
                Color(red: 0.0, green: 0.20, blue: 0.30),
                Color(red: 0.0, green: 0.25, blue: 0.35),
                Color(red: 0.0, green: 0.65, blue: 0.65)
            ]
        }
    }

    /// Preview swatch colors shown in the settings picker.
    var swatchColors: [Color] {
        switch self {
        case .light:  return [.purple, .indigo, .white]
        case .dark:   return [.purple, .indigo, .black]
        case .breeze: return [Color(red: 0.0, green: 0.75, blue: 0.72), Color(red: 0.0, green: 0.55, blue: 0.75), Color(red: 0.0, green: 0.30, blue: 0.45)]
        }
    }

    var description: String {
        switch self {
        case .light:  return "Light mode, purple accents"
        case .dark:   return "Dark mode, purple accents"
        case .breeze: return "Dark mode, ocean blues & greens"
        }
    }
}

// MARK: - ThemeStore

@Observable
class ThemeStore {
    static let shared = ThemeStore()

    var selectedTheme: AppTheme {
        didSet {
            UserDefaults.standard.set(selectedTheme.rawValue, forKey: "appTheme")
        }
    }

    private init() {
        let saved = UserDefaults.standard.string(forKey: "appTheme") ?? AppTheme.light.rawValue
        selectedTheme = AppTheme(rawValue: saved) ?? .light
    }
}
