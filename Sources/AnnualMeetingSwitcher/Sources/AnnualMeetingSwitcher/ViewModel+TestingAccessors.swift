import Foundation

@MainActor
extension SwitcherViewModel {
    func setBGMTransitionGenerationForRuntime(_ generation: Int) {
        bgmTransitionGeneration = generation
    }

    func incrementBGMTransitionGenerationForRuntime() {
        bgmTransitionGeneration += 1
    }

    func currentBGMTransitionGenerationForRuntime() -> Int {
        bgmTransitionGeneration
    }

    func setActiveBGMTimerGenerationForRuntime(_ generation: Int?) {
        activeBGMTimerGeneration = generation
    }

    func activeBGMTimerGenerationForRuntime() -> Int? {
        activeBGMTimerGeneration
    }

    func resetLastAudioRoutingTransitionForTesting() {
        applyLastAudioRoutingTransitionFromRuntime(nil)
    }

    var activeRuntimeMediaCallbackGenerationForTesting: Int? {
        runtimeIdentityStore.activeMediaGeneration
    }

    var activeRuntimeMediaCallbackURLForTesting: URL? {
        runtimeIdentityStore.activeMediaURL
    }

    var bgmTransitionGenerationForTesting: Int {
        bgmTransitionGeneration
    }

    var bgmProgressTimerForTesting: Timer? {
        cleanupBag.bgmProgressTimer
    }

    var activeBGMTimerGenerationForTesting: Int? {
        activeBGMTimerGeneration
    }

    var activeRuntimeBGMCallbackGenerationForTesting: Int? {
        runtimeIdentityStore.activeBGMGeneration
    }

    var activeRuntimeBGMCallbackItemIDForTesting: UUID? {
        runtimeIdentityStore.activeBGMItemID
    }

    var activeRuntimeBGMCallbackURLForTesting: URL? {
        runtimeIdentityStore.activeBGMURL
    }

    func seedActiveRuntimeBGMCallbackForTesting(item: BGMItem, generation: Int) {
        setActiveRuntimeBGMCallbackIdentity(item: item, generation: generation)
    }

    func invalidateBGMTransitionGeneration() {
        incrementBGMTransitionGenerationForRuntime()
    }
}
