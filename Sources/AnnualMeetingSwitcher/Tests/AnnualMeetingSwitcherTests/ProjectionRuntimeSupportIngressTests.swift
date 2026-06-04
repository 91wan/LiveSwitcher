import AppKit
import XCTest
@testable import LiveSwitcher

@MainActor
final class ProjectionRuntimeSupportIngressTests: XCTestCase {
    func testProjectionOwnedReducerDoesNotWriteProjectionStartedSupport() {
        var state = LiveRuntimeState()
        state.projection.hasExternalDisplay = true

        let mutation = reduce(state, .operatorToggledProjection)

        XCTAssertTrue(mutation.state.support.events.isEmpty)
    }

    func testProjectionOwnedReducerDoesNotWriteProjectionStoppedSupport() {
        var state = LiveRuntimeState()
        state.projection.isBroadcasting = true
        state.projection.hasExternalDisplay = true

        let mutation = reduce(state, .operatorToggledProjection)

        XCTAssertTrue(mutation.state.support.events.isEmpty)
    }

    func testProjectionOwnedReducerDoesNotWriteProjectionLostSupport() {
        var state = LiveRuntimeState()
        state.projection.isBroadcasting = true
        state.projection.hasExternalDisplay = true

        let mutation = reduce(state, .projectionExternalDisplayLost)

        XCTAssertTrue(mutation.state.support.events.isEmpty)
    }

    func testViewModelRecordsProjectionStartedSupportAfterRuntimeTransition() throws {
        let viewModel = try makeProjectionOwnedViewModel(isBroadcasting: false, hasExternalDisplay: true)

        viewModel.handleBroadcastToggle()

        XCTAssertTrue(viewModel.supportEvents.contains { $0.kind == .projectionStarted })
        XCTAssertTrue(viewModel.supportEvents.contains { $0.kind == .projectionToggle })
    }

    func testViewModelRecordsProjectionLostSupportAfterRuntimeTransition() throws {
        let viewModel = try makeProjectionOwnedViewModel(isBroadcasting: true, hasExternalDisplay: true)

        viewModel.handleExternalDisplayLost()

        XCTAssertTrue(viewModel.supportEvents.contains { $0.kind == .projectionFailClosed })
        XCTAssertTrue(viewModel.supportEvents.contains { $0.kind == .projectionLost })
    }

    func testSupportEventRecordedStillWritesRuntimeSupportStorage() {
        let event = LiveSupportEvent(
            timestamp: Date(timeIntervalSince1970: 100),
            kind: .projectionStarted,
            detail: "source=viewModel"
        )

        let mutation = reduce(LiveRuntimeState(), .supportEventRecorded(event))

        XCTAssertEqual(mutation.state.support.events.map(\.kind), [.projectionStarted])
    }

    private func reduce(
        _ state: LiveRuntimeState,
        _ action: LiveRuntimeAction
    ) -> LiveRuntimeMutation {
        LiveRuntimeReducer.reduce(
            state: state,
            action: action,
            environment: LiveRuntimeEnvironment(now: Date(timeIntervalSince1970: 100), bridgeMode: .projectionOwned)
        )
    }

    private func makeProjectionOwnedViewModel(
        isBroadcasting: Bool,
        hasExternalDisplay: Bool
    ) throws -> SwitcherViewModel {
        let screen = NSScreen.main ?? NSScreen.screens.first
        if hasExternalDisplay, screen == nil {
            throw XCTSkip("No NSScreen is available in this test environment.")
        }
        var state = LiveRuntimeState()
        state.projection.isBroadcasting = isBroadcasting
        state.projection.hasExternalDisplay = hasExternalDisplay
        let runtime = LiveRuntimeStore(
            initialState: state,
            effectRunner: .recording(),
            environment: LiveRuntimeEnvironment(bridgeMode: .projectionOwned)
        )
        let viewModel = SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            runtime: runtime
        )
        viewModel.isBroadcasting = isBroadcasting
        viewModel.externalScreenProvider = { hasExternalDisplay ? screen : nil }
        viewModel.refreshExternalDisplayAvailability()
        return viewModel
    }
}
