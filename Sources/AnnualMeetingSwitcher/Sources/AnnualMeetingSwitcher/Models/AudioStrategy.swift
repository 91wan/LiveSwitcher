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

        guard let strategy = Self.legacyPersistedValues[persistedValue] else {
            return nil
        }
        self = strategy
    }

    var displayTitleKey: String {
        switch self {
        case .followProgram:
            return "audio.strategy.followProgram.title"
        case .followSource:
            return "audio.strategy.followSource.title"
        case .bgmOnly:
            return "audio.strategy.bgmOnly.title"
        case .mixed:
            return "audio.strategy.mixed.title"
        }
    }

    var displayTitle: String {
        NSLocalizedString(displayTitleKey, bundle: .module, comment: "")
    }

    private static let legacyPersistedValues: [String: AudioStrategy] = [
        "音频跟随": .followProgram,
        "跟随源": .followSource,
        "仅 BGM": .bgmOnly,
        "混合": .mixed
    ]
}
