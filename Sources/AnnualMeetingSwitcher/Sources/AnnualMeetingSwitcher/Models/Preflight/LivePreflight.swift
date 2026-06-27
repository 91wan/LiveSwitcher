import Foundation

enum LivePreflightGroup: String, CaseIterable {
    case display = "Display"
    case audio = "Audio"
    case playback = "Playback"
    case overlays = "Overlays"
    case controls = "Controls"

    var displayTitle: String {
        switch self {
        case .display:
            return "显示"
        case .audio:
            return "音频"
        case .playback:
            return "播放"
        case .overlays:
            return "叠层"
        case .controls:
            return "控制"
        }
    }
}

enum LivePreflightStatus: String {
    case pass = "PASS"
    case warn = "WARN"
    case fail = "FAIL"

    var displayTitle: String {
        switch self {
        case .pass:
            return "通过"
        case .warn:
            return "警告"
        case .fail:
            return "故障"
        }
    }
}

enum LivePreflightActionPresentationRole: Equatable {
    case safeOneClick
    case navigation
    case operatorGuidance
}

enum LivePreflightActionKind: String, Equatable {
    case clearOverlays
    case turnOffPanic
    case openPreview
    case openAudioMixer
    case openOverlays
    case needsHardware
    case manualReview

    var presentationRole: LivePreflightActionPresentationRole {
        switch self {
        case .clearOverlays, .turnOffPanic:
            return .safeOneClick
        case .openPreview, .openAudioMixer, .openOverlays:
            return .navigation
        case .needsHardware, .manualReview:
            return .operatorGuidance
        }
    }

    var shouldRenderAsButton: Bool {
        presentationRole != .operatorGuidance
    }

    var isEnabledInPreflightUI: Bool {
        shouldRenderAsButton
    }
}

enum LiveOverlayKind: String, Equatable, CaseIterable {
    case countdown
    case ticker
    case lowerThird

    var displayTitle: String {
        switch self {
        case .countdown:
            return "倒计时"
        case .ticker:
            return "游动字幕"
        case .lowerThird:
            return "人名条"
        }
    }
}

struct LivePreflightSnapshot: Equatable {
    var appVersion: String
    var hasExternalDisplay: Bool
    var isBroadcasting: Bool
    var broadcastSafetyNotice: String?
    var programItemCount: Int
    var currentProgramTitle: String?
    var currentProgramSource: String?
    var currentProgramScheduledStartAt: Date? = nil
    var currentProgramScheduledDuration: TimeInterval? = nil
    var currentProgramSwitchedAt: Date? = nil
    var scheduleNow: Date = Date()
    var bgmItemCount: Int
    var isBGMPlaying: Bool
    var isBGMAudioTakeoverActive: Bool
    var isSpeakerMode: Bool
    var isPanicMode: Bool
    var isPageInterceptEnabled: Bool
    var activeOverlayCount: Int
    var activeOverlayKinds: [LiveOverlayKind] = []
    var countdownRemainingSeconds: Int? = nil
    var wallpaperCount: Int
    var autoPlayNextVideoOnEnd: Bool
    var effectiveMediaVolume: Float
    var effectiveBGMVolume: Float

    static func == (lhs: LivePreflightSnapshot, rhs: LivePreflightSnapshot) -> Bool {
        lhs.appVersion == rhs.appVersion &&
        lhs.hasExternalDisplay == rhs.hasExternalDisplay &&
        lhs.isBroadcasting == rhs.isBroadcasting &&
        lhs.broadcastSafetyNotice == rhs.broadcastSafetyNotice &&
        lhs.programItemCount == rhs.programItemCount &&
        lhs.currentProgramTitle == rhs.currentProgramTitle &&
        lhs.currentProgramSource == rhs.currentProgramSource &&
        lhs.currentProgramScheduledStartAt == rhs.currentProgramScheduledStartAt &&
        lhs.currentProgramScheduledDuration == rhs.currentProgramScheduledDuration &&
        lhs.currentProgramSwitchedAt == rhs.currentProgramSwitchedAt &&
        lhs.bgmItemCount == rhs.bgmItemCount &&
        lhs.isBGMPlaying == rhs.isBGMPlaying &&
        lhs.isBGMAudioTakeoverActive == rhs.isBGMAudioTakeoverActive &&
        lhs.isSpeakerMode == rhs.isSpeakerMode &&
        lhs.isPanicMode == rhs.isPanicMode &&
        lhs.isPageInterceptEnabled == rhs.isPageInterceptEnabled &&
        lhs.activeOverlayCount == rhs.activeOverlayCount &&
        lhs.activeOverlayKinds == rhs.activeOverlayKinds &&
        lhs.countdownRemainingSeconds == rhs.countdownRemainingSeconds &&
        lhs.wallpaperCount == rhs.wallpaperCount &&
        lhs.autoPlayNextVideoOnEnd == rhs.autoPlayNextVideoOnEnd &&
        lhs.effectiveMediaVolume == rhs.effectiveMediaVolume &&
        lhs.effectiveBGMVolume == rhs.effectiveBGMVolume
    }
}
