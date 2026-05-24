import Foundation

enum ConsoleMode: String, CaseIterable, Equatable, Identifiable {
    case setup
    case live

    var id: String { rawValue }

    var displayTitleKey: String {
        switch self {
        case .setup:
            return "console.mode.setup"
        case .live:
            return "console.mode.live"
        }
    }

    var displayTitle: String {
        NSLocalizedString(displayTitleKey, bundle: .module, comment: "")
    }

    var systemImage: String {
        switch self {
        case .setup:
            return "gearshape.fill"
        case .live:
            return "play.fill"
        }
    }
}
