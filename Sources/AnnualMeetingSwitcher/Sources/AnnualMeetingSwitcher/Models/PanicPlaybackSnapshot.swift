import Foundation

struct PanicPlaybackSnapshot: Equatable {
    var currentProgramID: UUID?
    var wasMediaPlaying: Bool
    var currentBGMID: UUID?
    var wasBGMPlaying: Bool
}

