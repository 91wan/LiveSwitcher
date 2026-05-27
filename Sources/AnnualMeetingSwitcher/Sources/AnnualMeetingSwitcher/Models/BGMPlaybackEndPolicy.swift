import Foundation

enum BGMPlaybackEndPolicy {
    static func shouldTreatAsFinished(
        isPlaying: Bool,
        playMode: BGMPlayMode,
        currentTime: TimeInterval,
        duration: TimeInterval?
    ) -> Bool {
        guard isPlaying, playMode != .loopOne else { return false }
        guard currentTime.isFinite, let duration, duration.isFinite, duration > 0 else { return false }
        return currentTime >= duration
    }

    static func numberOfLoops(for playMode: BGMPlayMode) -> Int {
        playMode == .loopOne ? -1 : 0
    }
}
