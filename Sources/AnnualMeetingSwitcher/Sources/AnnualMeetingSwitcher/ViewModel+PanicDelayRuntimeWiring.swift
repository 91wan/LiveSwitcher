import Foundation

@MainActor
extension SwitcherViewModel {
    func configurePanicDelayRuntimePortHandlers(_ ports: SwitcherRuntimePortBundle) {
        ports.panicDelayPort.scheduleBGMPauseHandler = { [weak self] generation, snapshot, delay, context in
            guard let self else { return }
            cleanupBag.panicAudioPauseTask?.cancel()
            cleanupBag.panicAudioPauseTaskGeneration = generation
            cleanupBag.panicAudioPauseTask = Task { @MainActor [weak self] in
                if delay > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
                guard !Task.isCancelled else { return }
                guard let self else { return }
                guard cleanupBag.panicAudioPauseTaskGeneration == generation else { return }
                context.dispatch(.panicBGMPauseDelayElapsed(generation: generation, snapshot: snapshot))
                syncBGMFacadeFromRuntime()
                syncPanicFacadeFromRuntime()
                if cleanupBag.panicAudioPauseTaskGeneration == generation {
                    cleanupBag.panicAudioPauseTask = nil
                    cleanupBag.panicAudioPauseTaskGeneration = nil
                }
            }
        }

        ports.panicDelayPort.cancelBGMPauseHandler = { [weak self] generation in
            guard let self else { return }
            guard cleanupBag.panicAudioPauseTaskGeneration == generation else { return }
            cleanupBag.panicAudioPauseTask?.cancel()
            cleanupBag.panicAudioPauseTask = nil
            cleanupBag.panicAudioPauseTaskGeneration = nil
        }
    }
}
