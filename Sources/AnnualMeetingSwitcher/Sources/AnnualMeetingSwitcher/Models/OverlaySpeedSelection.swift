import Foundation

enum OverlaySpeedSelection {
    static let defaultOptions: [(label: String, speed: Double)] = [
        ("慢", 55),
        ("中", 85),
        ("快", 130)
    ]

    static func nearestIndex(for speed: Double, options: [(label: String, speed: Double)] = defaultOptions) -> Int {
        guard let first = options.first else { return 0 }
        var bestIndex = 0
        var bestDistance = abs(first.speed - speed)

        for (index, option) in options.enumerated().dropFirst() {
            let distance = abs(option.speed - speed)
            if distance < bestDistance {
                bestIndex = index
                bestDistance = distance
            }
        }

        return bestIndex
    }

    static func speed(at index: Int, options: [(label: String, speed: Double)] = defaultOptions) -> Double {
        guard !options.isEmpty else { return 0 }
        let clampedIndex = min(max(index, 0), options.count - 1)
        return options[clampedIndex].speed
    }
}
