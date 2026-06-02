import XCTest
@testable import LiveSwitcher

final class SupportRuntimeBridgeTests: XCTestCase {
    func testAudioOwnedProjectionToggleDoesNotWriteReducerSupportEvent() {
        let mutation = LiveRuntimeReducer.reduce(
            state: LiveRuntimeState(),
            action: .operatorToggledProjection,
            environment: LiveRuntimeEnvironment(
                now: Date(timeIntervalSince1970: 100),
                bridgeMode: .audioOwned
            )
        )

        XCTAssertTrue(mutation.state.support.events.isEmpty)
        XCTAssertTrue(mutation.effects.isEmpty)
    }

    func testAudioOwnedPanicToggleDoesNotWriteReducerSupportEvent() {
        let mutation = LiveRuntimeReducer.reduce(
            state: LiveRuntimeState(),
            action: .operatorToggledPanic,
            environment: LiveRuntimeEnvironment(
                now: Date(timeIntervalSince1970: 100),
                bridgeMode: .audioOwned
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

    func testFullRuntimeProjectionAndPanicMayWriteReducerSupportEvents() {
        let projectionMutation = LiveRuntimeReducer.reduce(
            state: LiveRuntimeState(),
            action: .operatorToggledProjection,
            environment: LiveRuntimeEnvironment(
                now: Date(timeIntervalSince1970: 100),
                bridgeMode: .fullRuntime
            )
        )

        let panicMutation = LiveRuntimeReducer.reduce(
            state: LiveRuntimeState(),
            action: .operatorToggledPanic,
            environment: LiveRuntimeEnvironment(
                now: Date(timeIntervalSince1970: 100),
                bridgeMode: .fullRuntime
            )
        )

        XCTAssertTrue(projectionMutation.state.support.events.contains { $0.kind == .projectionStartFailed })
        XCTAssertTrue(panicMutation.state.support.events.contains { $0.kind == .panicModeChanged })
    }

    func testAudioOwnedProjectionStartFailureIsNotDuplicatedByReducer() {
        let first = LiveRuntimeReducer.reduce(
            state: LiveRuntimeState(),
            action: .operatorToggledProjection,
            environment: LiveRuntimeEnvironment(
                now: Date(timeIntervalSince1970: 100),
                bridgeMode: .audioOwned
            )
        )
        let second = LiveRuntimeReducer.reduce(
            state: first.state,
            action: .operatorToggledProjection,
            environment: LiveRuntimeEnvironment(
                now: Date(timeIntervalSince1970: 101),
                bridgeMode: .audioOwned
            )
        )

        XCTAssertTrue(second.state.support.events.isEmpty)
    }
}
