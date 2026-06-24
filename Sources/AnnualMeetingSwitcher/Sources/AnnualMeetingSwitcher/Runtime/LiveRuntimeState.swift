import Foundation

enum LiveRuntimeBridgeMode: String, CaseIterable, Equatable {
    case recordingOnly
    case audioOwned
    case mediaOwned
    case bgmOwned
    case projectionOwned
    case pptOwned
    case automationNoticeOwned
    case supportOwned
    case automationCommandOwned
    case presentationQueryOwned
    case programQueueOwned
    case programSelectionOwned
    case programActivationOwned
    case panicOwned
    case fullRuntime
}

enum LiveRuntimeDomain: String, CaseIterable, Equatable {
    case audio
    case media
    case bgm
    case projection
    case panic
    case ppt
    case automationNotice
    case automation
    case automationCommand
    case presentationQuery
    case programQueue
    case programSelection
    case programActivation
    case support
    case imageAssets
    case persistence
}

extension LiveRuntimeBridgeMode {
    var ownedDomains: Set<LiveRuntimeDomain> {
        switch self {
        case .recordingOnly:
            return []
        case .audioOwned:
            return [.audio, .imageAssets, .persistence]
        case .mediaOwned:
            return [.audio, .media, .imageAssets, .persistence]
        case .bgmOwned:
            return [.audio, .media, .bgm, .imageAssets, .persistence]
        case .projectionOwned:
            return [.audio, .media, .bgm, .projection, .imageAssets, .persistence]
        case .pptOwned:
            return [.audio, .media, .bgm, .projection, .ppt, .imageAssets, .persistence]
        case .automationNoticeOwned:
            return [.audio, .media, .bgm, .projection, .ppt, .automationNotice, .imageAssets, .persistence]
        case .supportOwned:
            return [.audio, .media, .bgm, .projection, .ppt, .automationNotice, .support, .imageAssets, .persistence]
        case .automationCommandOwned:
            return [.audio, .media, .bgm, .projection, .ppt, .automationNotice, .support, .automationCommand, .imageAssets, .persistence]
        case .presentationQueryOwned:
            return [.audio, .media, .bgm, .projection, .ppt, .automationNotice, .support, .automationCommand, .presentationQuery, .imageAssets, .persistence]
        case .programQueueOwned:
            return [.audio, .media, .bgm, .projection, .ppt, .automationNotice, .support, .automationCommand, .presentationQuery, .programQueue, .imageAssets, .persistence]
        case .programSelectionOwned:
            return [.audio, .media, .bgm, .projection, .ppt, .automationNotice, .support, .automationCommand, .presentationQuery, .programQueue, .programSelection, .imageAssets, .persistence]
        case .programActivationOwned:
            return [.audio, .media, .bgm, .projection, .ppt, .automationNotice, .support, .automationCommand, .presentationQuery, .programQueue, .programSelection, .programActivation, .imageAssets, .persistence]
        case .panicOwned:
            return [.audio, .media, .bgm, .projection, .panic, .ppt, .automationNotice, .support, .automationCommand, .presentationQuery, .programQueue, .programSelection, .programActivation, .imageAssets, .persistence]
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
    var programActivation = ProgramActivationRuntimeState()
    var media = MediaRuntimeState()
    var bgm = BGMRuntimeState()
    var audio = AudioRuntimeState()
    var panic = PanicRuntimeState()
    var ppt = PPTRuntimeState()
    var projection = ProjectionRuntimeState()
    var automation = AutomationRuntimeState()
    var presentationQuery = PresentationQueryRuntimeState()
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

enum BGMPlaybackPhase: Equatable {
    case idle
    case selected
    case playing
    case paused
}

struct BGMRuntimeState: Equatable {
    var items: [BGMItem] = []
    var currentID: UUID?
    var phase: BGMPlaybackPhase = .idle
    var playMode: BGMPlayMode = .loopAll
    var progress: Double = 0
    var currentTime: Double = 0
    var duration: Double?
    var generation = 0

    var isPlaying: Bool {
        phase == .playing
    }

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
    var strategy: AudioStrategy = .followProgram
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

struct PresentationQueryRuntimeState: Equatable {
    static let consumedRequestLimit = 20

    var activeRequestID: UUID?
    var latestCompletedRequestID: UUID?
    var latestResult: PresentationQueryResult?
    var latestFailure: PresentationQueryFailure?
    var consumedRequestIDs: [UUID] = []

    func hasConsumed(_ id: UUID) -> Bool {
        consumedRequestIDs.contains(id)
    }

    mutating func markConsumed(_ id: UUID) {
        if !hasConsumed(id) {
            consumedRequestIDs.append(id)
        }
        if latestCompletedRequestID == id {
            latestCompletedRequestID = nil
            latestResult = nil
        }
        if latestFailure?.id == id {
            latestFailure = nil
        }
        if consumedRequestIDs.count > Self.consumedRequestLimit {
            consumedRequestIDs.removeFirst(consumedRequestIDs.count - Self.consumedRequestLimit)
        }
    }
}

struct PresentationQueryFailure: Equatable {
    var id: UUID
    var action: String
    var sanitizedMessage: String
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

    @discardableResult
    mutating func record(event: LiveSupportEvent) -> LiveSupportEvent? {
        record(kind: event.kind, detail: event.detail, at: event.timestamp)
    }

    @discardableResult
    mutating func record(kind: LiveSupportEventKind, detail: String, at date: Date) -> LiveSupportEvent? {
        let baseDetail = LiveSupportRedactor.safeEventDetail(detail)
        let key = "\(kind.rawValue)|\(baseDetail)"

        if shouldCoalesce(kind),
           let index = events.firstIndex(where: { $0.kind == kind && supportEventBaseDetail($0.detail) == baseDetail }) {
            let existing = events.remove(at: index)
            let nextCount = supportEventCoalescedCount(existing.detail) + 1
            coalescedCounts[key] = nextCount
            let accepted = LiveSupportEvent(
                timestamp: date,
                kind: kind,
                detail: "\(baseDetail),count=\(nextCount),lastSeen=\(Self.isoString(date))"
            )
            events.append(accepted)
            trimToLimit()
            return events.contains(accepted) ? accepted : nil
        }

        coalescedCounts[key] = 1
        let accepted = LiveSupportEvent(timestamp: date, kind: kind, detail: baseDetail)
        events.append(accepted)
        trimToLimit()
        return events.contains(accepted) ? accepted : nil
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
    var liveAudioFadeDuration: Double
    var bridgeMode: LiveRuntimeBridgeMode

    init(
        now: Date = Date(),
        speakerModeDuckedRatio: Float = AudioRoutingDefaults.speakerModeDuckedRatio,
        liveAudioFadeDuration: Double = AudioRoutingDefaults.liveAudioFadeDuration,
        bridgeMode: LiveRuntimeBridgeMode
    ) {
        self.now = now
        self.speakerModeDuckedRatio = speakerModeDuckedRatio
        self.liveAudioFadeDuration = liveAudioFadeDuration
        self.bridgeMode = bridgeMode
    }

    static func productionAudioOwned(
        now: Date = Date(),
        speakerModeDuckedRatio: Float = AudioRoutingDefaults.speakerModeDuckedRatio,
        liveAudioFadeDuration: Double = AudioRoutingDefaults.liveAudioFadeDuration
    ) -> LiveRuntimeEnvironment {
        LiveRuntimeEnvironment(
            now: now,
            speakerModeDuckedRatio: speakerModeDuckedRatio,
            liveAudioFadeDuration: liveAudioFadeDuration,
            bridgeMode: .audioOwned
        )
    }

    static func productionMediaOwned(
        now: Date = Date(),
        speakerModeDuckedRatio: Float = AudioRoutingDefaults.speakerModeDuckedRatio,
        liveAudioFadeDuration: Double = AudioRoutingDefaults.liveAudioFadeDuration
    ) -> LiveRuntimeEnvironment {
        LiveRuntimeEnvironment(
            now: now,
            speakerModeDuckedRatio: speakerModeDuckedRatio,
            liveAudioFadeDuration: liveAudioFadeDuration,
            bridgeMode: .mediaOwned
        )
    }

    static func productionBGMOwning(
        now: Date = Date(),
        speakerModeDuckedRatio: Float = AudioRoutingDefaults.speakerModeDuckedRatio,
        liveAudioFadeDuration: Double = AudioRoutingDefaults.liveAudioFadeDuration
    ) -> LiveRuntimeEnvironment {
        LiveRuntimeEnvironment(
            now: now,
            speakerModeDuckedRatio: speakerModeDuckedRatio,
            liveAudioFadeDuration: liveAudioFadeDuration,
            bridgeMode: .bgmOwned
        )
    }

    static func productionProjectionOwned(
        now: Date = Date(),
        speakerModeDuckedRatio: Float = AudioRoutingDefaults.speakerModeDuckedRatio,
        liveAudioFadeDuration: Double = AudioRoutingDefaults.liveAudioFadeDuration
    ) -> LiveRuntimeEnvironment {
        LiveRuntimeEnvironment(
            now: now,
            speakerModeDuckedRatio: speakerModeDuckedRatio,
            liveAudioFadeDuration: liveAudioFadeDuration,
            bridgeMode: .projectionOwned
        )
    }

    static func productionPPTOwning(
        now: Date = Date(),
        speakerModeDuckedRatio: Float = AudioRoutingDefaults.speakerModeDuckedRatio,
        liveAudioFadeDuration: Double = AudioRoutingDefaults.liveAudioFadeDuration
    ) -> LiveRuntimeEnvironment {
        LiveRuntimeEnvironment(
            now: now,
            speakerModeDuckedRatio: speakerModeDuckedRatio,
            liveAudioFadeDuration: liveAudioFadeDuration,
            bridgeMode: .pptOwned
        )
    }

    static func productionAutomationNoticeOwning(
        now: Date = Date(),
        speakerModeDuckedRatio: Float = AudioRoutingDefaults.speakerModeDuckedRatio,
        liveAudioFadeDuration: Double = AudioRoutingDefaults.liveAudioFadeDuration
    ) -> LiveRuntimeEnvironment {
        LiveRuntimeEnvironment(
            now: now,
            speakerModeDuckedRatio: speakerModeDuckedRatio,
            liveAudioFadeDuration: liveAudioFadeDuration,
            bridgeMode: .automationNoticeOwned
        )
    }

    static func productionSupportOwning(
        now: Date = Date(),
        speakerModeDuckedRatio: Float = AudioRoutingDefaults.speakerModeDuckedRatio,
        liveAudioFadeDuration: Double = AudioRoutingDefaults.liveAudioFadeDuration
    ) -> LiveRuntimeEnvironment {
        LiveRuntimeEnvironment(
            now: now,
            speakerModeDuckedRatio: speakerModeDuckedRatio,
            liveAudioFadeDuration: liveAudioFadeDuration,
            bridgeMode: .supportOwned
        )
    }

    static func productionAutomationCommandOwning(
        now: Date = Date(),
        speakerModeDuckedRatio: Float = AudioRoutingDefaults.speakerModeDuckedRatio,
        liveAudioFadeDuration: Double = AudioRoutingDefaults.liveAudioFadeDuration
    ) -> LiveRuntimeEnvironment {
        LiveRuntimeEnvironment(
            now: now,
            speakerModeDuckedRatio: speakerModeDuckedRatio,
            liveAudioFadeDuration: liveAudioFadeDuration,
            bridgeMode: .automationCommandOwned
        )
    }

    static func productionPresentationQueryOwning(
        now: Date = Date(),
        speakerModeDuckedRatio: Float = AudioRoutingDefaults.speakerModeDuckedRatio,
        liveAudioFadeDuration: Double = AudioRoutingDefaults.liveAudioFadeDuration
    ) -> LiveRuntimeEnvironment {
        LiveRuntimeEnvironment(
            now: now,
            speakerModeDuckedRatio: speakerModeDuckedRatio,
            liveAudioFadeDuration: liveAudioFadeDuration,
            bridgeMode: .presentationQueryOwned
        )
    }

    static func productionProgramQueueOwning(
        now: Date = Date(),
        speakerModeDuckedRatio: Float = AudioRoutingDefaults.speakerModeDuckedRatio,
        liveAudioFadeDuration: Double = AudioRoutingDefaults.liveAudioFadeDuration
    ) -> LiveRuntimeEnvironment {
        LiveRuntimeEnvironment(
            now: now,
            speakerModeDuckedRatio: speakerModeDuckedRatio,
            liveAudioFadeDuration: liveAudioFadeDuration,
            bridgeMode: .programQueueOwned
        )
    }

    static func productionProgramSelectionOwning(
        now: Date = Date(),
        speakerModeDuckedRatio: Float = AudioRoutingDefaults.speakerModeDuckedRatio,
        liveAudioFadeDuration: Double = AudioRoutingDefaults.liveAudioFadeDuration
    ) -> LiveRuntimeEnvironment {
        LiveRuntimeEnvironment(
            now: now,
            speakerModeDuckedRatio: speakerModeDuckedRatio,
            liveAudioFadeDuration: liveAudioFadeDuration,
            bridgeMode: .programSelectionOwned
        )
    }

    static func productionProgramActivationOwning(
        now: Date = Date(),
        speakerModeDuckedRatio: Float = AudioRoutingDefaults.speakerModeDuckedRatio,
        liveAudioFadeDuration: Double = AudioRoutingDefaults.liveAudioFadeDuration
    ) -> LiveRuntimeEnvironment {
        LiveRuntimeEnvironment(
            now: now,
            speakerModeDuckedRatio: speakerModeDuckedRatio,
            liveAudioFadeDuration: liveAudioFadeDuration,
            bridgeMode: .programActivationOwned
        )
    }

    static func productionPanicOwning(
        now: Date = Date(),
        speakerModeDuckedRatio: Float = AudioRoutingDefaults.speakerModeDuckedRatio,
        liveAudioFadeDuration: Double = AudioRoutingDefaults.liveAudioFadeDuration
    ) -> LiveRuntimeEnvironment {
        LiveRuntimeEnvironment(
            now: now,
            speakerModeDuckedRatio: speakerModeDuckedRatio,
            liveAudioFadeDuration: liveAudioFadeDuration,
            bridgeMode: .panicOwned
        )
    }

    static func fullRuntimeForTests(
        now: Date = Date(),
        speakerModeDuckedRatio: Float = AudioRoutingDefaults.speakerModeDuckedRatio,
        liveAudioFadeDuration: Double = AudioRoutingDefaults.liveAudioFadeDuration
    ) -> LiveRuntimeEnvironment {
        LiveRuntimeEnvironment(
            now: now,
            speakerModeDuckedRatio: speakerModeDuckedRatio,
            liveAudioFadeDuration: liveAudioFadeDuration,
            bridgeMode: .fullRuntime
        )
    }

    static func recordingOnlyForTests(
        now: Date = Date(),
        speakerModeDuckedRatio: Float = AudioRoutingDefaults.speakerModeDuckedRatio,
        liveAudioFadeDuration: Double = AudioRoutingDefaults.liveAudioFadeDuration
    ) -> LiveRuntimeEnvironment {
        LiveRuntimeEnvironment(
            now: now,
            speakerModeDuckedRatio: speakerModeDuckedRatio,
            liveAudioFadeDuration: liveAudioFadeDuration,
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
