import Foundation

enum OverlaySpeedSelection {
    static let options: [(label: String, speed: Double)] = [
        ("慢", 55),
        ("中", 85),
        ("快", 130)
    ]

    static func nearestIndex(for speed: Double) -> Int {
        options.indices.min { lhs, rhs in
            abs(options[lhs].speed - speed) < abs(options[rhs].speed - speed)
        } ?? 1
    }

    static func speed(at index: Int) -> Double {
        let clamped = min(max(index, options.startIndex), options.index(before: options.endIndex))
        return options[clamped].speed
    }

    static func label(at index: Int) -> String {
        let clamped = min(max(index, options.startIndex), options.index(before: options.endIndex))
        return options[clamped].label
    }
}
