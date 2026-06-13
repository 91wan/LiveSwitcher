import XCTest
@testable import LiveSwitcher

final class SupportRuntimeBridgeTests: XCTestCase {
    func testAudioOwnedProjectionToggleDoesNotWriteReducerSupportEvent() {
        let mutation = LiveRuntimeReducer.reduce(
            state: LiveRuntimeState(),
            action: .operatorToggledProjection,
            environment: .productionAudioOwned(
                now: Date(timeIntervalSince1970: 100)
            )
        )

        XCTAssertTrue(mutation.state.support.events.isEmpty)
        XCTAssertTrue(mutation.effects.isEmpty)
    }

    func testAudioOwnedPanicToggleDoesNotWriteReducerSupportEvent() {
        let mutation = LiveRuntimeReducer.reduce(
            state: LiveRuntimeState(),
            action: .operatorToggledPanic,
            environment: .productionAudioOwned(
                now: Date(timeIntervalSince1970: 100)
            )
        )

        XCTAssertTrue(mutation.state.support.events.isEmpty)
    }

    func testAudioOwnedSupportEventRecordedWritesSupportEvent() throws {
        let event = LiveSupportEvent(
            timestamp: Date(timeIntervalSince1970: 100),
            kind: .projectionStartFailed,
            detail: "reason=noExternalDisplay"
        )

        let mutation = LiveRuntimeReducer.reduce(
            state: LiveRuntimeState(),
            action: .supportEventRecorded(event),
            environment: LiveRuntimeEnvironment(bridgeMode: .audioOwned)
        )

        let recorded = try XCTUnwrap(mutation.state.support.events.first)
        XCTAssertEqual(recorded.kind, .projectionStartFailed)
        XCTAssertEqual(recorded.detail, "reason=noExternalDisplay")
    }

    func testFullRuntimeProjectionMayWriteReducerSupportEventsButPanicDoesNot() {
        let projectionMutation = LiveRuntimeReducer.reduce(
            state: LiveRuntimeState(),
            action: .operatorToggledProjection,
            environment: .fullRuntimeForTests(
                now: Date(timeIntervalSince1970: 100)
            )
        )

        let panicMutation = LiveRuntimeReducer.reduce(
            state: LiveRuntimeState(),
            action: .operatorToggledPanic,
            environment: .fullRuntimeForTests(
                now: Date(timeIntervalSince1970: 100)
            )
        )

        XCTAssertTrue(projectionMutation.state.support.events.contains { $0.kind == .projectionStartFailed })
        XCTAssertFalse(panicMutation.state.support.events.contains { $0.kind == .panicModeChanged })
    }

    func testAudioOwnedProjectionStartFailureIsNotDuplicatedByReducer() {
        let first = LiveRuntimeReducer.reduce(
            state: LiveRuntimeState(),
            action: .operatorToggledProjection,
            environment: .productionAudioOwned(
                now: Date(timeIntervalSince1970: 100)
            )
        )
        let second = LiveRuntimeReducer.reduce(
            state: first.state,
            action: .operatorToggledProjection,
            environment: .productionAudioOwned(
                now: Date(timeIntervalSince1970: 101)
            )
        )

        XCTAssertTrue(second.state.support.events.isEmpty)
    }
}
