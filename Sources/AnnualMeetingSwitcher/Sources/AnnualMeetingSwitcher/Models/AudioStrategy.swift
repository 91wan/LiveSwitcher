import Foundation

enum AudioStrategy: String, CaseIterable {
    case followProgram
    case followSource
    case bgmOnly
    case mixed

    init?(persistedValue: String) {
        if let strategy = AudioStrategy(rawValue: persistedValue) {
            self = strategy
            return
        }

        switch persistedValue {
        case "音频跟随":
            self = .followProgram
        case "跟随源":
            self = .followSource
        case "仅 BGM":
            self = .bgmOnly
        case "混合":
            self = .mixed
        default:
            return nil
        }
    }

    var displayTitle: String {
        switch self {
        case .followProgram:
            return "音频跟随"
        case .followSource:
            return "跟随源"
        case .bgmOnly:
            return "仅 BGM"
        case .mixed:
            return "混合"
        }
    }
}
