struct PanicRuntimeState: Equatable {
    var isActive = false
    var snapshot: PanicPlaybackSnapshot?
    var generation = 0
}
