import Foundation

enum LiveRuntimeBridgeMode: String, CaseIterable, Equatable {
    case recordingOnly
    case audioOwned
    case mediaOwned
    case bgmOwned
    case projectionOwned
    case pptOwned
    case fullRuntime
}

enum LiveRuntimeDomain: String, CaseIterable, Equatable {
    case audio
    case media
    case bgm
    case projection
    case panic
    case ppt
    case automation
    case support
}

extension LiveRuntimeBridgeMode {
    var ownedDomains: Set<LiveRuntimeDomain> {
        switch self {
        case .recordingOnly:
            return []
        case .audioOwned:
            return [.audio]
        case .mediaOwned:
            return [.audio, .media]
        case .bgmOwned:
            return [.audio, .media, .bgm]
        case .projectionOwned:
            return [.audio, .media, .bgm, .projection]
        case .pptOwned:
            return [.audio, .media, .bgm, .projection, .ppt]
        case .fullRuntime:
            return Set(LiveRuntimeDomain.allCases)
        }
    }

    func owns(_ domain: LiveRuntimeDomain) -> Bool {
        ownedDomains.contains(domain)
    }
}

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
    var currentDetachedItem: ProgramItem?
    var currentSwitchedAt: Date?

    var currentItem: ProgramItem? {
        guard let currentID else { return nil }
        return items.first { $0.id == currentID }
    }

    var effectiveCurrentItem: ProgramItem? {
        currentItem ?? currentDetachedItem
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

struct AudioRoutingContext: Equatable {
    var isCurrentProgramMediaSource = false
    var isMediaPlaying = false
    var isBGMPlaying = false
    var isPanicMode = false
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
    var routingContext = AudioRoutingContext()
    var effectiveMedia: Float = 0
    var effectiveBGM: Float = 0
}

struct AudioFacadeSnapshot: Equatable {
    var masterVolume: Double
    var mediaVolume: Double
    var bgmVolume: Double
    var strategy: AudioStrategy
    var isMasterMuted: Bool
    var isMediaMuted: Bool
    var isBGMMuted: Bool
    var isSpeakerMode: Bool
    var isBGMTakeoverActive: Bool
    var isPanicMode: Bool
    var isCurrentProgramMediaSource: Bool
    var isMediaPlaying: Bool
    var isBGMPlaying: Bool
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
    var themeOverride: ThemeOverride = .dark
    var activeWallpaperURL: URL?
    var cornerLogoURL: URL?
    var autoPlayNextVideoOnEnd = false
    var autoAdvanceAtScheduledTime = false
    var showAgendaTimeline = false
    var cornerLogoPosition: CornerLogoPosition = .topRight
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
        while events.count > eventLimit {
            guard let indexToRemove = events.indices.min(by: { lhs, rhs in
                let lhsPriority = LiveSupportEventPriorityPolicy.priority(for: events[lhs].kind)
                let rhsPriority = LiveSupportEventPriorityPolicy.priority(for: events[rhs].kind)
                if lhsPriority == rhsPriority {
                    return events[lhs].timestamp < events[rhs].timestamp
                }
                return lhsPriority < rhsPriority
            }) else {
                return
            }
            events.remove(at: indexToRemove)
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
    var speakerModeDuckedRatio: Float
    var bridgeMode: LiveRuntimeBridgeMode

    init(
        now: Date = Date(),
        speakerModeDuckedRatio: Float = AudioRoutingDefaults.speakerModeDuckedRatio,
        bridgeMode: LiveRuntimeBridgeMode
    ) {
        self.now = now
        self.speakerModeDuckedRatio = speakerModeDuckedRatio
        self.bridgeMode = bridgeMode
    }

    static func productionAudioOwned(
        now: Date = Date(),
        speakerModeDuckedRatio: Float = AudioRoutingDefaults.speakerModeDuckedRatio
    ) -> LiveRuntimeEnvironment {
        LiveRuntimeEnvironment(
            now: now,
            speakerModeDuckedRatio: speakerModeDuckedRatio,
            bridgeMode: .audioOwned
        )
    }

    static func productionMediaOwned(
        now: Date = Date(),
        speakerModeDuckedRatio: Float = AudioRoutingDefaults.speakerModeDuckedRatio
    ) -> LiveRuntimeEnvironment {
        LiveRuntimeEnvironment(
            now: now,
            speakerModeDuckedRatio: speakerModeDuckedRatio,
            bridgeMode: .mediaOwned
        )
    }

    static func productionBGMOwning(
        now: Date = Date(),
        speakerModeDuckedRatio: Float = AudioRoutingDefaults.speakerModeDuckedRatio
    ) -> LiveRuntimeEnvironment {
        LiveRuntimeEnvironment(
            now: now,
            speakerModeDuckedRatio: speakerModeDuckedRatio,
            bridgeMode: .bgmOwned
        )
    }

    static func productionProjectionOwned(
        now: Date = Date(),
        speakerModeDuckedRatio: Float = AudioRoutingDefaults.speakerModeDuckedRatio
    ) -> LiveRuntimeEnvironment {
        LiveRuntimeEnvironment(
            now: now,
            speakerModeDuckedRatio: speakerModeDuckedRatio,
            bridgeMode: .projectionOwned
        )
    }

    static func productionPPTOwning(
        now: Date = Date(),
        speakerModeDuckedRatio: Float = AudioRoutingDefaults.speakerModeDuckedRatio
    ) -> LiveRuntimeEnvironment {
        LiveRuntimeEnvironment(
            now: now,
            speakerModeDuckedRatio: speakerModeDuckedRatio,
            bridgeMode: .pptOwned
        )
    }

    static func fullRuntimeForTests(
        now: Date = Date(),
        speakerModeDuckedRatio: Float = AudioRoutingDefaults.speakerModeDuckedRatio
    ) -> LiveRuntimeEnvironment {
        LiveRuntimeEnvironment(
            now: now,
            speakerModeDuckedRatio: speakerModeDuckedRatio,
            bridgeMode: .fullRuntime
        )
    }

    static func recordingOnlyForTests(
        now: Date = Date(),
        speakerModeDuckedRatio: Float = AudioRoutingDefaults.speakerModeDuckedRatio
    ) -> LiveRuntimeEnvironment {
        LiveRuntimeEnvironment(
            now: now,
            speakerModeDuckedRatio: speakerModeDuckedRatio,
            bridgeMode: .recordingOnly
        )
    }
}

struct LiveRuntimeActionLogEntry: Equatable {
    var timestamp: Date
    var actionName: String
    var oldStateSummary: String
    var newStateSummary: String
}
