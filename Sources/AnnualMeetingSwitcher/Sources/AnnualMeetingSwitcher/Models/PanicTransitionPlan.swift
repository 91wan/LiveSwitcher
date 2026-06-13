struct PanicActivationPlan: Equatable {
    var snapshot: PanicPlaybackSnapshot
    var shouldPauseMediaImmediately: Bool
    var shouldPauseBGMAfterFade: Bool
}

struct PanicDeactivationPlan: Equatable {
    var snapshot: PanicPlaybackSnapshot?
    var shouldResumeMedia: Bool
    var shouldResumeBGM: Bool
}

