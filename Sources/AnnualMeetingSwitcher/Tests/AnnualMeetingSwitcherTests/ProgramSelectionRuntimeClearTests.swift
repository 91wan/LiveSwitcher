import XCTest
@testable import LiveSwitcher

@MainActor
final class ProgramSelectionRuntimeClearTests: XCTestCase {
    func testOperatorClearedCurrentProgramRequiresProgramSelectionDomain() {
        let item = programItem("Current")
        let state = selectedState(item)

        let mutation = reduce(state, .operatorClearedCurrentProgram(reason: .operatorCleared), bridgeMode: .programQueueOwned)

        XCTAssertEqual(mutation.state.program.currentID, item.id)
        XCTAssertTrue(mutation.effects.isEmpty)
    }

    func testOperatorClearedCurrentProgramClearsCurrentID() {
        let mutation = ownedClearMutation()

        XCTAssertNil(mutation.state.program.currentID)
    }

    func testOperatorClearedCurrentProgramClearsDetachedCurrentItem() {
        var state = LiveRuntimeState()
        let item = programItem("Detached")
        state.program.currentID = item.id
        state.program.currentDetachedItem = item

        let mutation = reduce(state, .operatorClearedCurrentProgram(reason: .operatorCleared), bridgeMode: .programSelectionOwned)

        XCTAssertNil(mutation.state.program.currentDetachedItem)
    }

    func testOperatorClearedCurrentProgramClearsCurrentSwitchedAt() {
        let mutation = ownedClearMutation()

        XCTAssertNil(mutation.state.program.currentSwitchedAt)
    }

    func testOperatorClearedCurrentProgramRecalculatesAudioRoutingContext() {
        let mutation = ownedClearMutation()

        XCTAssertFalse(mutation.state.audio.routingContext.isCurrentProgramMediaSource)
    }

    func testOperatorClearedCurrentProgramEmitsApplyAudioRoutingProgramChanged() {
        let mutation = ownedClearMutation()

        XCTAssertEqual(mutation.effects, [.applyAudioRouting(reason: .programChanged)])
    }

    func testOperatorClearedCurrentProgramDoesNotStopMedia() {
        let mutation = ownedClearMutation()

        XCTAssertFalse(mutation.effects.contains { effect in
            if case .stopMedia = effect { return true }
            return false
        })
        XCTAssertEqual(mutation.state.media.loadedURL?.path, "/tmp/Current.mp4")
    }

    func testOperatorClearedCurrentProgramDoesNotMutateProgramQueue() {
        let item = programItem("Current")
        let mutation = reduce(selectedState(item), .operatorClearedCurrentProgram(reason: .operatorCleared), bridgeMode: .programSelectionOwned)

        XCTAssertEqual(mutation.state.program.items, [item])
    }

    func testOperatorClearedCurrentProgramDoesNotRecordSupport() {
        let mutation = ownedClearMutation()

        XCTAssertTrue(mutation.state.support.events.isEmpty)
    }

    func testOperatorClearedCurrentProgramSyncsCurrentProgramFacade() {
        let options = LiveRuntimeFacadeSyncPolicy.options(for: .operatorClearedCurrentProgram(reason: .operatorCleared))

        XCTAssertTrue(options.syncCurrentProgram)
        XCTAssertFalse(options.dispatchAudioInputsChanged)
    }

    private func ownedClearMutation() -> LiveRuntimeMutation {
        let item = programItem("Current")
        return reduce(selectedState(item), .operatorClearedCurrentProgram(reason: .operatorCleared), bridgeMode: .programSelectionOwned)
    }

    private func selectedState(_ item: ProgramItem) -> LiveRuntimeState {
        var state = LiveRuntimeState()
        state.program.items = [item]
        state.program.currentID = item.id
        state.program.currentSwitchedAt = Date(timeIntervalSince1970: 50)
        state.media.loadedURL = item.sourceURL
        state.media.isPlaying = true
        state.audio.routingContext.isCurrentProgramMediaSource = true
        return state
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

    private func programItem(_ title: String) -> ProgramItem {
        ProgramItem(title: title, subtitle: "MEDIA", sourceURL: URL(fileURLWithPath: "/tmp/\(title).mp4"))
    }
}
