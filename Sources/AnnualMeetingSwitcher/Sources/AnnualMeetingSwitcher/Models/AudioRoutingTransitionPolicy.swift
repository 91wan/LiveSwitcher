import Foundation

enum AudioRoutingRuntimeChangeReason: Equatable {
    case programChanged
    case mediaPlaybackChanged
    case strategyChanged
    case speakerChanged
    case panicChanged
    case bgmPlaybackChanged
    case operatorFaderChanged
}

struct AudioRoutingTransition: Equatable {
    let reason: AudioRoutingRuntimeChangeReason
    let mediaFadeDuration: Double?
    let bgmFadeDuration: Double?
}

enum AudioRoutingTransitionPolicy {
    static let operatorFaderDuration: Double = 0

    static func transition(
        for reason: AudioRoutingRuntimeChangeReason,
        liveAudioFadeDuration: Double
    ) -> AudioRoutingTransition {
        switch reason {
        case .operatorFaderChanged:
            return AudioRoutingTransition(
                reason: reason,
                mediaFadeDuration: operatorFaderDuration,
                bgmFadeDuration: operatorFaderDuration
            )
        case .programChanged,
             .mediaPlaybackChanged,
             .strategyChanged,
             .speakerChanged,
             .panicChanged,
             .bgmPlaybackChanged:
            return AudioRoutingTransition(
                reason: reason,
                mediaFadeDuration: liveAudioFadeDuration,
                bgmFadeDuration: liveAudioFadeDuration
            )
        }
    }
}
