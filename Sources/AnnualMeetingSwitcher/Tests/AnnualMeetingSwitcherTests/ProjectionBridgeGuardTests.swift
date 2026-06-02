import XCTest
@testable import LiveSwitcher

final class ProjectionBridgeGuardTests: XCTestCase {
    func testAudioOwnedProjectionToggleDoesNotMutateProjectionStateOrWriteSupport() {
        var state = LiveRuntimeState()
        state.projection.hasExternalDisplay = true
        let originalProjection = state.projection

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .operatorToggledProjection,
            environment: LiveRuntimeEnvironment(
                now: Date(timeIntervalSince1970: 100),
                bridgeMode: .audioOwned
            )
        )

        XCTAssertEqual(mutation.state.projection, originalProjection)
        XCTAssertTrue(mutation.state.support.events.isEmpty)
        XCTAssertTrue(mutation.effects.isEmpty)
    }

    func testAudioOwnedDisplayLossUpdatesMirrorButBlocksStopProjectionEffect() {
        var state = LiveRuntimeState()
        state.projection.isBroadcasting = true
        state.projection.hasExternalDisplay = true

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .projectionExternalDisplayLost,
            environment: LiveRuntimeEnvironment(
                now: Date(timeIntervalSince1970: 100),
                bridgeMode: .audioOwned
            )
        )

        XCTAssertFalse(mutation.state.projection.isBroadcasting)
        XCTAssertFalse(mutation.state.projection.hasExternalDisplay)
        XCTAssertTrue(mutation.effects.isEmpty)
    }

    func testProjectionOwnedModeAllowsProjectionEffects() {
        var state = LiveRuntimeState()
        state.projection.hasExternalDisplay = true

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .operatorToggledProjection,
            environment: LiveRuntimeEnvironment(bridgeMode: .projectionOwned)
        )

        XCTAssertTrue(mutation.effects.contains(.startProjection))
        XCTAssertTrue(mutation.effects.contains(.showOutputWindow))
    }
}
