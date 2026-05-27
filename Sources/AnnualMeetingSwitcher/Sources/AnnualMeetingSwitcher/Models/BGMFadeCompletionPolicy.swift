import Foundation

enum BGMFadeCompletionPolicy {
    static func pauseDelay(fadeDuration: Double) -> Double {
        guard fadeDuration > 0, fadeDuration.isFinite else { return 0 }
        return fadeDuration + min(0.1, max(0.03, fadeDuration / 20.0))
    }
}
