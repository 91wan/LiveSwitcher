import XCTest
@testable import LiveSwitcher

@MainActor
final class MediaRuntimeProgramActivationTests: XCTestCase {
    func testProgramQueueStillOwnedByViewModel() {
        let item = mediaProgram()
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)

        viewModel.addProgramItem(item)

        XCTAssertEqual(viewModel.programItems.map(\.id), [item.id])
        XCTAssertTrue(viewModel.runtime.state.program.items.isEmpty)
    }

    func testRuntimeDoesNotMutateProgramItemsOnMediaPlaybackToggle() {
        let item = mediaProgram()
        var state = LiveRuntimeState()
        state.program.items = [item]
        state.program.currentID = item.id
        state.media.loadedURL = item.sourceURL

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .operatorToggledMediaPlayback,
            environment: LiveRuntimeEnvironment(bridgeMode: .mediaOwned)
        )

        XCTAssertEqual(mutation.state.program.items, [item])
    }

    func testCurrentProgramMirrorUpdatesFromViewModelFacade() {
        let item = mediaProgram()
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)
        viewModel.programItems = [item]

        viewModel.currentProgramItem = item

        XCTAssertEqual(viewModel.runtime.state.program.currentID, item.id)
    }

    func testRuntimeSetsMediaVolumeToZeroBeforeLoadingNewMedia() {
        let item = mediaProgram()
        var state = LiveRuntimeState()
        state.program.items = [item]

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .operatorSelectedProgram(item.id),
            environment: LiveRuntimeEnvironment(bridgeMode: .mediaOwned)
        )

        XCTAssertEqual(mutation.effects.first, .setMediaVolume(0, fade: 0, generation: 1))
    }

    func testRuntimeLoadsMediaBeforePlayMedia() {
        let item = mediaProgram()
        var state = LiveRuntimeState()
        state.program.items = [item]

        let effects = LiveRuntimeReducer.reduce(
            state: state,
            action: .operatorSelectedProgram(item.id),
            environment: LiveRuntimeEnvironment(bridgeMode: .mediaOwned)
        ).effects

        let loadIndex = effects.firstIndex {
            if case .loadMedia = $0 { return true }
            return false
        }
        let playIndex = effects.firstIndex {
            if case .playMedia = $0 { return true }
            return false
        }

        XCTAssertNotNil(loadIndex)
        XCTAssertNotNil(playIndex)
        XCTAssertLessThan(loadIndex!, playIndex!)
    }

    func testRuntimeDoesNotPlayMediaWhenPanicMirrorIsActive() {
        let item = mediaProgram()
        var state = LiveRuntimeState()
        state.program.items = [item]
        state.panic.isActive = true

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .operatorSelectedProgram(item.id),
            environment: LiveRuntimeEnvironment(bridgeMode: .mediaOwned)
        )

        XCTAssertFalse(mutation.state.media.isPlaying)
        XCTAssertFalse(mutation.effects.contains {
            if case .playMedia = $0 { return true }
            return false
        })
    }

    func testRuntimeAppliesProgramChangedAudioRoutingAfterMediaSelection() {
        let item = mediaProgram()
        var state = LiveRuntimeState()
        state.program.items = [item]

        let effects = LiveRuntimeReducer.reduce(
            state: state,
            action: .operatorSelectedProgram(item.id),
            environment: LiveRuntimeEnvironment(bridgeMode: .mediaOwned)
        ).effects

        XCTAssertEqual(effects.last, .applyAudioRouting(reason: .programChanged))
    }

    private func mediaProgram() -> ProgramItem {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        try? Data("fixture".utf8).write(to: url)
        return ProgramItem(title: "Video", subtitle: "VIDEO", sourceURL: url)
    }
}
