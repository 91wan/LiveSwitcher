import Foundation

@MainActor
extension SwitcherViewModel {
    // MARK: - BGM Runtime Playback

    func prepareRuntimeBGM(_ item: BGMItem, generation: Int) {
        prepareRuntimeBGMPlayer(item, generation: generation)
    }

    func playRuntimeBGM(generation: Int) {
        playCurrentRuntimeBGM(generation: generation)
    }

    func pauseRuntimeBGM(generation: Int) {
        pauseCurrentRuntimeBGM(generation: generation)
    }

    func stopRuntimeBGM(fade: TimeInterval, generation: Int) {
        stopCurrentRuntimeBGM(fade: fade, generation: generation)
    }

    func setRuntimeBGMVolume(_ volume: Float, fade: TimeInterval, generation: Int) {
        applyRuntimeBGMVolume(volume, fade: fade, generation: generation)
    }

    func seekRuntimeBGMToBeginning(generation: Int) {
        seekRuntimeBGMToBeginningWithSmoothing(generation: generation)
    }

    func seekRuntimeBGM(toProgress progress: Double, generation: Int) {
        seekRuntimeBGMProgress(progress, generation: generation)
    }

    func setRuntimeBGMPlayMode(_ playMode: BGMPlayMode, generation: Int?) {
        applyRuntimeBGMPlayMode(playMode, generation: generation)
    }

    func startBGMTimer(generation: Int) {
        startRuntimeBGMTimer(generation: generation)
    }

    func stopBGMTimer(generation: Int) {
        stopRuntimeBGMTimer(generation: generation)
    }
}
