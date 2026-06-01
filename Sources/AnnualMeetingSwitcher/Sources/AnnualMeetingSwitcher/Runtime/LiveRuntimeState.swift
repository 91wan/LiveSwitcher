import Foundation

struct LiveRuntimeState: Equatable {
    var mode: ConsoleMode = .setup
    var program = ProgramRuntimeState()
    var media = MediaRuntimeState()
    var bgm = BGMRuntimeState()
    var audio = AudioRuntimeState()
    var panic = PanicRuntimeState()
    var ppt = PPTRuntimeState()
    var projection = ProjectionRuntimeState()
    var automation = AutomationRuntimeState()
    var preferences = LiveRuntimePreferenceState()
    var support = SupportRuntimeState()
}

struct ProgramRuntimeState: Equatable {
    var items: [ProgramItem] = []
    var currentID: UUID?
    var currentSwitchedAt: Date?

    var currentItem: ProgramItem? {
        guard let currentID else { return nil }
        return items.first { $0.id == currentID }
    }
}

struct MediaRuntimeState: Equatable {
    var loadedURL: URL?
    var isPlaying = false
    var didPlayToEnd = false
    var currentTime: Double = 0
    var duration: Double?
    var generation = 0
}

struct BGMRuntimeState: Equatable {
    var items: [BGMItem] = []
    var currentID: UUID?
    var isPlaying = false
    var playMode: BGMPlayMode = .loopAll
    var progress: Double = 0
    var currentTime: Double = 0
    var duration: Double?
    var generation = 0

    var currentItem: BGMItem? {
        guard let currentID else { return nil }
        return items.first { $0.id == currentID }
    }
}

struct AudioRuntimeState: Equatable {
    var masterVolume: Double = 0.5
    var mediaVolume: Double = 1
    var bgmVolume: Double = 0.5
    var strategy: AudioStrategy = .mixed
    var isMasterMuted = false
    var isMediaMuted = false
    var isBGMMuted = false
    var isSpeakerMode = false
    var isBGMTakeoverActive = false
    var effectiveMedia: Float = 0
    var effectiveBGM: Float = 0
}

struct PanicRuntimeState: Equatable {
    var isActive = false
    var snapshot: PanicPlaybackSnapshot?
    var generation = 0
}

struct PPTRuntimeState: Equatable {
    var isRequested = false
    var isEventTapActive = false
    var lastFailureReason: String?
}

struct ProjectionRuntimeState: Equatable {
    var isBroadcasting = false
    var hasExternalDisplay = false
    var lastDisplayLostAt: Date?
    var safetyNotice: String?
}

struct AutomationRuntimeState: Equatable {
    var notice: AutomationRuntimeNotice?
    var suppressionUntilByAction: [String: Date] = [:]
}

struct LiveRuntimePreferenceState: Equatable {
    var autoPlayNextVideoOnEnd = false
    var autoAdvanceAtScheduledTime = false
}

struct SupportRuntimeState: Equatable {
    var events: [LiveSupportEvent] = []
    var coalescedCounts: [String: Int] = [:]
    var eventLimit = 80

    mutating func record(kind: LiveSupportEventKind, detail: String, at date: Date) {
        let baseDetail = LiveSupportRedactor.safeEventDetail(detail)
        let key = "\(kind.rawValue)|\(baseDetail)"

        if shouldCoalesce(kind),
           let index = events.firstIndex(where: { $0.kind == kind && supportEventBaseDetail($0.detail) == baseDetail }) {
            let existing = events.remove(at: index)
            let nextCount = supportEventCoalescedCount(existing.detail) + 1
            coalescedCounts[key] = nextCount
            events.append(
                LiveSupportEvent(
                    timestamp: date,
                    kind: kind,
                    detail: "\(baseDetail),count=\(nextCount),lastSeen=\(Self.isoString(date))"
                )
            )
            trimToLimit()
            return
        }

        coalescedCounts[key] = 1
        events.append(LiveSupportEvent(timestamp: date, kind: kind, detail: baseDetail))
        trimToLimit()
    }

    private mutating func trimToLimit() {
        if events.count > eventLimit {
            events.removeFirst(events.count - eventLimit)
        }
    }

    private func shouldCoalesce(_ kind: LiveSupportEventKind) -> Bool {
        switch kind {
        case .appleScriptFailed, .pageInterceptWPSNotRunning, .pageInterceptForwardedToWPS:
            return true
        default:
            return false
        }
    }

    private func supportEventBaseDetail(_ detail: String) -> String {
        guard let countRange = detail.range(of: ",count=") else {
            return detail
        }
        return String(detail[..<countRange.lowerBound])
    }

    private func supportEventCoalescedCount(_ detail: String) -> Int {
        guard let countRange = detail.range(of: ",count=") else {
            return 1
        }
        let countStart = countRange.upperBound
        let countEnd = detail[countStart...].firstIndex(of: ",") ?? detail.endIndex
        return Int(detail[countStart..<countEnd]) ?? 1
    }

    private static func isoString(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }
}

struct LiveRuntimeEnvironment: Equatable {
    var now: Date

    init(now: Date = Date()) {
        self.now = now
    }
}

struct LiveRuntimeActionLogEntry: Equatable {
    var timestamp: Date
    var actionName: String
    var oldStateSummary: String
    var newStateSummary: String
}
