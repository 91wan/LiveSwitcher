import XCTest
@testable import LiveSwitcher

final class ProjectionRuntimeCallbackGuardTests: XCTestCase {
    func testProjectionCallbacksAreNoOpsBeforeProjectionOwnership() {
        let actions: [LiveRuntimeAction] = [
            .operatorToggledProjection,
            .projectionStartFailed(reason: .noTargetScreen),
            .projectionExternalDisplayLost,
            .projectionExternalDisplayAvailable,
            .projectionExternalDisplayUnavailable
        ]

        for action in actions {
            var state = LiveRuntimeState()
            state.projection.isBroadcasting = true
            state.projection.hasExternalDisplay = true
            state.projection.lastDisplayLostAt = Date(timeIntervalSince1970: 50)
            state.projection.safetyNotice = "existing"
            let originalProjection = state.projection

            let mutation = LiveRuntimeReducer.reduce(
                state: state,
                action: action,
                environment: .productionBGMOwning(now: Date(timeIntervalSince1970: 100))
            )

            XCTAssertEqual(mutation.state.projection, originalProjection, "Unexpected projection mutation for \(action.redactedName)")
            XCTAssertTrue(mutation.effects.isEmpty, "Unexpected projection effect for \(action.redactedName)")
            XCTAssertTrue(mutation.state.support.events.isEmpty, "Unexpected reducer support write for \(action.redactedName)")
        }
    }
}
