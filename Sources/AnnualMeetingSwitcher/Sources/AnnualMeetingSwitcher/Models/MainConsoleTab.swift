import Foundation

enum MainConsoleTab: Int, CaseIterable, Equatable {
    case preview = 0
    case audioMixer = 1
    case overlays = 2
}

struct TabRetentionModel: Equatable {
    let tab: MainConsoleTab
    let selectedTab: MainConsoleTab

    var isVisible: Bool { tab == selectedTab }
    var allowsHitTesting: Bool { isVisible }
    var accessibilityHidden: Bool { !isVisible }
    var opacity: Double { isVisible ? 1 : 0 }
    var zIndex: Double { isVisible ? 1 : 0 }
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
