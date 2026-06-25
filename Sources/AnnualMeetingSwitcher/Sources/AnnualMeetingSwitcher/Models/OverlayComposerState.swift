import Foundation

enum OverlayComposerKind: String, CaseIterable, Equatable, Identifiable {
    case lowerThird
    case countdown
    case ticker

    var id: String { rawValue }

    var title: String {
        switch self {
        case .lowerThird: return "人名条"
        case .countdown: return "倒计时"
        case .ticker: return "游动字幕"
        }
    }

    var pickerTitle: String {
        switch self {
        case .lowerThird: return "人名条"
        case .countdown: return "倒计时"
        case .ticker: return "游动字幕"
        }
    }

    var systemImage: String {
        switch self {
        case .lowerThird: return "person.text.rectangle"
        case .countdown: return "timer"
        case .ticker: return "text.badge.star"
        }
    }
}

struct OverlayComposerState: Equatable {
    var selectedKind: OverlayComposerKind = .lowerThird
    var countdownMinutesDraft = 10
    var countdownSecondsDraft = 0
    var countdownTitleDraft = "活动即将开始"
    var tickerTextDraft = "欢迎莅临，活动即将开始"
    var tickerSpeedIndex = 1
    var lowerThirdNameDraft = ""
    var lowerThirdRoleDraft = ""
    var lowerThirdOrganizationDraft = ""
    var selectedLowerThirdPresetID: UUID?
    var selectedCountdownPresetID: UUID?
    var selectedTickerPresetID: UUID?

    var visibleComposerTitles: [String] {
        [selectedKind.title]
    }

    var trimmedLowerThirdName: String {
        lowerThirdNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedTickerText: String {
        tickerTextDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var countdownTotalSeconds: Int {
        OverlayUIState.countdownTotalSeconds(minutes: countdownMinutesDraft, seconds: countdownSecondsDraft) ?? 0
    }

    mutating func select(_ kind: OverlayComposerKind) {
        selectedKind = kind
    }
}
