import Foundation

enum MainConsoleTab: Int, CaseIterable, Equatable {
    case preview = 0
    case audioMixer = 1
    case overlays = 2
}

extension LivePreflightActionKind {
    var mainConsoleDestination: MainConsoleTab? {
        switch self {
        case .openPreview:
            return .preview
        case .openAudioMixer:
            return .audioMixer
        case .openOverlays:
            return .overlays
        case .clearOverlays, .turnOffPanic, .needsHardware, .manualReview:
            return nil
        }
    }
}
