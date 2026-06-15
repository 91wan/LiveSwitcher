import XCTest
@testable import LiveSwitcher

final class RuntimeSupportOwnershipGateTests: XCTestCase {
    func testAudioOwnedCannotWriteReducerSupport() {
        let mutation = projectionStartFailure(bridgeMode: .audioOwned)

        XCTAssertTrue(mutation.state.support.events.isEmpty)
    }

    func testMediaOwnedCannotWriteReducerSupport() {
        let mutation = projectionStartFailure(bridgeMode: .mediaOwned)

        XCTAssertTrue(mutation.state.support.events.isEmpty)
    }

    func testBGMOwningModeStillCannotWriteReducerSupport() {
        var state = LiveRuntimeState()
        state.bgm.generation = 4

        let mutation = reduce(
            state,
            .bgmFailed(reason: "decode", generation: 4),
            bridgeMode: .bgmOwned
        )

        XCTAssertTrue(mutation.state.support.events.isEmpty)
    }

    func testProjectionOwningModeStillCannotWriteReducerSupport() {
        let mutation = projectionStartFailure(bridgeMode: .projectionOwned)

        XCTAssertTrue(mutation.state.support.events.isEmpty)
    }

    func testFullRuntimeCanWriteReducerSupport() {
        let mutation = projectionStartFailure(bridgeMode: .fullRuntime)

        XCTAssertTrue(mutation.state.support.events.contains { $0.kind == .projectionStartFailed })
    }

    func testSupportEventRecordedStillWritesSupportStorageWhenSupportOwned() throws {
        let event = LiveSupportEvent(
            timestamp: Date(timeIntervalSince1970: 10),
            kind: .preflightAction,
            detail: "action=manualReview"
        )

        let mutation = reduce(.supportEventRecorded(event), bridgeMode: .supportOwned)

        let recorded = try XCTUnwrap(mutation.state.support.events.first)
        XCTAssertEqual(recorded.kind, .preflightAction)
        XCTAssertEqual(recorded.detail, "action=manualReview")
    }

    private func projectionStartFailure(bridgeMode: LiveRuntimeBridgeMode) -> LiveRuntimeMutation {
        reduce(.operatorToggledProjection, bridgeMode: bridgeMode)
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
