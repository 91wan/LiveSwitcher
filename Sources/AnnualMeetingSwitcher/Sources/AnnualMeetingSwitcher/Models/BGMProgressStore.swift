import Foundation
import Combine

@MainActor
final class BGMProgressStore: ObservableObject {
    static let updateInterval: TimeInterval = 0.1

    @Published var progress: Double = 0
    @Published var currentTime: Double = 0
    @Published var duration: Double?

    func update(currentTime: Double, duration: Double) {
        let state = PlaybackProgressPolicy.displayState(currentTime: currentTime, duration: duration)
        self.currentTime = state.currentTime
        self.duration = state.duration
        progress = state.progress
    }

    func reset() {
        progress = 0
        currentTime = 0
        duration = nil
    }

    static func clampedProgress(_ value: Double) -> Double {
        PlaybackProgressPolicy.clampedProgress(value)
    }
}
