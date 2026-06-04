import XCTest
@testable import LiveSwitcher

@MainActor
final class SupportRuntimeProductionBoundaryTests: XCTestCase {
    func testProductionRuntimeWiresSupportButNotAutomation() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)

        XCTAssertTrue(viewModel.runtimeConnectedPortKinds.contains(.support))
        XCTAssertFalse(viewModel.runtimeConnectedPortKinds.contains(.automation))
    }

    func testProductionSupportEventIngressRecordsThroughRuntimeState() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)

        viewModel.recordSupportEvent(
            kind: .preflightAction,
            detail: "action=manualReview",
            timestamp: Date(timeIntervalSince1970: 100)
        )

        XCTAssertEqual(viewModel.runtime.actionLog.last?.actionName, "supportEventRecorded")
        XCTAssertEqual(viewModel.supportEvents, viewModel.runtime.state.support.events)
    }

    func testAutomationNoticeOwnedBoundaryStillBlocksSupportPortEffect() {
        let event = LiveSupportEvent(
            timestamp: Date(timeIntervalSince1970: 100),
            kind: .preflightAction,
            detail: "action=manualReview"
        )

        let mutation = LiveRuntimeReducer.reduce(
            state: LiveRuntimeState(),
            action: .supportEventRecorded(event),
            environment: .productionAutomationNoticeOwning(now: Date(timeIntervalSince1970: 100))
        )

        XCTAssertFalse(mutation.effects.contains(.recordSupportEvent(event)))
    }
}
