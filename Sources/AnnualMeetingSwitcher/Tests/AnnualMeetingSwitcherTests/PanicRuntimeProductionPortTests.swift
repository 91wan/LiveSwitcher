import XCTest
@testable import LiveSwitcher

@MainActor
final class PanicRuntimeProductionPortTests: XCTestCase {
    func testProductionPanicDelayClearsTaskAfterDispatch() async throws {
        let harness = makeHarness(runtimePanic: true, bgmPlaying: true)

        harness.ports.panicDelayPort.scheduleBGMPause(
            generation: 7,
            snapshot: panicSnapshot(),
            delay: 0,
            context: harness.context
        )
        try await Task.sleep(nanoseconds: 20_000_000)

        XCTAssertNil(harness.viewModel.cleanupBag.panicAudioPauseTask)
    }

    func testProductionPanicDelayClearsGenerationAfterDispatch() async throws {
        let harness = makeHarness(runtimePanic: true, bgmPlaying: true)

        harness.ports.panicDelayPort.scheduleBGMPause(
            generation: 7,
            snapshot: panicSnapshot(),
            delay: 0,
            context: harness.context
        )
        try await Task.sleep(nanoseconds: 20_000_000)

        XCTAssertNil(harness.viewModel.cleanupBag.panicAudioPauseTaskGeneration)
    }

    func testProductionPanicDelayDoesNotClearNewerGenerationAfterOldTask() async throws {
        let harness = makeHarness(runtimePanic: true, bgmPlaying: true)

        harness.ports.panicDelayPort.scheduleBGMPause(
            generation: 7,
            snapshot: panicSnapshot(),
            delay: 0.02,
            context: harness.context
        )
        harness.viewModel.cleanupBag.panicAudioPauseTaskGeneration = 8
        harness.viewModel.cleanupBag.panicAudioPauseTask = Task { @MainActor in }
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(harness.viewModel.cleanupBag.panicAudioPauseTaskGeneration, 8)
        XCTAssertNotNil(harness.viewModel.cleanupBag.panicAudioPauseTask)
    }

    func testProductionPanicDelayCancelClearsMatchingTaskAndGeneration() {
        let harness = makeHarness(runtimePanic: true, bgmPlaying: true)

        harness.ports.panicDelayPort.scheduleBGMPause(
            generation: 7,
            snapshot: panicSnapshot(),
            delay: 10,
            context: harness.context
        )
        harness.ports.panicDelayPort.cancelBGMPause(generation: 7)

        XCTAssertNil(harness.viewModel.cleanupBag.panicAudioPauseTask)
        XCTAssertNil(harness.viewModel.cleanupBag.panicAudioPauseTaskGeneration)
    }

    func testProductionPanicDelayCancelDoesNotClearNewerGeneration() {
        let harness = makeHarness(runtimePanic: true, bgmPlaying: true)

        harness.ports.panicDelayPort.scheduleBGMPause(
            generation: 7,
            snapshot: panicSnapshot(),
            delay: 10,
            context: harness.context
        )
        harness.viewModel.cleanupBag.panicAudioPauseTaskGeneration = 8
        harness.ports.panicDelayPort.cancelBGMPause(generation: 7)

        XCTAssertEqual(harness.viewModel.cleanupBag.panicAudioPauseTaskGeneration, 8)
        XCTAssertNotNil(harness.viewModel.cleanupBag.panicAudioPauseTask)
    }

    func testProductionPanicDelaySyncsBGMFacadeAfterDelayElapsed() async throws {
        let harness = makeHarness(runtimePanic: true, bgmPlaying: true)
        harness.viewModel.isBGMPlaying = true

        harness.ports.panicDelayPort.scheduleBGMPause(
            generation: 7,
            snapshot: panicSnapshot(),
            delay: 0,
            context: harness.context
        )
        try await Task.sleep(nanoseconds: 20_000_000)

        XCTAssertFalse(harness.viewModel.isBGMPlaying)
    }

    func testProductionPanicDelaySyncsPanicFacadeAfterDelayElapsed() async throws {
        let harness = makeHarness(runtimePanic: true, bgmPlaying: true)
        harness.viewModel.applyPanicProjectionFromRuntime(isActive: false, snapshot: nil)

        harness.ports.panicDelayPort.scheduleBGMPause(
            generation: 7,
            snapshot: panicSnapshot(),
            delay: 0,
            context: harness.context
        )
        try await Task.sleep(nanoseconds: 20_000_000)

        XCTAssertTrue(harness.viewModel.isPanicMode)
    }

    private struct Harness {
        let viewModel: SwitcherViewModel
        let ports: SwitcherRuntimePortBundle
        let context: LiveRuntimeEffectExecutionContext
    }

    private func makeHarness(runtimePanic: Bool, bgmPlaying: Bool) -> Harness {
        let bgm = BGMItem(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            title: "Walk In",
            url: URL(fileURLWithPath: "/tmp/walk-in.mp3")
        )
        var state = LiveRuntimeState()
        state.panic.isActive = runtimePanic
        state.panic.generation = 7
        state.panic.snapshot = panicSnapshot()
        state.bgm.items = [bgm]
        state.bgm.currentID = bgm.id
        state.bgm.phase = bgmPlaying ? .playing : .selected
        state.bgm.generation = 3
        state.audio.routingContext.isPanicMode = runtimePanic
        state.audio.routingContext.isBGMPlaying = bgmPlaying
        let runtime = LiveRuntimeStore(
            initialState: state,
            effectRunner: .recording(),
            environment: .productionPanicOwning()
        )
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false, runtime: runtime)
        let ports = SwitcherRuntimePortBundle()
        viewModel.configurePanicDelayRuntimePortHandlers(ports)
        let context = LiveRuntimeEffectExecutionContext(
            currentState: { viewModel.runtime.state },
            dispatch: { viewModel.runtime.dispatch($0) }
        )
        return Harness(viewModel: viewModel, ports: ports, context: context)
    }

    private func panicSnapshot() -> PanicPlaybackSnapshot {
        PanicPlaybackSnapshot(
            currentProgramID: nil,
            wasMediaPlaying: false,
            currentBGMID: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            wasBGMPlaying: true
        )
    }
}
