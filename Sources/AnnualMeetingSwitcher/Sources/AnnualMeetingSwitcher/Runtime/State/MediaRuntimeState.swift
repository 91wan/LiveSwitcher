import Foundation

struct MediaRuntimeState: Equatable {
    var loadedURL: URL?
    var isPlaying = false
    var didPlayToEnd = false
    var currentTime: Double = 0
    var duration: Double?
    var generation = 0
}
