import XCTest
@testable import LiveSwitcher

final class RuntimeBridgeStateMutationTests: XCTestCase {
    func testAudioOwnedProgramSelectionDoesNotPredictMediaState() {
        let item = mediaProgram()
        var state = LiveRuntimeState()
        state.program.items = [item]
        let originalProgram = state.program
        let originalMedia = state.media

        let mutation = reduce(state, .operatorSelectedProgram(item.id), bridgeMode: .audioOwned)

        XCTAssertEqual(mutation.state.program, originalProgram)
        XCTAssertEqual(mutation.state.media, originalMedia)
        XCTAssertTrue(mutation.effects.isEmpty)
    }

    func testAudioOwnedPlaybackToggleDoesNotPredictMediaState() {
        var state = LiveRuntimeState()
        state.media.isPlaying = true
        let originalMedia = state.media

        let mutation = reduce(state, .operatorToggledMediaPlayback, bridgeMode: .audioOwned)

        XCTAssertEqual(mutation.state.media, originalMedia)
        XCTAssertTrue(mutation.effects.isEmpty)
    }

    func testAudioOwnedRestartDoesNotPredictMediaState() {
        var state = LiveRuntimeState()
        state.program.currentDetachedItem = mediaProgram()
        state.media.currentTime = 4
        state.media.isPlaying = false
        let originalMedia = state.media

        let mutation = reduce(state, .operatorRestartedCurrentMedia, bridgeMode: .audioOwned)

        XCTAssertEqual(mutation.state.media, originalMedia)
        XCTAssertTrue(mutation.effects.isEmpty)
    }

    func testAudioOwnedBGMSelectionDoesNotPredictBGMState() {
        let item = bgmItem()
        var state = LiveRuntimeState()
        state.bgm.items = [item]
        let originalBGM = state.bgm

        let mutation = reduce(state, .operatorSelectedBGM(item.id), bridgeMode: .audioOwned)

        XCTAssertEqual(mutation.state.bgm, originalBGM)
        XCTAssertTrue(mutation.effects.isEmpty)
    }

    func testAudioOwnedBGMStopDoesNotPredictBGMState() {
        let item = bgmItem()
        var state = LiveRuntimeState()
        state.bgm.items = [item]
        state.bgm.currentID = item.id
        state.bgm.isPlaying = true
        let originalBGM = state.bgm

        let mutation = reduce(state, .operatorStoppedBGM, bridgeMode: .audioOwned)

        XCTAssertEqual(mutation.state.bgm, originalBGM)
        XCTAssertTrue(mutation.effects.isEmpty)
    }

    func testAudioOwnedProjectionToggleDoesNotPredictProjectionState() {
        var state = LiveRuntimeState()
        state.projection.hasExternalDisplay = true
        let originalProjection = state.projection

        let mutation = reduce(state, .operatorToggledProjection, bridgeMode: .audioOwned)

        XCTAssertEqual(mutation.state.projection, originalProjection)
        XCTAssertTrue(mutation.effects.isEmpty)
    }

    func testAudioOwnedPPTToggleDoesNotPredictPPTState() {
        var state = LiveRuntimeState()
        state.ppt.isRequested = true
        let originalPPT = state.ppt

        let mutation = reduce(state, .operatorToggledPPTMode(source: .liveMode), bridgeMode: .audioOwned)

        XCTAssertEqual(mutation.state.ppt, originalPPT)
        XCTAssertTrue(mutation.effects.isEmpty)
    }

    func testAudioOwnedPanicToggleDoesNotPredictPanicState() {
        var state = LiveRuntimeState()
        state.panic.isActive = false
        state.media.isPlaying = true
        let originalPanic = state.panic
        let originalMedia = state.media

        let mutation = reduce(state, .operatorToggledPanic, bridgeMode: .audioOwned)

        XCTAssertEqual(mutation.state.panic, originalPanic)
        XCTAssertEqual(mutation.state.media, originalMedia)
        XCTAssertTrue(mutation.effects.isEmpty)
    }

    func testAudioOwnedCallbackMayUpdateMediaMirror() {
        var state = LiveRuntimeState()
        state.media.generation = 2

        let mutation = reduce(state, .mediaPlaybackChanged(isPlaying: true, generation: 2), bridgeMode: .audioOwned)

        XCTAssertTrue(mutation.state.media.isPlaying)
        XCTAssertTrue(mutation.effects.contains(.applyAudioRouting(reason: .mediaPlaybackChanged)))
    }

    func testAudioOwnedCallbackMayUpdateBGMMirror() {
        var state = LiveRuntimeState()
        state.bgm.generation = 3

        let mutation = reduce(state, .bgmPlaybackChanged(isPlaying: true, generation: 3), bridgeMode: .audioOwned)

        XCTAssertTrue(mutation.state.bgm.isPlaying)
        XCTAssertTrue(mutation.effects.contains(.applyAudioRouting(reason: .bgmPlaybackChanged)))
    }

    func testAudioOwnedCallbackMayUpdatePPTMirror() {
        let mutation = reduce(LiveRuntimeState(), .pptEventTapStarted, bridgeMode: .audioOwned)

        XCTAssertTrue(mutation.state.ppt.isRequested)
        XCTAssertTrue(mutation.state.ppt.isEventTapActive)
        XCTAssertTrue(mutation.effects.isEmpty)
    }

    func testAudioOwnedCallbackMayUpdateProjectionMirror() {
        let mutation = reduce(LiveRuntimeState(), .projectionExternalDisplayAvailable, bridgeMode: .audioOwned)

        XCTAssertTrue(mutation.state.projection.hasExternalDisplay)
        XCTAssertTrue(mutation.effects.isEmpty)
    }

    func testFullRuntimeStillMutatesOwnedDomains() {
        let item = mediaProgram()
        var state = LiveRuntimeState()
        state.program.items = [item]

        let mutation = reduce(state, .operatorSelectedProgram(item.id), bridgeMode: .fullRuntime)

        XCTAssertEqual(mutation.state.program.currentID, item.id)
        XCTAssertTrue(mutation.state.media.isPlaying)
        XCTAssertTrue(mutation.effects.contains(.loadMedia(item.sourceURL!, generation: 1)))
        XCTAssertTrue(mutation.effects.contains(.playMedia(generation: 1)))
    }

    private func reduce(
        _ state: LiveRuntimeState,
        _ action: LiveRuntimeAction,
        bridgeMode: LiveRuntimeBridgeMode
    ) -> LiveRuntimeMutation {
        LiveRuntimeReducer.reduce(
            state: state,
            action: action,
            environment: LiveRuntimeEnvironment(bridgeMode: bridgeMode)
        )
    }

    private func mediaProgram() -> ProgramItem {
        ProgramItem(
            title: "Video",
            subtitle: "VIDEO",
            sourceURL: URL(fileURLWithPath: "/tmp/video.mp4")
        )
    }

    private func bgmItem() -> BGMItem {
        BGMItem(title: "Walk-in", url: URL(fileURLWithPath: "/tmp/walk-in.mp3"))
    }
}
