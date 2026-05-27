import Foundation

enum AudioFadeStepPolicy {
    static let minimumSteps = 12
    static let maximumSteps = 60
    static let targetStepsPerSecond = 30.0

    static func stepCount(duration: Double) -> Int {
        guard duration.isFinite, duration > 0 else { return 1 }
        let requestedSteps = Int(ceil(duration * targetStepsPerSecond))
        return min(max(requestedSteps, minimumSteps), maximumSteps)
    }
}
