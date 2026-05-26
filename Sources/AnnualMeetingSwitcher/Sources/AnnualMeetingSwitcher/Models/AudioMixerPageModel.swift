import Foundation
import SwiftUI

struct AudioMixerPageModel: Equatable {
    let masterVolume: Double
    let mediaVolume: Double
    let mediaEffectiveVolume: Double
    let bgmVolume: Double
    let bgmEffectiveVolume: Double
    let strategy: AudioStrategy
    let isPanicMode: Bool
    let isSpeakerMode: Bool
    let isBGMAudioTakeoverActive: Bool

    var sectionTitles: [String] {
        ["调音台", "音频策略", "BGM 库"]
    }

    var routingImpactText: String {
        if isPanicMode {
            return "紧急切黑已开启：媒体和 BGM 实际输出静音。"
        }
        if isSpeakerMode {
            return "主持人模式已开启：媒体和 BGM 已压低到人声优先电平。"
        }
        if isBGMAudioTakeoverActive {
            return "BGM 接管已开启：BGM 播放时媒体声道静音。"
        }
        return "没有应急路由；实际输出跟随当前策略和推子。"
    }

    var routingStatusText: String {
        if isPanicMode { return "切黑静音" }
        if isBGMAudioTakeoverActive { return "BGM 接管" }
        if isSpeakerMode { return "主持人" }
        return strategy.displayTitle
    }

    var routingStatusKind: StudioTheme.StatusKind {
        if isPanicMode { return .fail }
        if isSpeakerMode || isBGMAudioTakeoverActive { return .warn }
        return .idle
    }

    var channelLimitText: String {
        if isPanicMode { return "静音：媒体、BGM" }
        if isBGMAudioTakeoverActive { return "静音：媒体" }
        if isSpeakerMode { return "压低：媒体、BGM" }
        return "无强制静音"
    }
}

enum AudioMixerFaderAccent: String, CaseIterable, Equatable {
    case master = "action.primary"
    case media = "action.secondary"
    case bgm = "tone.warn"

    var color: Color {
        switch self {
        case .master:
            return StudioTheme.Action.primary
        case .media:
            return StudioTheme.Action.secondary
        case .bgm:
            return StudioTheme.Tone.warn
        }
    }
}
