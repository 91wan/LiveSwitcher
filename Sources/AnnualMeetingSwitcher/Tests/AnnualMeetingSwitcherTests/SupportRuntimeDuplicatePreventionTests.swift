import XCTest
@testable import LiveSwitcher

@MainActor
final class SupportRuntimeDuplicatePreventionTests: XCTestCase {
    func testSupportOwnedProjectionToggleDoesNotGenerateReducerSupportEvent() {
        let mutation = reduce(.operatorToggledProjection, bridgeMode: .supportOwned)

        XCTAssertTrue(mutation.state.support.events.isEmpty)
    }

    func testSupportOwnedPPTCallbackDoesNotGenerateReducerSupportEvent() {
        let mutation = reduce(.pptEventTapStarted, bridgeMode: .supportOwned)

        XCTAssertTrue(mutation.state.support.events.isEmpty)
    }

    func testSupportOwnedAutomationFailureDoesNotGenerateReducerSupportEvent() {
        let mutation = reduce(
            .automationFailed(action: "keynote.next-slide", sanitizedMessage: "failed"),
            bridgeMode: .supportOwned
        )

        XCTAssertTrue(mutation.state.support.events.isEmpty)
    }

    func testSupportEventRecordedAddsOneRuntimeEventAndOneAcceptedPortEffect() {
        let event = LiveSupportEvent(
            timestamp: Date(timeIntervalSince1970: 100),
            kind: .projectionStarted,
            detail: "source=viewModel"
        )

        let mutation = reduce(.supportEventRecorded(event), bridgeMode: .supportOwned)

        XCTAssertEqual(mutation.state.support.events.count, 1)
        XCTAssertEqual(mutation.effects, mutation.state.support.events.map(LiveRuntimeEffect.recordSupportEvent))
    }

    func testSupportOwnedBGMFailureDoesNotGenerateReducerSupportEvent() {
        var state = LiveRuntimeState()
        state.bgm.generation = 7

        let mutation = reduce(state, .bgmFailed(reason: "failed", generation: 7), bridgeMode: .supportOwned)

        XCTAssertTrue(mutation.state.support.events.isEmpty)
    }

    func testSupportOwnedPanicToggleDoesNotGenerateReducerSupportEvent() {
        let mutation = reduce(.operatorToggledPanic, bridgeMode: .supportOwned)

        XCTAssertTrue(mutation.state.support.events.isEmpty)
    }

    func testViewModelRecordSupportEventDoesNotDuplicateFacadeEvents() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)

        viewModel.recordSupportEvent(
            kind: .projectionStarted,
            detail: "source=viewModel",
            timestamp: Date(timeIntervalSince1970: 100)
        )

        XCTAssertEqual(viewModel.supportEvents.count, 1)
        XCTAssertEqual(viewModel.runtime.state.support.events.count, 1)
    }

    private func reduce(
        _ action: LiveRuntimeAction,
        bridgeMode: LiveRuntimeBridgeMode
    ) -> LiveRuntimeMutation {
        reduce(LiveRuntimeState(), action, bridgeMode: bridgeMode)
    }

    private func reduce(
        _ state: LiveRuntimeState,
        _ action: LiveRuntimeAction,
        bridgeMode: LiveRuntimeBridgeMode
    ) -> LiveRuntimeMutation {
        LiveRuntimeReducer.reduce(
            state: state,
            action: action,
            environment: LiveRuntimeEnvironment(now: Date(timeIntervalSince1970: 100), bridgeMode: bridgeMode)
        )
    }
}
