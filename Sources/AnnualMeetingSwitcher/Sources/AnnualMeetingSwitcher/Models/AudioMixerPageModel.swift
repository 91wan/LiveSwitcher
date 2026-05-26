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

    var selectedStrategyText: String {
        strategy.displayTitle
    }

    var activeLimiterText: String {
        if isPanicMode { return "紧急切黑" }
        if isBGMAudioTakeoverActive { return "BGM 接管" }
        if isSpeakerMode { return "主持人" }
        return "无"
    }

    var effectiveRoutingSummary: String {
        activeLimiterText == "无" ? "\(selectedStrategyText) · 无限制器" : "\(selectedStrategyText) · \(activeLimiterText)"
    }

    var routingImpactText: String {
        if isPanicMode {
            return "当前策略：\(selectedStrategyText)；限制器：紧急切黑。媒体和 BGM 实际输出静音。"
        }
        if isSpeakerMode {
            return "当前策略：\(selectedStrategyText)；限制器：主持人。媒体和 BGM 已压低到人声优先电平。"
        }
        if isBGMAudioTakeoverActive {
            return "当前策略：\(selectedStrategyText)；限制器：BGM 接管。媒体声道被临时静音。"
        }
        return "没有应急路由；实际输出跟随当前策略和推子。"
    }

    var routingStatusText: String {
        activeLimiterText == "无" ? selectedStrategyText : effectiveRoutingSummary
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
