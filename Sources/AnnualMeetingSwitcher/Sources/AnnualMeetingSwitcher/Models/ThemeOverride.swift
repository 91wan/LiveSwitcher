import SwiftUI

enum ThemeOverride: String, CaseIterable, Equatable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var menuTitle: String {
        switch self {
        case .system:
            return "System"
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}
