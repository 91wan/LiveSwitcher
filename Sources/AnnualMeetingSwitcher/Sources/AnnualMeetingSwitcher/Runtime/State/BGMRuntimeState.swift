import Foundation

enum BGMPlaybackPhase: Equatable {
    case idle
    case selected
    case playing
    case paused
}

struct BGMRuntimeState: Equatable {
    var items: [BGMItem] = []
    var currentID: UUID?
    var phase: BGMPlaybackPhase = .idle
    var playMode: BGMPlayMode = .loopAll
    var progress: Double = 0
    var currentTime: Double = 0
    var duration: Double?
    var generation = 0

    var isPlaying: Bool {
        phase == .playing
    }

    var currentItem: BGMItem? {
        guard let currentID else { return nil }
        return items.first { $0.id == currentID }
    }
}
