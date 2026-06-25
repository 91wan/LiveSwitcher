import Foundation

enum MainConsoleTab: Int, CaseIterable, Equatable {
    case preview = 0
    case audioMixer = 1
    case overlays = 2

    var chromeTitleSuffix: String {
        switch self {
        case .preview:
            return "导播台"
        case .audioMixer:
            return "音频"
        case .overlays:
            return "叠层"
        }
    }

    var chromeTitle: String {
        ConsoleBrandingModel.title(brandName: "", mode: .setup, tab: self)
    }

    var setupMenuTitle: String {
        switch self {
        case .preview:
            return "节目单"
        case .audioMixer:
            return "音频"
        case .overlays:
            return "叠层"
        }
    }

    var setupShortcutKey: String {
        switch self {
        case .preview:
            return "1"
        case .audioMixer:
            return "2"
        case .overlays:
            return "3"
        }
    }

    var setupMenuShortcutLabel: String {
        "\(setupMenuTitle)  ⌘\(setupShortcutKey)"
    }

    var systemImage: String {
        switch self {
        case .preview:
            return "play.square.stack.fill"
        case .audioMixer:
            return "slider.horizontal.3"
        case .overlays:
            return "rectangle.3.group.bubble.left.fill"
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
            return "叠层已清空"
        case .turnOffPanic:
            return "紧急切黑已关闭"
        case .openPreview, .openAudioMixer, .openOverlays, .needsHardware, .manualReview:
            return nil
        }
    }
}
