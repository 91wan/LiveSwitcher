import Foundation

enum BGMReturnToStartPlan: Equatable {
    case immediate
    case smoothed(fadeOut: TimeInterval, fadeIn: TimeInterval)
    case noOp
}

enum BGMReturnToStartSmoothingPolicy {
    static let fadeOutDuration: TimeInterval = 0.1
    static let fadeInDuration: TimeInterval = 0.15

    static func plan(
        phase: BGMPlaybackPhase,
        effectiveBGM: Float,
        isMuted: Bool,
        panicActive: Bool
    ) -> BGMReturnToStartPlan {
        guard phase != .idle else { return .noOp }
        guard phase == .playing else { return .immediate }
        guard !panicActive else { return .immediate }
        guard !isMuted, effectiveBGM.isFinite, effectiveBGM > 0 else { return .immediate }
        return .smoothed(fadeOut: fadeOutDuration, fadeIn: fadeInDuration)
    }
}
