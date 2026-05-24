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
        ["Mixer", "Routing Strategy", "BGM Library"]
    }

    var routingImpactText: String {
        if isPanicMode {
            return "Panic is active: media and BGM effective outputs are muted."
        }
        if isSpeakerMode {
            return "Speaker mode is active: media and BGM are ducked to the speaker-safe level."
        }
        if isBGMAudioTakeoverActive {
            return "BGM takeover is active: media is muted while BGM plays."
        }
        return "No emergency routing is active; effective output follows the selected strategy and faders."
    }

    var routingStatusText: String {
        if isPanicMode { return "PANIC MUTED" }
        if isBGMAudioTakeoverActive { return "BGM TAKEOVER" }
        if isSpeakerMode { return "SPEAKER" }
        return strategy.displayTitle
    }

    var routingStatusKind: StudioTheme.StatusKind {
        if isPanicMode { return .fail }
        if isSpeakerMode || isBGMAudioTakeoverActive { return .warn }
        return .idle
    }

    var channelLimitText: String {
        if isPanicMode { return "Muted: media, BGM" }
        if isBGMAudioTakeoverActive { return "Muted: media" }
        if isSpeakerMode { return "Ducked: media, BGM" }
        return "No forced mute"
    }
}

enum AudioMixerFaderAccent: String, CaseIterable, Equatable {
    case master = "action.primary"
    case media = "tone.warn"
    case bgm = "tone.ready"

    var color: Color {
        switch self {
        case .master:
            return StudioTheme.Action.primary
        case .media:
            return StudioTheme.Tone.warn
        case .bgm:
            return StudioTheme.Tone.ready
        }
    }
}
