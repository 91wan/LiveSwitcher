import Foundation

struct PlaybackProgressState: Equatable {
    let currentTime: Double
    let duration: Double?
    let progress: Double
}

enum PlaybackProgressPolicy {
    static func displayState(currentTime: Double, duration: Double?) -> PlaybackProgressState {
        let safeCurrentTime = currentTime.isFinite ? max(0, currentTime) : 0
        guard let duration, duration.isFinite, duration > 0 else {
            return PlaybackProgressState(currentTime: safeCurrentTime, duration: nil, progress: 0)
        }

        let displayedCurrentTime = min(safeCurrentTime, duration)
        return PlaybackProgressState(
            currentTime: displayedCurrentTime,
            duration: duration,
            progress: clampedProgress(displayedCurrentTime / duration)
        )
    }

    static func clampedProgress(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return min(max(value, 0), 1)
    }
}
