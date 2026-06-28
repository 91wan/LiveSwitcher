import XCTest
@testable import LiveSwitcher

@MainActor
final class PersistentStateRuntimeLoadAudioTests: XCTestCase {
    func testApplyPersistentStateSourceUsesRuntimeHydrationHelper() throws {
        let source = try persistentRuntimeLoadSource()

        XCTAssertTrue(source.contains("runtime.hydratePersistentOwnedState(state)"))
        XCTAssertTrue(source.contains("projectPersistentStateToFacadeDuringLoad"))
        XCTAssertFalse(source.contains("applyPersistentStateToRuntimeIfOwned"))
        XCTAssertFalse(source.contains("runtimeState.audio.strategy"))
        XCTAssertFalse(source.contains("runtimeState.audio.isSpeakerMode"))
        XCTAssertFalse(source.contains("runtimeState.bgm.playMode"))
        XCTAssertFalse(source.contains("runtimeState.preferences ="))
        XCTAssertFalse(source.contains("AudioRuntimeReducer.recalculateAudio"))
        XCTAssertFalse(source.contains("replaceStateForPersistentLoad"))
    }

    func testRecordingOnlyPersistentLoadMirrorsFacadeAudioIntoRuntimeShadow() {
        let viewModel = persistentRuntimeLoadMakeViewModel(bridgeMode: .recordingOnly)

        viewModel.applyPersistentState(SwitcherPersistentState(
            audioStrategy: .followProgram,
            isSpeakerMode: true
        ))

        XCTAssertEqual(viewModel.runtime.state.audio.strategy, .followProgram)
        XCTAssertTrue(viewModel.runtime.state.audio.isSpeakerMode)
    }

    func testPersistentLoadPerformsNoFacadeAudioInputsChangedAction() {
        let viewModel = persistentRuntimeLoadMakeViewModel(bridgeMode: .panicOwned)

        viewModel.applyPersistentState(SwitcherPersistentState(audioStrategy: .followSource))

        XCTAssertFalse(viewModel.runtime.actionLog.contains { $0.actionName == "facadeAudioInputsChanged" })
        XCTAssertFalse(viewModel.runtime.recordedEffects.contains {
            if case .applyAudioRouting = $0 { return true }
            return false
        })
    }

    func testPersistentHydrationDoesNotResetAudioSessionFields() {
        var state = LiveRuntimeState()
        state.audio.masterVolume = 0.2
        state.audio.isMasterMuted = true
        state.audio.isBGMTakeoverActive = true
        state.audio.effectiveMedia = 0.1
        state.audio.effectiveBGM = 0.4
        let viewModel = persistentRuntimeLoadMakeViewModel(runtimeState: state, bridgeMode: .panicOwned)

        viewModel.applyPersistentState(SwitcherPersistentState(
            audioStrategy: .followSource,
            isSpeakerMode: true
        ))

        XCTAssertEqual(viewModel.runtime.state.audio.masterVolume, 0.2)
        XCTAssertTrue(viewModel.runtime.state.audio.isMasterMuted)
        XCTAssertTrue(viewModel.runtime.state.audio.isBGMTakeoverActive)
        XCTAssertEqual(viewModel.runtime.state.audio.effectiveMedia, 0)
        XCTAssertEqual(viewModel.runtime.state.audio.effectiveBGM, 0)
    }
}
