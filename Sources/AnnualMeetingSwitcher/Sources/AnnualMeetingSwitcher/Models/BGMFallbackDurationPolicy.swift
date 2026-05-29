import Foundation

enum BGMFallbackDurationPolicy {
    static func knownDuration(storedDuration: Double?, itemDuration: Double?) -> Double? {
        if let storedDuration, storedDuration > 0, storedDuration.isFinite {
            return storedDuration
        }

        guard let itemDuration, itemDuration > 0, itemDuration.isFinite else {
            return nil
        }
        return itemDuration
    }
}
