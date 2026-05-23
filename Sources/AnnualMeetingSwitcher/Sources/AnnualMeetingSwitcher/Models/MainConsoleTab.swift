import Foundation

enum MainConsoleTab: Int, CaseIterable, Equatable {
    case preview = 0
    case audioMixer = 1
    case overlays = 2

    var chromeTitle: String {
        switch self {
        case .preview:
            return "LiveSwitcher · Run"
        case .audioMixer:
            return "LiveSwitcher · Audio"
        case .overlays:
            return "LiveSwitcher · Overlays"
        }
    }
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

struct PreflightActionRoutingModel: Equatable {
    let action: LivePreflightActionKind
    let shouldDismissPopover: Bool
    let destinationTab: MainConsoleTab?
    let successMessage: String?
    let shouldMutateState: Bool

    static func make(action: LivePreflightActionKind) -> PreflightActionRoutingModel {
        let destination = action.mainConsoleDestination
        return PreflightActionRoutingModel(
            action: action,
            shouldDismissPopover: destination != nil,
            destinationTab: destination,
            successMessage: action.successMessage,
            shouldMutateState: action.presentationRole == .safeOneClick
        )
    }
}

private extension LivePreflightActionKind {
    var successMessage: String? {
        switch self {
        case .clearOverlays:
            return "Overlays cleared"
        case .turnOffPanic:
            return "Panic turned off"
        case .openPreview, .openAudioMixer, .openOverlays, .needsHardware, .manualReview:
            return nil
        }
    }
}
