import AppKit
import XCTest
@testable import LiveSwitcher

@MainActor
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

    func testProjectionToggleRecordsViewModelSupportEvents() throws {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            throw XCTSkip("No NSScreen is available in this test environment.")
        }
        var state = LiveRuntimeState()
        state.projection.hasExternalDisplay = true
        let viewModel = makeViewModel(runtimeState: state)
        viewModel.externalScreenProvider = { screen }

        viewModel.handleBroadcastToggle()

        XCTAssertTrue(viewModel.supportEvents.contains { $0.kind == .projectionStarted })
        XCTAssertTrue(viewModel.supportEvents.contains { $0.kind == .projectionToggle })
    }

    func testProjectionStartFailureRecordsViewModelSupportEvents() {
        let viewModel = makeViewModel()
        viewModel.externalScreenProvider = { nil }
        viewModel.refreshExternalDisplayAvailability()

        viewModel.handleBroadcastToggle()

        XCTAssertTrue(viewModel.supportEvents.contains { $0.kind == .projectionFailClosed })
        XCTAssertTrue(viewModel.supportEvents.contains { $0.kind == .projectionStartFailed })
    }

    func testProjectionDisplayLostRecordsViewModelSupportEvents() {
        var state = LiveRuntimeState()
        state.projection.hasExternalDisplay = true
        state.projection.isBroadcasting = true
        let viewModel = makeViewModel(runtimeState: state)

        viewModel.handleExternalDisplayLost()

        XCTAssertTrue(viewModel.supportEvents.contains { $0.kind == .projectionFailClosed })
        XCTAssertTrue(viewModel.supportEvents.contains { $0.kind == .projectionLost })
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

    private func makeViewModel(runtimeState: LiveRuntimeState = LiveRuntimeState()) -> SwitcherViewModel {
        let runtime = LiveRuntimeStore(
            initialState: runtimeState,
            effectRunner: .recording(),
            environment: .productionPanicOwning(now: Date(timeIntervalSince1970: 100))
        )
        let suiteName = "ProjectionRuntimeSupportTests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
        return SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            userDefaults: userDefaults,
            runtime: runtime
        )
    }
}
