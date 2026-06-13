import XCTest
@testable import LiveSwitcher

@MainActor
final class PanicRuntimeOwnershipTests: XCTestCase {
    func testPanicOwnedBridgeModeOwnsPriorDomainsAndPanic() {
        XCTAssertEqual(
            LiveRuntimeBridgeMode.panicOwned.ownedDomains,
            [.audio, .media, .bgm, .projection, .panic, .ppt, .automationNotice, .support, .automationCommand, .presentationQuery, .programQueue, .programSelection, .programActivation, .imageAssets, .persistence]
        )
    }

    func testProductionViewModelUsesPanicOwnedEnvironment() {
        let viewModel = makeViewModel()

        XCTAssertEqual(viewModel.runtimeBridgeMode, .panicOwned)
        XCTAssertEqual(LiveRuntimeEnvironment.productionPanicOwning().bridgeMode, .panicOwned)
    }

    func testProductionPortsIncludePanicDelayWithoutLosingPriorPorts() {
        let viewModel = makeViewModel()
        let expected: Set<LiveRuntimeEffectPortKind> = [
            .media, .bgm, .bgmTimer, .panicDelay, .projection, .ppt,
            .automationNotice, .support, .automation, .presentationQuery,
            .programActivation, .audioRouting, .imageAssets, .persistence
        ]

        XCTAssertEqual(viewModel.runtimeConnectedPortKinds, expected)
    }

    func testPanicFacadeSyncPolicyDoesNotDispatchAudioInputsBeforePanicActions() {
        for action in panicActions {
            let options = LiveRuntimeFacadeSyncPolicy.options(for: action)

            XCTAssertFalse(options.dispatchAudioInputsChanged, action.redactedName)
            XCTAssertTrue(options.syncPanic, action.redactedName)
            XCTAssertTrue(options.syncBGM, action.redactedName)
        }
    }

    func testOperatorSetPanicSyncsRuntimePanicStateBackToFacade() {
        let viewModel = makeViewModel()

        viewModel.dispatchRuntimeFacadeAction(.operatorSetPanic(true))

        XCTAssertTrue(viewModel.isPanicMode)
        XCTAssertNotNil(viewModel.panicPlaybackSnapshot)
        XCTAssertTrue(viewModel.runtime.state.panic.isActive)
    }

    func testRuntimeOwnedSnapshotPreservesRuntimePanicStateDuringFacadeSync() {
        let viewModel = makeViewModel()
        viewModel.runtime.dispatch(.operatorSetPanic(true))
        let runtimeSnapshot = viewModel.runtime.state.panic.snapshot

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false, dispatchAudioInputsChanged: false)

        XCTAssertTrue(viewModel.runtime.state.panic.isActive)
        XCTAssertEqual(viewModel.runtime.state.panic.snapshot, runtimeSnapshot)
    }

    func testTogglePanicInProductionUsesRuntimeOwnedActionAndRecordsSupportOnce() {
        let viewModel = makeViewModel()
        let before = viewModel.supportEvents.filter { $0.kind == .panicModeChanged }.count

        viewModel.togglePanicMode()

        XCTAssertTrue(viewModel.isPanicMode)
        XCTAssertEqual(actionCount("operatorSetPanic", in: viewModel), 1)
        XCTAssertEqual(actionCount("operatorPausedMediaForPanic", in: viewModel), 0)
        XCTAssertEqual(viewModel.supportEvents.filter { $0.kind == .panicModeChanged }.count, before + 1)
    }

    func testFadeToBlackDoesNotDispatchRuntimePanicActions() {
        let viewModel = makeViewModel()

        viewModel.toggleFadeToBlack()

        XCTAssertTrue(viewModel.isFadeToBlackActive)
        XCTAssertEqual(actionCount("operatorSetPanic", in: viewModel), 0)
        XCTAssertEqual(actionCount("operatorToggledPanic", in: viewModel), 0)
    }

    func testPanicDelayRuntimeWiringOwnsCleanupGeneration() throws {
        let cleanup = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Models/ViewModelCleanupBag.swift")
        let wiring = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+PanicDelayRuntimeWiring.swift")

        XCTAssertTrue(cleanup.contains("var panicAudioPauseTaskGeneration: Int?"))
        XCTAssertTrue(cleanup.contains("panicAudioPauseTaskGeneration = nil"))
        XCTAssertTrue(wiring.contains("cleanupBag.panicAudioPauseTaskGeneration = generation"))
    }

    func testSnapshotSyncHasRuntimeOwnedPanicGuard() throws {
        let source = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+RuntimeSnapshot.swift")

        XCTAssertTrue(source.contains("func syncPanicIntoRuntimeSnapshot"))
        XCTAssertTrue(source.contains("guard !runtime.bridgeMode.owns(.panic) else"))
        XCTAssertTrue(source.contains("state.panic = runtime.state.panic"))
    }

    private var panicActions: [LiveRuntimeAction] {
        let snapshot = PanicPlaybackSnapshot(
            currentProgramID: nil,
            wasMediaPlaying: false,
            currentBGMID: nil,
            wasBGMPlaying: false
        )
        return [
            .operatorSetPanic(true),
            .operatorToggledPanic,
            .panicBGMPauseDelayElapsed(generation: 1, snapshot: snapshot)
        ]
    }

    private func makeViewModel() -> SwitcherViewModel {
        SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)
    }

    private func actionCount(_ name: String, in viewModel: SwitcherViewModel) -> Int {
        viewModel.runtime.actionLog.filter { $0.actionName == name }.count
    }
}
