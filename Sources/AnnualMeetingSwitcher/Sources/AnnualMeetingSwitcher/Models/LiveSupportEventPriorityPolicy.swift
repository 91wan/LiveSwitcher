import Foundation

enum LiveSupportEventPriority: Int, Comparable {
    case low = 0
    case normal = 1
    case high = 2
    case critical = 3

    static func < (lhs: LiveSupportEventPriority, rhs: LiveSupportEventPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

enum LiveSupportEventPriorityPolicy {
    static func priority(for kind: LiveSupportEventKind) -> LiveSupportEventPriority {
        switch kind {
        case .panicModeChanged,
             .projectionLost,
             .bgmPlaybackFailed,
             .projectionStartFailed:
            return .critical
        case .appleScriptFailed,
             .pageInterceptDisabled,
             .pageInterceptWPSNotRunning:
            return .high
        case .bgmPlaybackChanged,
             .playbackReachedEnd,
             .mediaRestarted:
            return .normal
        case .pageInterceptForwardedToWPS,
             .systemVolumeSynced:
            return .low
        default:
            return .normal
        }
    }
}
