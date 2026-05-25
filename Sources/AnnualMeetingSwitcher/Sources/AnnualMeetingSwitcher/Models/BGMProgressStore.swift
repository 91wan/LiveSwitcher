import Foundation
import Combine

@MainActor
final class BGMProgressStore: ObservableObject {
    static let updateInterval: TimeInterval = 0.1

    @Published var progress: Double = 0
    @Published var currentTime: Double = 0
    @Published var duration: Double?

    func update(currentTime: Double, duration: Double) {
        let safeCurrentTime = max(0, currentTime)
        self.currentTime = safeCurrentTime
        guard duration > 0 else {
            self.duration = nil
            progress = 0
            return
        }
        self.duration = duration
        progress = Self.clampedProgress(safeCurrentTime / duration)
    }

    func reset() {
        progress = 0
        currentTime = 0
        duration = nil
    }

    static func clampedProgress(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return min(max(value, 0), 1)
    }
}
