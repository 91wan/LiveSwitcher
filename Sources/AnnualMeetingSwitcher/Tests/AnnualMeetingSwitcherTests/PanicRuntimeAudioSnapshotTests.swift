import XCTest
@testable import LiveSwitcher

@MainActor
final class PanicRuntimeAudioSnapshotTests: XCTestCase {
    func testPanicOwnedAudioFacadeSnapshotUsesRuntimePanicState() {
        let viewModel = makeViewModel(bridgeMode: .panicOwned, runtimePanic: true, facadePanic: false)

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false)

        XCTAssertTrue(viewModel.runtime.state.audio.routingContext.isPanicMode)
    }

    func testPanicOwnedRuntimeSnapshotAudioRoutingUsesRuntimePanicState() {
        let viewModel = makeViewModel(bridgeMode: .panicOwned, runtimePanic: true, facadePanic: false)

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false, dispatchAudioInputsChanged: false)

        XCTAssertTrue(viewModel.runtime.state.audio.routingContext.isPanicMode)
    }

    func testPanicOwnedRuntimeSnapshotDoesNotUseStaleFacadePanicState() {
        let viewModel = makeViewModel(bridgeMode: .panicOwned, runtimePanic: false, facadePanic: true)

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false, dispatchAudioInputsChanged: false)

        XCTAssertFalse(viewModel.runtime.state.audio.routingContext.isPanicMode)
    }

    func testNonPanicOwnedRuntimeSnapshotUsesFacadePanicState() {
        let viewModel = makeViewModel(bridgeMode: .recordingOnly, runtimePanic: false, facadePanic: true)

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false, dispatchAudioInputsChanged: false)

        XCTAssertTrue(viewModel.runtime.state.audio.routingContext.isPanicMode)
    }

    func testPanicOwnedDispatchDoesNotOverwriteAudioRoutingContextWithStaleFacade() {
        let viewModel = makeViewModel(bridgeMode: .panicOwned, runtimePanic: true, facadePanic: false)

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false)

        XCTAssertTrue(viewModel.runtime.state.audio.routingContext.isPanicMode)
    }

    func testPanicOwnedApplyAudioRoutingReceivesRuntimePanicContext() {
        let port = ClosureAudioRoutingPort()
        var receivedState: LiveRuntimeState?
        port.applyHandler = { _, state in
            receivedState = state
        }
        let runner = LiveRuntimeEffectRunner(
            recordsOnly: false,
            audioRouting: port
        )
        var state = LiveRuntimeState()
        state.audio.routingContext.isPanicMode = false
        let runtime = LiveRuntimeStore(
            initialState: state,
            effectRunner: runner,
            environment: .productionPanicOwning()
        )

        runtime.dispatch(.operatorSetPanic(true))

        XCTAssertTrue(receivedState?.audio.routingContext.isPanicMode == true)
    }

    func testRuntimeSnapshotSourceUsesRuntimeBackedPanicHelper() throws {
        let source = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+RuntimeSnapshot.swift")

        XCTAssertTrue(source.contains("runtimeBackedPanicIsActiveForSnapshot"))
        XCTAssertFalse(source.contains("isPanicMode: isPanicMode"))
    }

    private func makeViewModel(
        bridgeMode: LiveRuntimeBridgeMode,
        runtimePanic: Bool,
        facadePanic: Bool
    ) -> SwitcherViewModel {
        var state = LiveRuntimeState()
        state.panic.isActive = runtimePanic
        state.audio.routingContext.isPanicMode = runtimePanic
        let runtime = LiveRuntimeStore(
            initialState: state,
            effectRunner: .recording(),
            environment: LiveRuntimeEnvironment(bridgeMode: bridgeMode)
        )
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false, runtime: runtime)
        viewModel.applyPanicProjectionFromRuntime(isActive: facadePanic, snapshot: nil)
        return viewModel
    }
}
