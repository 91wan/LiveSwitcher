import XCTest
@testable import LiveSwitcher

final class ProjectionRuntimeSupportTests: XCTestCase {
    func testProjectionReducerSupportWritesRemainFullRuntimeOnly() {
        var state = LiveRuntimeState()
        state.projection.hasExternalDisplay = true

        let panicOwnedStart = reduce(state, .operatorToggledProjection, bridgeMode: .panicOwned)
        XCTAssertTrue(panicOwnedStart.state.projection.isBroadcasting)
        XCTAssertTrue(panicOwnedStart.state.support.events.isEmpty)

        let panicOwnedLost = reduce(panicOwnedStart.state, .projectionExternalDisplayLost, bridgeMode: .panicOwned)
        XCTAssertFalse(panicOwnedLost.state.projection.isBroadcasting)
        XCTAssertTrue(panicOwnedLost.state.support.events.isEmpty)

        let fullRuntimeStart = reduce(state, .operatorToggledProjection, bridgeMode: .fullRuntime)
        XCTAssertTrue(fullRuntimeStart.state.support.events.contains { $0.kind == .projectionStarted })

        let fullRuntimeLost = reduce(fullRuntimeStart.state, .projectionExternalDisplayLost, bridgeMode: .fullRuntime)
        XCTAssertTrue(fullRuntimeLost.state.support.events.contains { $0.kind == .projectionLost })
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
