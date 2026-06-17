import XCTest
@testable import LiveSwitcher

@MainActor
final class RuntimeAudioSnapshotOwnershipBoundaryTests: XCTestCase {
    func testAudioOwnedAudioFacadeSnapshotUsesRuntimeMasterVolume() {
        let viewModel = makeAudioOwnedViewModelWithRoutingChange()

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false)

        XCTAssertEqual(viewModel.runtime.state.audio.masterVolume, 0.82, accuracy: 0.0001)
    }

    func testAudioOwnedAudioFacadeSnapshotUsesRuntimeMediaVolume() {
        let viewModel = makeAudioOwnedViewModelWithRoutingChange()

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false)

        XCTAssertEqual(viewModel.runtime.state.audio.mediaVolume, 0.73, accuracy: 0.0001)
    }

    func testAudioOwnedAudioFacadeSnapshotUsesRuntimeBGMVolume() {
        let viewModel = makeAudioOwnedViewModelWithRoutingChange()

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false)

        XCTAssertEqual(viewModel.runtime.state.audio.bgmVolume, 0.64, accuracy: 0.0001)
    }

    func testAudioOwnedAudioFacadeSnapshotUsesRuntimeStrategy() {
        let viewModel = makeAudioOwnedViewModelWithRoutingChange()

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false)

        XCTAssertEqual(viewModel.runtime.state.audio.strategy, .followProgram)
    }

    func testAudioOwnedAudioFacadeSnapshotUsesRuntimeMutes() {
        let viewModel = makeAudioOwnedViewModelWithRoutingChange()

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false)

        XCTAssertTrue(viewModel.runtime.state.audio.isMasterMuted)
        XCTAssertTrue(viewModel.runtime.state.audio.isMediaMuted)
        XCTAssertTrue(viewModel.runtime.state.audio.isBGMMuted)
    }

    func testAudioOwnedAudioFacadeSnapshotUsesRuntimeSpeakerMode() {
        let viewModel = makeAudioOwnedViewModelWithRoutingChange()

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false)

        XCTAssertTrue(viewModel.runtime.state.audio.isSpeakerMode)
    }

    func testAudioOwnedAudioFacadeSnapshotUsesRuntimeBGMTakeover() {
        let viewModel = makeAudioOwnedViewModelWithRoutingChange()

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false)

        XCTAssertTrue(viewModel.runtime.state.audio.isBGMTakeoverActive)
    }

    func testAudioOwnedFacadeAudioInputsChangedDoesNotOverwriteRuntimeAudioControls() {
        let viewModel = makeAudioOwnedViewModelWithRoutingChange()

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false)

        XCTAssertEqual(viewModel.runtime.state.audio.masterVolume, 0.82, accuracy: 0.0001)
        XCTAssertEqual(viewModel.runtime.state.audio.mediaVolume, 0.73, accuracy: 0.0001)
        XCTAssertEqual(viewModel.runtime.state.audio.bgmVolume, 0.64, accuracy: 0.0001)
        XCTAssertEqual(viewModel.runtime.state.audio.strategy, .followProgram)
        XCTAssertTrue(viewModel.runtime.state.audio.isMasterMuted)
        XCTAssertTrue(viewModel.runtime.state.audio.isMediaMuted)
        XCTAssertTrue(viewModel.runtime.state.audio.isBGMMuted)
        XCTAssertTrue(viewModel.runtime.state.audio.isSpeakerMode)
        XCTAssertTrue(viewModel.runtime.state.audio.isBGMTakeoverActive)
        XCTAssertTrue(viewModel.runtime.state.audio.routingContext.isMediaPlaying)
    }

    func testNonAudioOwnedAudioFacadeSnapshotUsesFacadeAudioControls() {
        let viewModel = makeViewModel(runtimeState: runtimeAudioState(), bridgeMode: .recordingOnly) {
            configureStaleAudioFacade($0)
            $0.avCoordinator.isPlaying = true
        }

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false)

        XCTAssertEqual(viewModel.runtime.state.audio.masterVolume, 0.21, accuracy: 0.0001)
        XCTAssertEqual(viewModel.runtime.state.audio.mediaVolume, 0.18, accuracy: 0.0001)
        XCTAssertEqual(viewModel.runtime.state.audio.bgmVolume, 0.11, accuracy: 0.0001)
        XCTAssertEqual(viewModel.runtime.state.audio.strategy, AudioStrategy.bgmOnly)
    }

    func testAudioFacadeSnapshotStillUsesRuntimeOwnedRoutingInputs() {
        var state = runtimeAudioState()
        state.program.items = [mediaItem("runtime")]
        state.program.currentID = state.program.items[0].id
        state.media.isPlaying = true
        state.bgm.isPlaying = true
        state.panic.isActive = true
        state.audio.routingContext = AudioRoutingContext()
        let viewModel = makeViewModel(runtimeState: state, bridgeMode: .panicOwned) { viewModel in
            configureStaleAudioFacade(viewModel)
            viewModel.avCoordinator.isPlaying = false
            viewModel.isBGMPlaying = false
            viewModel.applyPanicProjectionFromRuntime(isActive: false, snapshot: nil)
            let deck = ProgramItem(title: "Deck", subtitle: "KEYNOTE", sourceURL: URL(fileURLWithPath: "/tmp/deck.key"))
            viewModel.applyProgramQueueProjectionFromRuntime([deck])
            viewModel.applyCurrentProgramProjectionFromRuntime(deck, switchedAt: Date(timeIntervalSince1970: 1))
        }

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false)

        XCTAssertTrue(viewModel.runtime.state.audio.routingContext.isCurrentProgramMediaSource)
        XCTAssertTrue(viewModel.runtime.state.audio.routingContext.isMediaPlaying)
        XCTAssertTrue(viewModel.runtime.state.audio.routingContext.isBGMPlaying)
        XCTAssertTrue(viewModel.runtime.state.audio.routingContext.isPanicMode)
    }

    func testAudioOwnedOperatorChangedMasterVolumeStillUpdatesRuntime() {
        let viewModel = makeAudioOwnedViewModelWithRoutingChange()

        viewModel.dispatchRuntimeFacadeAction(.operatorChangedMasterVolume(0.44))

        XCTAssertEqual(viewModel.runtime.state.audio.masterVolume, 0.44, accuracy: 0.0001)
    }

    func testAudioOwnedOperatorChangedMediaVolumeStillUpdatesRuntime() {
        let viewModel = makeAudioOwnedViewModelWithRoutingChange()

        viewModel.dispatchRuntimeFacadeAction(.operatorChangedMediaVolume(0.45))

        XCTAssertEqual(viewModel.runtime.state.audio.mediaVolume, 0.45, accuracy: 0.0001)
    }

    func testAudioOwnedOperatorChangedBGMVolumeStillUpdatesRuntime() {
        let viewModel = makeAudioOwnedViewModelWithRoutingChange()

        viewModel.dispatchRuntimeFacadeAction(.operatorChangedBGMVolume(0.46))

        XCTAssertEqual(viewModel.runtime.state.audio.bgmVolume, 0.46, accuracy: 0.0001)
    }

    func testAudioOwnedOperatorSelectedStrategyStillUpdatesRuntime() {
        let viewModel = makeAudioOwnedViewModelWithRoutingChange()

        viewModel.dispatchRuntimeFacadeAction(.operatorSelectedAudioStrategy(.followSource))

        XCTAssertEqual(viewModel.runtime.state.audio.strategy, .followSource)
    }

    func testAudioOwnedOperatorChangedMasterMuteStillUpdatesRuntime() {
        let viewModel = makeAudioOwnedViewModelWithRoutingChange()

        viewModel.dispatchRuntimeFacadeAction(.operatorChangedMasterMute(false))

        XCTAssertFalse(viewModel.runtime.state.audio.isMasterMuted)
    }

    func testAudioOwnedOperatorChangedMediaMuteStillUpdatesRuntime() {
        let viewModel = makeAudioOwnedViewModelWithRoutingChange()

        viewModel.dispatchRuntimeFacadeAction(.operatorChangedMediaMute(false))

        XCTAssertFalse(viewModel.runtime.state.audio.isMediaMuted)
    }

    func testAudioOwnedOperatorChangedBGMMuteStillUpdatesRuntime() {
        let viewModel = makeAudioOwnedViewModelWithRoutingChange()

        viewModel.dispatchRuntimeFacadeAction(.operatorChangedBGMMute(false))

        XCTAssertFalse(viewModel.runtime.state.audio.isBGMMuted)
    }

    func testAudioOwnedOperatorChangedBGMTakeoverStillUpdatesRuntime() {
        let viewModel = makeAudioOwnedViewModelWithRoutingChange()

        viewModel.dispatchRuntimeFacadeAction(.operatorChangedBGMTakeover(false))

        XCTAssertFalse(viewModel.runtime.state.audio.isBGMTakeoverActive)
    }

    func testAudioOwnedOperatorSetSpeakerModeStillUpdatesRuntime() {
        let viewModel = makeAudioOwnedViewModelWithRoutingChange()

        viewModel.dispatchRuntimeFacadeAction(.operatorSetSpeakerMode(false))

        XCTAssertFalse(viewModel.runtime.state.audio.isSpeakerMode)
    }

    func testUnrelatedRuntimeActionDoesNotOverwriteAudioOwnedControlsFromFacade() {
        let state = runtimeAudioState()
        let viewModel = makeViewModel(runtimeState: state, bridgeMode: .audioOwned) {
            configureStaleAudioFacade($0)
        }

        viewModel.dispatchRuntimeFacadeAction(LiveRuntimeAction.operatorSetAutoAdvanceAtScheduledTime(true))

        XCTAssertEqual(viewModel.runtime.state.audio.masterVolume, state.audio.masterVolume, accuracy: 0.0001)
        XCTAssertEqual(viewModel.runtime.state.audio.strategy, state.audio.strategy)
        XCTAssertTrue(viewModel.runtime.state.audio.isBGMTakeoverActive)
    }

    func testAudioOwnedSnapshotStillUsesRuntimeMediaPlayingWhenMediaOwned() {
        var state = runtimeAudioState()
        state.media.isPlaying = true
        let viewModel = makeViewModel(runtimeState: state, bridgeMode: .mediaOwned) {
            $0.avCoordinator.isPlaying = false
        }

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false, dispatchAudioInputsChanged: false)

        XCTAssertTrue(viewModel.runtime.state.audio.routingContext.isMediaPlaying)
    }

    func testAudioOwnedSnapshotStillUsesFacadeMediaPlayingWhenMediaNotOwned() {
        var state = runtimeAudioState()
        state.media.isPlaying = false
        let viewModel = makeViewModel(runtimeState: state, bridgeMode: .audioOwned) {
            $0.avCoordinator.isPlaying = true
        }

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false, dispatchAudioInputsChanged: false)

        XCTAssertTrue(viewModel.runtime.state.audio.routingContext.isMediaPlaying)
    }

    func testAudioOwnedSnapshotStillUsesRuntimeCurrentProgramWhenProgramSelectionOwned() {
        let item = mediaItem("runtime")
        var state = runtimeAudioState()
        state.program.items = [item]
        state.program.currentID = item.id
        let viewModel = makeViewModel(runtimeState: state, bridgeMode: .programSelectionOwned) { viewModel in
            let deck = ProgramItem(title: "Deck", subtitle: "KEYNOTE", sourceURL: URL(fileURLWithPath: "/tmp/deck.key"))
            viewModel.applyProgramQueueProjectionFromRuntime([deck])
            viewModel.applyCurrentProgramProjectionFromRuntime(deck, switchedAt: Date(timeIntervalSince1970: 1))
        }

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false, dispatchAudioInputsChanged: false)

        XCTAssertTrue(viewModel.runtime.state.audio.routingContext.isCurrentProgramMediaSource)
    }

    func testAudioOwnedSnapshotStillUsesFacadeCurrentProgramWhenProgramSelectionNotOwned() {
        let item = ProgramItem(title: "Deck", subtitle: "KEYNOTE", sourceURL: URL(fileURLWithPath: "/tmp/deck.key"))
        var state = runtimeAudioState()
        state.program.items = [item]
        state.program.currentID = item.id
        let viewModel = makeViewModel(runtimeState: state, bridgeMode: .audioOwned) { viewModel in
            let media = mediaItem("facade")
            viewModel.applyProgramQueueProjectionFromRuntime([media])
            viewModel.applyCurrentProgramProjectionFromRuntime(media, switchedAt: Date(timeIntervalSince1970: 1))
        }

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false, dispatchAudioInputsChanged: false)

        XCTAssertTrue(viewModel.runtime.state.audio.routingContext.isCurrentProgramMediaSource)
    }

    func testAudioOwnedSnapshotStillUsesRuntimeBGMPlayingWhenBGMOwned() {
        var state = runtimeAudioState()
        state.bgm.isPlaying = true
        let viewModel = makeViewModel(runtimeState: state, bridgeMode: .bgmOwned) {
            $0.isBGMPlaying = false
        }

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false, dispatchAudioInputsChanged: false)

        XCTAssertTrue(viewModel.runtime.state.audio.routingContext.isBGMPlaying)
    }

    func testAudioOwnedSnapshotStillUsesFacadeBGMPlayingWhenBGMNotOwned() {
        var state = runtimeAudioState()
        state.bgm.isPlaying = false
        let viewModel = makeViewModel(runtimeState: state, bridgeMode: .mediaOwned) {
            $0.isBGMPlaying = true
        }

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false, dispatchAudioInputsChanged: false)

        XCTAssertTrue(viewModel.runtime.state.audio.routingContext.isBGMPlaying)
    }

    func testAudioOwnedSnapshotStillUsesRuntimePanicWhenPanicOwned() {
        var state = runtimeAudioState()
        state.panic.isActive = true
        let viewModel = makeViewModel(runtimeState: state, bridgeMode: .panicOwned) {
            $0.applyPanicProjectionFromRuntime(isActive: false, snapshot: nil)
        }

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false, dispatchAudioInputsChanged: false)

        XCTAssertTrue(viewModel.runtime.state.audio.routingContext.isPanicMode)
    }

    func testAudioOwnedSnapshotStillUsesFacadePanicWhenPanicNotOwned() {
        var state = runtimeAudioState()
        state.panic.isActive = false
        let viewModel = makeViewModel(runtimeState: state, bridgeMode: .audioOwned) {
            $0.applyPanicProjectionFromRuntime(isActive: true, snapshot: nil)
        }

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false, dispatchAudioInputsChanged: false)

        XCTAssertTrue(viewModel.runtime.state.audio.routingContext.isPanicMode)
    }

    func testAudioFacadeSnapshotDoesNotWriteFacadeAudioControlsDirectly() throws {
        let body = try XCTUnwrap(runtimeSnapshotSource().extractedRuntimeFunctionBody(named: "audioFacadeSnapshot"))

        [
            "masterVolume: masterVolume",
            "mediaVolume: mediaVolume",
            "bgmVolume: bgmVolume",
            "strategy: audioStrategy",
            "isMasterMuted: isMasterAudioMuted",
            "isMediaMuted: isMediaAudioMuted",
            "isBGMMuted: isBGMAudioMuted",
            "isSpeakerMode: isSpeakerMode",
            "isBGMTakeoverActive: isBGMAudioTakeoverActive"
        ].forEach { directRead in
            XCTAssertFalse(body.contains(directRead), directRead)
        }
    }

    private func makeAudioOwnedViewModelWithRoutingChange() -> SwitcherViewModel {
        var state = runtimeAudioState()
        state.audio.routingContext.isMediaPlaying = false
        return makeViewModel(runtimeState: state, bridgeMode: .audioOwned) {
            configureStaleAudioFacade($0)
            $0.avCoordinator.isPlaying = true
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

    private func mediaItem(_ title: String) -> ProgramItem {
        ProgramItem(title: title, subtitle: "VIDEO", sourceURL: URL(fileURLWithPath: "/tmp/\(title).mp4"))
    }

    private func runtimeSnapshotSource() throws -> String {
        try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+RuntimeSnapshot.swift")
    }
}
