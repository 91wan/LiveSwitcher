import XCTest
@testable import LiveSwitcher

@MainActor
final class ProgramRuntimeDetachedCurrentTests: XCTestCase {
    func testDetachedCurrentDoesNotInflateRuntimeQueue() {
        let queued = mediaProgram(title: "Queued", path: "/tmp/queued.mp4")
        let detached = mediaProgram(title: "Detached", path: "/tmp/detached.mp4")
        let runtime = RuntimeTestFactory.fullRuntimeStore()
        let viewModel = SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            runtime: runtime
        )
        viewModel.programItems = [queued]

        viewModel.currentProgramItem = detached
        viewModel.syncRuntimeStateFromFacade(clearActionLog: true)

        XCTAssertEqual(runtime.state.program.items.map(\.id), [queued.id])
        XCTAssertEqual(runtime.state.program.currentID, detached.id)
        XCTAssertNil(runtime.state.program.currentItem)
        XCTAssertEqual(runtime.state.program.currentDetachedItem?.id, detached.id)
        XCTAssertEqual(runtime.state.program.effectiveCurrentItem?.id, detached.id)
    }

    func testDetachedCurrentClearsWhenCurrentReturnsToQueue() {
        let queued = mediaProgram(title: "Queued", path: "/tmp/queued.mp4")
        let runtime = RuntimeTestFactory.fullRuntimeStore()
        let viewModel = SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            runtime: runtime
        )
        viewModel.programItems = [queued]

        viewModel.currentProgramItem = queued
        viewModel.syncRuntimeStateFromFacade(clearActionLog: true)

        XCTAssertEqual(runtime.state.program.currentItem?.id, queued.id)
        XCTAssertNil(runtime.state.program.currentDetachedItem)
        XCTAssertEqual(runtime.state.program.items.count, viewModel.programItems.count)
    }

    func testDetachedMediaCurrentParticipatesInRuntimeAudioCalculation() {
        let detached = mediaProgram(title: "Detached", path: "/tmp/detached.mp4")
        var state = LiveRuntimeState()
        state.program.currentID = detached.id
        state.program.currentDetachedItem = detached
        state.media.isPlaying = true
        state.audio.masterVolume = 1
        state.audio.mediaVolume = 1
        state.audio.bgmVolume = 0

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .operatorChangedMasterVolume(0.5),
            environment: LiveRuntimeEnvironment(bridgeMode: .audioOwned)
        )

        XCTAssertEqual(mutation.state.audio.effectiveMedia, 0.5, accuracy: 0.0001)
    }

    private func mediaProgram(title: String, path: String) -> ProgramItem {
        ProgramItem(title: title, subtitle: "VIDEO", sourceURL: URL(fileURLWithPath: path))
    }
}
