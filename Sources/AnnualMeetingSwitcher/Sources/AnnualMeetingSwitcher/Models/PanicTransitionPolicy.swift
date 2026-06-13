enum PanicTransitionPolicy {
    static func snapshot(
        currentProgram: ProgramItem?,
        isMediaPlaying: Bool,
        currentBGM: BGMItem?,
        isBGMPlaying: Bool
    ) -> PanicPlaybackSnapshot {
        PanicPlaybackSnapshot(
            currentProgramID: currentProgram?.id,
            wasMediaPlaying: currentProgram?.sourceKind == .media && isMediaPlaying,
            currentBGMID: currentBGM?.id,
            wasBGMPlaying: currentBGM != nil && isBGMPlaying
        )
    }

    static func shouldPauseMediaForActivation(
        snapshot: PanicPlaybackSnapshot?,
        currentProgram: ProgramItem?
    ) -> Bool {
        mediaMatches(snapshot: snapshot, currentProgram: currentProgram)
    }

    static func shouldPauseBGMAfterFadeForActivation(
        snapshot: PanicPlaybackSnapshot?,
        currentBGM: BGMItem?
    ) -> Bool {
        bgmMatches(snapshot: snapshot, currentBGM: currentBGM)
    }

    static func shouldResumeMediaAfterDeactivation(
        snapshot: PanicPlaybackSnapshot?,
        currentProgram: ProgramItem?
    ) -> Bool {
        mediaMatches(snapshot: snapshot, currentProgram: currentProgram)
    }

    static func shouldResumeBGMAfterDeactivation(
        snapshot: PanicPlaybackSnapshot?,
        currentBGM: BGMItem?
    ) -> Bool {
        bgmMatches(snapshot: snapshot, currentBGM: currentBGM)
    }

    private static func mediaMatches(
        snapshot: PanicPlaybackSnapshot?,
        currentProgram: ProgramItem?
    ) -> Bool {
        guard let snapshot, snapshot.wasMediaPlaying else { return false }
        guard let currentProgram, currentProgram.sourceKind == .media else { return false }
        return currentProgram.id == snapshot.currentProgramID
    }

    private static func bgmMatches(
        snapshot: PanicPlaybackSnapshot?,
        currentBGM: BGMItem?
    ) -> Bool {
        guard let snapshot, snapshot.wasBGMPlaying else { return false }
        return currentBGM?.id == snapshot.currentBGMID
    }
}

