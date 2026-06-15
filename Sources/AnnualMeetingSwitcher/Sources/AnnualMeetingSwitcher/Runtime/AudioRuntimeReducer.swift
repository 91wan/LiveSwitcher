import Foundation

enum AudioRuntimeReducer {
    static func selectStrategy(
        _ strategy: AudioStrategy,
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect],
        speakerModeDuckedRatio: Float
    ) {
        state.audio.strategy = strategy
        recalculateAudio(&state, speakerModeDuckedRatio: speakerModeDuckedRatio)
        effects += [
            .applyAudioRouting(reason: .strategyChanged),
            .saveAudioStrategy(strategy)
        ]
    }

    static func changeMasterVolume(
        _ volume: Double,
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect],
        speakerModeDuckedRatio: Float
    ) {
        state.audio.masterVolume = clampedVolume(volume)
        recalculateAudio(&state, speakerModeDuckedRatio: speakerModeDuckedRatio)
        effects.append(.applyAudioRouting(reason: .operatorFaderChanged))
    }

    static func changeMediaVolume(
        _ volume: Double,
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect],
        speakerModeDuckedRatio: Float
    ) {
        state.audio.mediaVolume = clampedVolume(volume)
        recalculateAudio(&state, speakerModeDuckedRatio: speakerModeDuckedRatio)
        effects.append(.applyAudioRouting(reason: .operatorFaderChanged))
    }

    static func changeBGMVolume(
        _ volume: Double,
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect],
        speakerModeDuckedRatio: Float
    ) {
        state.audio.bgmVolume = clampedVolume(volume)
        recalculateAudio(&state, speakerModeDuckedRatio: speakerModeDuckedRatio)
        effects.append(.applyAudioRouting(reason: .operatorFaderChanged))
    }

    static func changeMasterMute(
        _ isMuted: Bool,
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect],
        speakerModeDuckedRatio: Float
    ) {
        state.audio.isMasterMuted = isMuted
        recalculateAudio(&state, speakerModeDuckedRatio: speakerModeDuckedRatio)
        effects.append(.applyAudioRouting(reason: .operatorFaderChanged))
    }

    static func changeMediaMute(
        _ isMuted: Bool,
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect],
        speakerModeDuckedRatio: Float
    ) {
        state.audio.isMediaMuted = isMuted
        recalculateAudio(&state, speakerModeDuckedRatio: speakerModeDuckedRatio)
        effects.append(.applyAudioRouting(reason: .operatorFaderChanged))
    }

    static func changeBGMMute(
        _ isMuted: Bool,
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect],
        speakerModeDuckedRatio: Float
    ) {
        state.audio.isBGMMuted = isMuted
        recalculateAudio(&state, speakerModeDuckedRatio: speakerModeDuckedRatio)
        effects.append(.applyAudioRouting(reason: .operatorFaderChanged))
    }

    static func changeBGMTakeover(
        _ isActive: Bool,
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect],
        speakerModeDuckedRatio: Float
    ) {
        state.audio.isBGMTakeoverActive = isActive
        recalculateAudio(&state, speakerModeDuckedRatio: speakerModeDuckedRatio)
        effects.append(.applyAudioRouting(reason: .limiterChanged))
    }

    static func toggleSpeakerMode(
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect],
        speakerModeDuckedRatio: Float
    ) {
        state.audio.isSpeakerMode.toggle()
        recalculateAudio(&state, speakerModeDuckedRatio: speakerModeDuckedRatio)
        effects += [
            .applyAudioRouting(reason: .speakerChanged),
            .saveSpeakerMode(state.audio.isSpeakerMode)
        ]
    }

    static func setSpeakerMode(
        _ isEnabled: Bool,
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect],
        speakerModeDuckedRatio: Float
    ) {
        state.audio.isSpeakerMode = isEnabled
        recalculateAudio(&state, speakerModeDuckedRatio: speakerModeDuckedRatio)
        effects += [
            .applyAudioRouting(reason: .speakerChanged),
            .saveSpeakerMode(isEnabled)
        ]
    }

    // Internal for domain reducers; do not call from ViewModel.
    internal static func recalculateAudio(
        _ state: inout LiveRuntimeState,
        speakerModeDuckedRatio: Float = AudioRoutingDefaults.speakerModeDuckedRatio
    ) {
        initializeRoutingContextIfNeeded(&state)
        let output = routingOutput(for: state, speakerModeDuckedRatio: speakerModeDuckedRatio)
        state.audio.effectiveMedia = output.media
        state.audio.effectiveBGM = output.bgm
    }

    private static func initializeRoutingContextIfNeeded(_ state: inout LiveRuntimeState) {
        guard state.audio.routingContext == AudioRoutingContext(),
              state.program.effectiveCurrentItem?.sourceKind == .media
                || state.media.isPlaying
                || state.bgm.isPlaying
                || state.panic.isActive
        else { return }
        syncRoutingContextFromMirrorState(&state)
    }

    // Internal for domain reducers; do not call from ViewModel.
    internal static func syncRoutingContextFromMirrorState(_ state: inout LiveRuntimeState) {
        state.audio.routingContext = AudioRoutingContext(
            isCurrentProgramMediaSource: state.program.effectiveCurrentItem?.sourceKind == .media,
            isMediaPlaying: state.media.isPlaying,
            isBGMPlaying: state.bgm.isPlaying,
            isPanicMode: state.panic.isActive
        )
    }

    internal static func applyFacadeSnapshot(
        _ snapshot: AudioFacadeSnapshot,
        to state: inout LiveRuntimeState,
        speakerModeDuckedRatio: Float
    ) {
        state.audio.masterVolume = clampedVolume(snapshot.masterVolume)
        state.audio.mediaVolume = clampedVolume(snapshot.mediaVolume)
        state.audio.bgmVolume = clampedVolume(snapshot.bgmVolume)
        state.audio.strategy = snapshot.strategy
        state.audio.isMasterMuted = snapshot.isMasterMuted
        state.audio.isMediaMuted = snapshot.isMediaMuted
        state.audio.isBGMMuted = snapshot.isBGMMuted
        state.audio.isSpeakerMode = snapshot.isSpeakerMode
        state.audio.isBGMTakeoverActive = snapshot.isBGMTakeoverActive
        state.audio.routingContext = AudioRoutingContext(
            isCurrentProgramMediaSource: snapshot.isCurrentProgramMediaSource,
            isMediaPlaying: snapshot.isMediaPlaying,
            isBGMPlaying: snapshot.isBGMPlaying,
            isPanicMode: snapshot.isPanicMode
        )

        let output = routingOutput(for: state, speakerModeDuckedRatio: speakerModeDuckedRatio)
        state.audio.effectiveMedia = output.media
        state.audio.effectiveBGM = output.bgm
    }

    private static func clampedVolume(_ volume: Double) -> Double {
        min(max(volume, 0), 1)
    }

    private static func routingOutput(
        for state: LiveRuntimeState,
        speakerModeDuckedRatio: Float
    ) -> AudioRoutingOutput {
        let context = state.audio.routingContext
        return AudioRoutingEngine.output(
            for: AudioRoutingInput(
                masterVolume: state.audio.masterVolume,
                mediaVolume: state.audio.mediaVolume,
                bgmVolume: state.audio.bgmVolume,
                audioStrategy: state.audio.strategy,
                isCurrentProgramMediaSource: context.isCurrentProgramMediaSource,
                isMediaPlaying: context.isMediaPlaying,
                isBGMAudioTakeoverActive: state.audio.isBGMTakeoverActive,
                isSpeakerMode: state.audio.isSpeakerMode,
                isPanicMode: context.isPanicMode,
                isMasterMuted: state.audio.isMasterMuted,
                isMediaMuted: state.audio.isMediaMuted,
                isBGMMuted: state.audio.isBGMMuted,
                speakerModeDuckedRatio: speakerModeDuckedRatio
            )
        )
    }
}
