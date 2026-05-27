import Combine
import Foundation

@MainActor
final class AudioMeterStore: ObservableObject {
    @Published private(set) var bgmRealtimeLevelDB: Float?

    private var lastPublishedLevel: Float?

    func updateBGMRealtimeLevel(_ level: Float?) {
        guard AudioMeterPublishPolicy.shouldPublishLevel(previous: lastPublishedLevel, next: level) else {
            return
        }
        lastPublishedLevel = level
        bgmRealtimeLevelDB = level
    }

    func resetBGMRealtimeLevel() {
        updateBGMRealtimeLevel(nil)
    }
}

enum AudioMeterPublishPolicy {
    static let minimumDecibelDelta: Float = 0.6

    static func shouldPublishLevel(previous: Float?, next: Float?) -> Bool {
        switch (previous, next) {
        case (nil, nil):
            return false
        case (nil, .some), (.some, nil):
            return true
        case let (.some(previous), .some(next)):
            guard previous.isFinite, next.isFinite else {
                return previous.isFinite != next.isFinite
            }
            return abs(previous - next) >= minimumDecibelDelta
        }
    }
}
