import XCTest
@testable import LiveSwitcher

final class AudioRuntimeOwnershipGuardTests: XCTestCase {
    func testAudioOperatorActionsDoNotMutateAudioWhenRuntimeDoesNotOwnAudio() {
        for action in audioActions {
            var state = LiveRuntimeState()
            state.audio.masterVolume = 0.32
            state.audio.mediaVolume = 0.41
            state.audio.bgmVolume = 0.52
            state.audio.strategy = .followProgram
            state.audio.isMasterMuted = false
            state.audio.isMediaMuted = false
            state.audio.isBGMMuted = false
            state.audio.isBGMTakeoverActive = false
            state.audio.isSpeakerMode = false
            state.audio.effectiveMedia = 0.2
            state.audio.effectiveBGM = 0.3
            let originalAudio = state.audio

            let mutation = LiveRuntimeReducer.reduce(
                state: state,
                action: action,
                environment: .recordingOnlyForTests()
            )

            XCTAssertEqual(mutation.state.audio, originalAudio, "\(action)")
            XCTAssertTrue(mutation.effects.isEmpty, "\(action)")
        }
    }

    func testFacadeAudioInputsChangedDoesNotMutateAudioWhenRuntimeDoesNotOwnAudio() {
        var state = LiveRuntimeState()
        state.audio.masterVolume = 0.32
        state.audio.effectiveMedia = 0.2
        state.audio.effectiveBGM = 0.3
        let originalAudio = state.audio

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .facadeAudioInputsChanged(audioSnapshot()),
            environment: .recordingOnlyForTests()
        )

        XCTAssertEqual(mutation.state.audio, originalAudio)
        XCTAssertTrue(mutation.effects.isEmpty)
    }

    func testLiveRuntimeReducerGuardsAudioCasesWithAudioOwnership() throws {
        let source = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeReducer.swift"
        )
        for start in [
            "case .operatorSelectedAudioStrategy",
            "case .operatorChangedMasterVolume",
            "case .operatorChangedMediaVolume",
            "case .operatorChangedBGMVolume",
            "case .operatorChangedMasterMute",
            "case .operatorChangedMediaMute",
            "case .operatorChangedBGMMute",
            "case .operatorChangedBGMTakeover",
            "case .operatorToggledSpeakerMode",
            "case .operatorSetSpeakerMode",
            "case .facadeAudioInputsChanged"
        ] {
            let body = try XCTUnwrap(source.slice(from: start, to: "case ."), start)

            XCTAssertTrue(body.contains("guard isRuntimeOwned(.audio, in: bridgeMode) else { break }"), start)
        }
    }

    private var audioActions: [LiveRuntimeAction] {
        [
            .operatorSelectedAudioStrategy(.mixed),
            .operatorChangedMasterVolume(0.91),
            .operatorChangedMediaVolume(0.82),
            .operatorChangedBGMVolume(0.73),
            .operatorChangedMasterMute(true),
            .operatorChangedMediaMute(true),
            .operatorChangedBGMMute(true),
            .operatorChangedBGMTakeover(true),
            .operatorToggledSpeakerMode,
            .operatorSetSpeakerMode(true)
        ]
    }

    private func audioSnapshot() -> AudioFacadeSnapshot {
        AudioFacadeSnapshot(
            masterVolume: 0.91,
            mediaVolume: 0.82,
            bgmVolume: 0.73,
            strategy: .bgmOnly,
            isMasterMuted: true,
            isMediaMuted: true,
            isBGMMuted: true,
            isSpeakerMode: true,
            isBGMTakeoverActive: true,
            isPanicMode: true,
            isCurrentProgramMediaSource: true,
            isMediaPlaying: true,
            isBGMPlaying: true
        )
    }
}
