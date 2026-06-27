struct AudioRoutingContext: Equatable {
    var isCurrentProgramMediaSource = false
    var isMediaPlaying = false
    var isBGMPlaying = false
    var isPanicMode = false
}

struct AudioRuntimeState: Equatable {
    var masterVolume: Double = 0.5
    var mediaVolume: Double = 1
    var bgmVolume: Double = 0.5
    var strategy: AudioStrategy = .followProgram
    var isMasterMuted = false
    var isMediaMuted = false
    var isBGMMuted = false
    var isSpeakerMode = false
    var isBGMTakeoverActive = false
    var routingContext = AudioRoutingContext()
    var effectiveMedia: Float = 0
    var effectiveBGM: Float = 0
}

struct AudioFacadeSnapshot: Equatable {
    var masterVolume: Double
    var mediaVolume: Double
    var bgmVolume: Double
    var strategy: AudioStrategy
    var isMasterMuted: Bool
    var isMediaMuted: Bool
    var isBGMMuted: Bool
    var isSpeakerMode: Bool
    var isBGMTakeoverActive: Bool
    var isPanicMode: Bool
    var isCurrentProgramMediaSource: Bool
    var isMediaPlaying: Bool
    var isBGMPlaying: Bool
}
