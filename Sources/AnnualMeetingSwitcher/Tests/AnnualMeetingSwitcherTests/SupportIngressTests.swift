import XCTest
@testable import LiveSwitcher

final class SupportIngressTests: XCTestCase {
    func testAudioOwnedProjectionActionDoesNotWriteSupportEvent() {
        let mutation = reduce(.operatorToggledProjection, bridgeMode: .audioOwned)

        XCTAssertTrue(mutation.state.support.events.isEmpty)
    }

    func testAudioOwnedProjectionDisplayLossDoesNotWriteSupportEvent() {
        var state = LiveRuntimeState()
        state.projection.isBroadcasting = true
        state.projection.hasExternalDisplay = true

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .projectionExternalDisplayLost,
            environment: LiveRuntimeEnvironment(bridgeMode: .audioOwned)
        )

        XCTAssertTrue(mutation.state.support.events.isEmpty)
    }

    func testAudioOwnedPanicActionDoesNotWriteSupportEvent() {
        let mutation = reduce(.operatorToggledPanic, bridgeMode: .audioOwned)

        XCTAssertTrue(mutation.state.support.events.isEmpty)
    }

    func testAudioOwnedPPTCallbackDoesNotWriteSupportEvent() {
        let mutation = reduce(.pptEventTapStarted, bridgeMode: .audioOwned)

        XCTAssertTrue(mutation.state.support.events.isEmpty)
    }

    func testAudioOwnedBGMFailureDoesNotWriteSupportEvent() {
        var state = LiveRuntimeState()
        state.bgm.generation = 3
        state.bgm.isPlaying = true

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .bgmFailed(reason: "decode", generation: 3),
            environment: LiveRuntimeEnvironment(bridgeMode: .audioOwned)
        )

        XCTAssertTrue(mutation.state.support.events.isEmpty)
    }

    func testAudioOwnedAutomationFailureDoesNotWriteSupportEvent() {
        let mutation = reduce(
            .automationFailed(action: "keynote.open", sanitizedMessage: "failed"),
            bridgeMode: .audioOwned
        )

        XCTAssertTrue(mutation.state.support.events.isEmpty)
    }

    func testSupportEventRecordedWritesRuntimeSupportEvent() throws {
        let event = LiveSupportEvent(
            timestamp: Date(timeIntervalSince1970: 10),
            kind: .appleScriptFailed,
            detail: "action=open,error=failed"
        )

        let mutation = reduce(.supportEventRecorded(event), bridgeMode: .audioOwned)

        let recorded = try XCTUnwrap(mutation.state.support.events.first)
        XCTAssertEqual(recorded.kind, .appleScriptFailed)
        XCTAssertEqual(recorded.detail, "action=open,error=failed")
    }

    func testFullRuntimeMayWriteReducerGeneratedSupportEvents() {
        let mutation = reduce(.operatorToggledProjection, bridgeMode: .fullRuntime)

        XCTAssertTrue(mutation.state.support.events.contains { $0.kind == .projectionStartFailed })
    }

    private func reduce(
        _ action: LiveRuntimeAction,
        bridgeMode: LiveRuntimeBridgeMode
    ) -> LiveRuntimeMutation {
        LiveRuntimeReducer.reduce(
            state: LiveRuntimeState(),
            action: action,
            environment: LiveRuntimeEnvironment(now: Date(timeIntervalSince1970: 100), bridgeMode: bridgeMode)
        )
    }
}
