import XCTest
@testable import LiveSwitcher

@MainActor
final class PPTMirrorTests: XCTestCase {
    func testOperatorToggledPPTModeInAudioOwnedDoesNotChangePPTState() {
        var state = LiveRuntimeState()
        state.ppt.isRequested = true
        state.ppt.isEventTapActive = true
        state.ppt.lastFailureReason = "existing"
        let originalPPT = state.ppt

        let mutation = reduce(state, .operatorToggledPPTMode(source: .liveMode), bridgeMode: .audioOwned)

        XCTAssertEqual(mutation.state.ppt, originalPPT)
        XCTAssertTrue(mutation.effects.isEmpty)
    }

    func testPPTEventTapStartedDoesNotUpdateMirrorBeforePPTOwnership() {
        let mutation = reduce(LiveRuntimeState(), .pptEventTapStarted, bridgeMode: .audioOwned)

        XCTAssertFalse(mutation.state.ppt.isRequested)
        XCTAssertFalse(mutation.state.ppt.isEventTapActive)
        XCTAssertNil(mutation.state.ppt.lastFailureReason)
    }

    func testPPTEventTapFailedDoesNotUpdateMirrorBeforePPTOwnership() {
        let mutation = reduce(LiveRuntimeState(), .pptEventTapFailed(reason: "permissionDenied"), bridgeMode: .audioOwned)

        XCTAssertFalse(mutation.state.ppt.isRequested)
        XCTAssertFalse(mutation.state.ppt.isEventTapActive)
        XCTAssertNil(mutation.state.ppt.lastFailureReason)
    }

    func testPPTEventTapStoppedDoesNotUpdateMirrorBeforePPTOwnership() {
        var state = LiveRuntimeState()
        state.ppt.isRequested = true
        state.ppt.isEventTapActive = true
        let originalPPT = state.ppt

        let mutation = reduce(state, .pptEventTapStopped(reason: .operatorDisabled), bridgeMode: .audioOwned)

        XCTAssertEqual(mutation.state.ppt, originalPPT)
    }

    func testPPTEventTapCallbacksUpdateMirrorWhenPPTOwned() {
        let started = reduce(LiveRuntimeState(), .pptEventTapStarted, bridgeMode: .pptOwned)
        XCTAssertTrue(started.state.ppt.isRequested)
        XCTAssertTrue(started.state.ppt.isEventTapActive)
        XCTAssertNil(started.state.ppt.lastFailureReason)

        let failed = reduce(started.state, .pptEventTapFailed(reason: "permissionDenied"), bridgeMode: .pptOwned)
        XCTAssertFalse(failed.state.ppt.isRequested)
        XCTAssertFalse(failed.state.ppt.isEventTapActive)
        XCTAssertEqual(failed.state.ppt.lastFailureReason, "permissionDenied")

        let stopped = reduce(started.state, .pptEventTapStopped(reason: .operatorDisabled), bridgeMode: .pptOwned)
        XCTAssertFalse(stopped.state.ppt.isRequested)
        XCTAssertFalse(stopped.state.ppt.isEventTapActive)
    }

    func testPPTCallbacksDoNotChangeAudioRoutingContext() {
        var state = LiveRuntimeState()
        state.audio.routingContext = AudioRoutingContext(
            isCurrentProgramMediaSource: true,
            isMediaPlaying: true,
            isBGMPlaying: true,
            isPanicMode: false
        )
        let originalAudio = state.audio

        let mutation = reduce(state, .pptEventTapStarted, bridgeMode: .audioOwned)

        XCTAssertEqual(mutation.state.audio, originalAudio)
    }

    func testMediaOwnedKeynoteSelectionDoesNotMutatePPTRequested() {
        let deck = ProgramItem(title: "Deck", subtitle: "KEY", sourceURL: URL(fileURLWithPath: "/tmp/deck.key"))
        var state = LiveRuntimeState()
        state.program.items = [deck]
        state.ppt.isRequested = false
        state.ppt.isEventTapActive = false

        let mutation = reduce(state, .operatorSelectedProgram(deck.id), bridgeMode: .mediaOwned)

        XCTAssertFalse(mutation.state.ppt.isRequested)
        XCTAssertFalse(mutation.state.ppt.isEventTapActive)
    }

    func testMediaOwnedPPTXSelectionDoesNotMutatePPTRequested() {
        let deck = ProgramItem(title: "Deck", subtitle: "PPTX", sourceURL: URL(fileURLWithPath: "/tmp/deck.pptx"))
        var state = LiveRuntimeState()
        state.program.items = [deck]
        state.ppt.isRequested = false
        state.ppt.isEventTapActive = false

        let mutation = reduce(state, .operatorSelectedProgram(deck.id), bridgeMode: .mediaOwned)

        XCTAssertFalse(mutation.state.ppt.isRequested)
        XCTAssertFalse(mutation.state.ppt.isEventTapActive)
    }

    func testMediaOwnedLeavingPresentationDoesNotMutatePPTActive() {
        let deck = ProgramItem(title: "Deck", subtitle: "KEY", sourceURL: URL(fileURLWithPath: "/tmp/deck.key"))
        let media = ProgramItem(title: "Video", subtitle: "VIDEO", sourceURL: URL(fileURLWithPath: "/tmp/video.mp4"))
        var state = LiveRuntimeState()
        state.program.items = [deck, media]
        state.program.currentID = deck.id
        state.ppt.isRequested = true
        state.ppt.isEventTapActive = true

        let mutation = reduce(state, .operatorSelectedProgram(media.id), bridgeMode: .mediaOwned)

        XCTAssertTrue(mutation.state.ppt.isRequested)
        XCTAssertTrue(mutation.state.ppt.isEventTapActive)
    }

    func testViewModelFailureDoesNotRecordSuccess() {
        let viewModel = makeViewModel()
        viewModel.testHooks.pageInterceptStartOverride = { false }

        viewModel.setPPTMode(true, source: .liveMode)

        XCTAssertTrue(viewModel.supportEvents.contains { $0.kind == .pageInterceptDisabled })
        XCTAssertFalse(viewModel.supportEvents.contains { $0.kind == .pptModeChanged })
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

    private func makeViewModel() -> SwitcherViewModel {
        let suiteName = "PPTMirrorTests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
        return SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            userDefaults: userDefaults
        )
    }
}
