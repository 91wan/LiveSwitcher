import XCTest
@testable import LiveSwitcher

final class ProjectionBridgeGuardTests: XCTestCase {
    func testAudioOwnedProjectionToggleUpdatesMirrorButBlocksProjectionEffects() {
        var state = LiveRuntimeState()
        state.projection.hasExternalDisplay = true

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .operatorToggledProjection,
            environment: LiveRuntimeEnvironment(
                now: Date(timeIntervalSince1970: 100),
                bridgeMode: .audioOwned
            )
        )

        XCTAssertTrue(mutation.state.projection.isBroadcasting)
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
