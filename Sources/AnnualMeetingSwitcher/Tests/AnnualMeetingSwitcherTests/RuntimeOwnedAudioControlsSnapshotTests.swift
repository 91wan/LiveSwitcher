import XCTest
@testable import LiveSwitcher

@MainActor
final class RuntimeOwnedAudioControlsSnapshotTests: XCTestCase {
    func testAudioOwnedSnapshotPreservesRuntimeMasterVolume() {
        var state = runtimeAudioState()
        state.audio.masterVolume = 0.82
        let viewModel = makeViewModel(runtimeState: state, bridgeMode: .audioOwned) {
            $0.masterVolume = 0.21
        }

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false, dispatchAudioInputsChanged: false)

        XCTAssertEqual(viewModel.runtime.state.audio.masterVolume, 0.82, accuracy: 0.0001)
    }

    func testAudioOwnedSnapshotPreservesRuntimeMediaVolume() {
        var state = runtimeAudioState()
        state.audio.mediaVolume = 0.73
        let viewModel = makeViewModel(runtimeState: state, bridgeMode: .audioOwned) {
            $0.mediaVolume = 0.18
        }

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false, dispatchAudioInputsChanged: false)

        XCTAssertEqual(viewModel.runtime.state.audio.mediaVolume, 0.73, accuracy: 0.0001)
    }

    func testAudioOwnedSnapshotPreservesRuntimeBGMVolume() {
        var state = runtimeAudioState()
        state.audio.bgmVolume = 0.64
        let viewModel = makeViewModel(runtimeState: state, bridgeMode: .audioOwned) {
            $0.bgmVolume = 0.11
        }

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false, dispatchAudioInputsChanged: false)

        XCTAssertEqual(viewModel.runtime.state.audio.bgmVolume, 0.64, accuracy: 0.0001)
    }

    func testAudioOwnedSnapshotPreservesRuntimeStrategy() {
        var state = runtimeAudioState()
        state.audio.strategy = .followProgram
        let viewModel = makeViewModel(runtimeState: state, bridgeMode: .audioOwned) {
            $0.audioStrategy = .bgmOnly
        }

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false, dispatchAudioInputsChanged: false)

        XCTAssertEqual(viewModel.runtime.state.audio.strategy, .followProgram)
    }

    func testAudioOwnedSnapshotPreservesRuntimeMasterMute() {
        var state = runtimeAudioState()
        state.audio.isMasterMuted = true
        let viewModel = makeViewModel(runtimeState: state, bridgeMode: .audioOwned) {
            $0.isMasterAudioMuted = false
        }

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false, dispatchAudioInputsChanged: false)

        XCTAssertTrue(viewModel.runtime.state.audio.isMasterMuted)
    }

    func testAudioOwnedSnapshotPreservesRuntimeMediaMute() {
        var state = runtimeAudioState()
        state.audio.isMediaMuted = true
        let viewModel = makeViewModel(runtimeState: state, bridgeMode: .audioOwned) {
            $0.isMediaAudioMuted = false
        }

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false, dispatchAudioInputsChanged: false)

        XCTAssertTrue(viewModel.runtime.state.audio.isMediaMuted)
    }

    func testAudioOwnedSnapshotPreservesRuntimeBGMMute() {
        var state = runtimeAudioState()
        state.audio.isBGMMuted = true
        let viewModel = makeViewModel(runtimeState: state, bridgeMode: .audioOwned) {
            $0.isBGMAudioMuted = false
        }

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false, dispatchAudioInputsChanged: false)

        XCTAssertTrue(viewModel.runtime.state.audio.isBGMMuted)
    }

    func testAudioOwnedSnapshotPreservesRuntimeSpeakerMode() {
        var state = runtimeAudioState()
        state.audio.isSpeakerMode = true
        let viewModel = makeViewModel(runtimeState: state, bridgeMode: .audioOwned) {
            $0.isSpeakerMode = false
        }

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false, dispatchAudioInputsChanged: false)

        XCTAssertTrue(viewModel.runtime.state.audio.isSpeakerMode)
    }

    func testAudioOwnedSnapshotPreservesRuntimeBGMTakeover() {
        var state = runtimeAudioState()
        state.audio.isBGMTakeoverActive = true
        let viewModel = makeViewModel(runtimeState: state, bridgeMode: .audioOwned) {
            $0.isBGMAudioTakeoverActive = false
        }

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false, dispatchAudioInputsChanged: false)

        XCTAssertTrue(viewModel.runtime.state.audio.isBGMTakeoverActive)
    }

    func testAudioOwnedSnapshotDoesNotOverwriteRuntimeAudioControlsWithStaleFacade() {
        let state = runtimeAudioState()
        let viewModel = makeViewModel(runtimeState: state, bridgeMode: .audioOwned) {
            configureStaleAudioFacade($0)
        }

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false, dispatchAudioInputsChanged: false)

        XCTAssertEqual(viewModel.runtime.state.audio.masterVolume, state.audio.masterVolume, accuracy: 0.0001)
        XCTAssertEqual(viewModel.runtime.state.audio.mediaVolume, state.audio.mediaVolume, accuracy: 0.0001)
        XCTAssertEqual(viewModel.runtime.state.audio.bgmVolume, state.audio.bgmVolume, accuracy: 0.0001)
        XCTAssertEqual(viewModel.runtime.state.audio.strategy, state.audio.strategy)
        XCTAssertEqual(viewModel.runtime.state.audio.isMasterMuted, state.audio.isMasterMuted)
        XCTAssertEqual(viewModel.runtime.state.audio.isMediaMuted, state.audio.isMediaMuted)
        XCTAssertEqual(viewModel.runtime.state.audio.isBGMMuted, state.audio.isBGMMuted)
        XCTAssertEqual(viewModel.runtime.state.audio.isSpeakerMode, state.audio.isSpeakerMode)
        XCTAssertEqual(viewModel.runtime.state.audio.isBGMTakeoverActive, state.audio.isBGMTakeoverActive)
    }

    func testNonAudioOwnedSnapshotUsesFacadeAudioControls() {
        let viewModel = makeViewModel(runtimeState: runtimeAudioState(), bridgeMode: .recordingOnly) {
            configureStaleAudioFacade($0)
        }

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false, dispatchAudioInputsChanged: false)

        XCTAssertEqual(viewModel.runtime.state.audio.masterVolume, 0.21, accuracy: 0.0001)
        XCTAssertEqual(viewModel.runtime.state.audio.mediaVolume, 0.18, accuracy: 0.0001)
        XCTAssertEqual(viewModel.runtime.state.audio.bgmVolume, 0.11, accuracy: 0.0001)
        XCTAssertEqual(viewModel.runtime.state.audio.strategy, .bgmOnly)
        XCTAssertFalse(viewModel.runtime.state.audio.isMasterMuted)
        XCTAssertFalse(viewModel.runtime.state.audio.isMediaMuted)
        XCTAssertFalse(viewModel.runtime.state.audio.isBGMMuted)
        XCTAssertFalse(viewModel.runtime.state.audio.isSpeakerMode)
        XCTAssertFalse(viewModel.runtime.state.audio.isBGMTakeoverActive)
    }

    func testSyncAudioIntoRuntimeSnapshotExists() throws {
        let source = try runtimeSnapshotSource()

        XCTAssertTrue(source.contains("syncAudioIntoRuntimeSnapshot"))
    }

    func testMakeRuntimeStateSnapshotDoesNotWriteAudioControlsDirectly() throws {
        let body = try XCTUnwrap(runtimeSnapshotSource().extractedRuntimeFunctionBody(named: "makeRuntimeStateSnapshot"))

        [
            "state.audio.masterVolume = masterVolume",
            "state.audio.mediaVolume = mediaVolume",
            "state.audio.bgmVolume = bgmVolume",
            "state.audio.strategy = audioStrategy",
            "state.audio.isMasterMuted = isMasterAudioMuted",
            "state.audio.isMediaMuted = isMediaAudioMuted",
            "state.audio.isBGMMuted = isBGMAudioMuted",
            "state.audio.isSpeakerMode = isSpeakerMode",
            "state.audio.isBGMTakeoverActive = isBGMAudioTakeoverActive",
            "state.audio.routingContext = AudioRoutingContext("
        ].forEach { directWrite in
            XCTAssertFalse(body.contains(directWrite), directWrite)
        }
    }

    private func makeViewModel(
        runtimeState: LiveRuntimeState,
        bridgeMode: LiveRuntimeBridgeMode,
        configureFacade: (SwitcherViewModel) -> Void
    ) -> SwitcherViewModel {
        let runtime = LiveRuntimeStore(
            initialState: runtimeState,
            effectRunner: .recording(),
            environment: LiveRuntimeEnvironment(bridgeMode: bridgeMode)
        )
        let viewModel = SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            runtime: runtime
        )
        configureFacade(viewModel)
        runtime.replaceStateForFacadeSync(runtimeState)
        return viewModel
    }

    private func runtimeAudioState() -> LiveRuntimeState {
        var state = LiveRuntimeState()
        state.audio.masterVolume = 0.82
        state.audio.mediaVolume = 0.73
        state.audio.bgmVolume = 0.64
        state.audio.strategy = .followProgram
        state.audio.isMasterMuted = true
        state.audio.isMediaMuted = true
        state.audio.isBGMMuted = true
        state.audio.isSpeakerMode = true
        state.audio.isBGMTakeoverActive = true
        state.audio.routingContext = AudioRoutingContext(
            isCurrentProgramMediaSource: false,
            isMediaPlaying: false,
            isBGMPlaying: false,
            isPanicMode: false
        )
        return state
    }

    private func runtimeSnapshotSource() throws -> String {
        try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+RuntimeSnapshot.swift")
    }
}

@MainActor
func configureStaleAudioFacade(_ viewModel: SwitcherViewModel) {
    viewModel.masterVolume = 0.21
    viewModel.mediaVolume = 0.18
    viewModel.bgmVolume = 0.11
    viewModel.audioStrategy = .bgmOnly
    viewModel.isMasterAudioMuted = false
    viewModel.isMediaAudioMuted = false
    viewModel.isBGMAudioMuted = false
    viewModel.isSpeakerMode = false
    viewModel.isBGMAudioTakeoverActive = false
}
