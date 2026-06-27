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
