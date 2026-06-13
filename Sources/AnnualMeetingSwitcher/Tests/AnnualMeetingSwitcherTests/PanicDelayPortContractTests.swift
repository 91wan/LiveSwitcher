import XCTest
@testable import LiveSwitcher

@MainActor
final class PanicDelayPortContractTests: XCTestCase {
    func testPanicDelayPortRequiresExecutionContextForSchedule() throws {
        let source = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimePorts.swift")

        XCTAssertTrue(source.contains("func scheduleBGMPause(generation: Int, snapshot: PanicPlaybackSnapshot, delay: TimeInterval, context: LiveRuntimeEffectExecutionContext)"))
        XCTAssertTrue(source.contains("func cancelBGMPause(generation: Int)"))
    }

    func testClosurePanicDelayPortForwardsScheduleArguments() {
        let port = ClosurePanicDelayPort()
        let expectedSnapshot = panicSnapshot()
        var received: (Int, PanicPlaybackSnapshot, TimeInterval)?
        port.scheduleBGMPauseHandler = { generation, snapshot, delay, context in
            received = (generation, snapshot, delay)
            XCTAssertTrue(context.currentState().panic.isActive)
        }

        port.scheduleBGMPause(
            generation: 7,
            snapshot: expectedSnapshot,
            delay: 0.25,
            context: context()
        )

        XCTAssertEqual(received?.0, 7)
        XCTAssertEqual(received?.1, expectedSnapshot)
        XCTAssertEqual(received?.2, 0.25)
    }

    func testClosurePanicDelayPortForwardsCancelGeneration() {
        let port = ClosurePanicDelayPort()
        var cancelledGeneration: Int?
        port.cancelBGMPauseHandler = { generation in
            cancelledGeneration = generation
        }

        port.cancelBGMPause(generation: 8)

        XCTAssertEqual(cancelledGeneration, 8)
    }

    func testEffectRunnerConnectedPortsIncludesPanicDelayOnlyWhenProvided() {
        XCTAssertFalse(LiveRuntimeEffectRunner().connectedPortKinds.contains(.panicDelay))
        XCTAssertTrue(LiveRuntimeEffectRunner(panicDelay: ClosurePanicDelayPort()).connectedPortKinds.contains(.panicDelay))
    }

    func testProductionRuntimeWiresPanicDelayPort() throws {
        let bundle = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/SwitcherRuntimePortBundle.swift")
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)

        XCTAssertTrue(viewModel.runtimeConnectedPortKinds.contains(.panicDelay))
        XCTAssertTrue(bundle.contains("panicDelay"))
    }

    func testProductionPanicDelayWiringDispatchesElapsedActionThroughContext() throws {
        let source = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+PanicDelayRuntimeWiring.swift")

        XCTAssertTrue(source.contains("context.dispatch(.panicBGMPauseDelayElapsed"))
        XCTAssertFalse(source.contains("dispatchRuntimeFacadeAction"))
        XCTAssertFalse(source.contains("recordSupportEvent"))
        XCTAssertFalse(source.contains("runtime.dispatch"))
    }

    func testPanicDelayPortHasNoDefaultNoOpImplementation() throws {
        let source = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimePorts.swift")

        XCTAssertFalse(source.contains("extension PanicDelayPort"))
    }

    func testEffectRunnerPortFieldRemainsPrivate() throws {
        let source = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeEffectRunner.swift")

        XCTAssertTrue(source.contains("private let panicDelay: PanicDelayPort?"))
    }

    private func panicSnapshot() -> PanicPlaybackSnapshot {
        PanicPlaybackSnapshot(
            currentProgramID: nil,
            wasMediaPlaying: false,
            currentBGMID: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            wasBGMPlaying: true
        )
    }

    private func context() -> LiveRuntimeEffectExecutionContext {
        var state = LiveRuntimeState()
        state.panic.isActive = true
        return LiveRuntimeEffectExecutionContext(currentState: { state }, dispatch: { _ in })
    }
}
