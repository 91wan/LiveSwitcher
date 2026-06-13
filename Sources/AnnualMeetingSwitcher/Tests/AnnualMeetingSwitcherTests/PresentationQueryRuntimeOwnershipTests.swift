import XCTest
@testable import LiveSwitcher

@MainActor
final class PresentationQueryRuntimeOwnershipTests: XCTestCase {
    func testPresentationQueryOwnedModeOwnsPriorDomainsAndPresentationQuery() {
        let mode = LiveRuntimeBridgeMode.presentationQueryOwned

        XCTAssertTrue(mode.owns(.audio))
        XCTAssertTrue(mode.owns(.media))
        XCTAssertTrue(mode.owns(.bgm))
        XCTAssertTrue(mode.owns(.projection))
        XCTAssertTrue(mode.owns(.ppt))
        XCTAssertTrue(mode.owns(.automationNotice))
        XCTAssertTrue(mode.owns(.support))
        XCTAssertTrue(mode.owns(.automationCommand))
        XCTAssertTrue(mode.owns(.presentationQuery))
    }

    func testPresentationQueryOwnedModeStillOwnsImageAssetsAndPersistence() {
        let mode = LiveRuntimeBridgeMode.presentationQueryOwned

        XCTAssertTrue(mode.owns(.imageAssets))
        XCTAssertTrue(mode.owns(.persistence))
    }

    func testPresentationQueryOwnedModeDoesNotOwnLegacyBroadAutomationDomain() {
        XCTAssertFalse(LiveRuntimeBridgeMode.presentationQueryOwned.owns(.automation))
    }

    func testProductionViewModelRuntimeBridgeModeIsPanicOwned() {
        let viewModel = makeViewModel()

        XCTAssertEqual(viewModel.runtimeBridgeMode, .panicOwned)
    }

    func testProductionConnectedPortsExactlyMatchExplicitRuntimeSet() {
        let viewModel = makeViewModel()

        XCTAssertEqual(
            viewModel.runtimeConnectedPortKinds,
            [.media, .bgm, .bgmTimer, .panicDelay, .projection, .ppt, .automationNotice, .support, .automation, .presentationQuery, .programActivation, .audioRouting, .imageAssets, .persistence]
        )
    }

    func testOperatorRequestedPresentationQueryEmitsScanEffectWhenOwned() {
        let id = UUID()
        let mutation = reduce(.operatorRequestedPresentationQuery(id: id), bridgeMode: .presentationQueryOwned)

        XCTAssertEqual(mutation.state.presentationQuery.activeRequestID, id)
        XCTAssertEqual(mutation.effects, [.scanPresentationQuery(id: id)])
    }

    func testOperatorRequestedPresentationQueryNoopsBeforeOwnership() {
        let id = UUID()
        let mutation = reduce(.operatorRequestedPresentationQuery(id: id), bridgeMode: .automationCommandOwned)

        XCTAssertNil(mutation.state.presentationQuery.activeRequestID)
        XCTAssertEqual(mutation.effects, [])
    }

    func testPresentationQueryCompletedStoresResultForActiveRequest() {
        let id = UUID()
        var state = LiveRuntimeState()
        state.presentationQuery.activeRequestID = id
        let result = PresentationQueryResult(openFilePaths: ["/tmp/show/Opening.key"], windowNames: [])
        let mutation = reduce(state, .presentationQueryCompleted(id: id, result: result), bridgeMode: .presentationQueryOwned)

        XCTAssertNil(mutation.state.presentationQuery.activeRequestID)
        XCTAssertEqual(mutation.state.presentationQuery.latestCompletedRequestID, id)
        XCTAssertEqual(mutation.state.presentationQuery.latestResult, result)
        XCTAssertNil(mutation.state.presentationQuery.latestFailure)
        XCTAssertTrue(mutation.state.program.items.isEmpty)
    }

    func testPresentationQueryCompletedIgnoresStaleRequest() {
        var state = LiveRuntimeState()
        state.presentationQuery.activeRequestID = UUID()
        let staleID = UUID()
        let result = PresentationQueryResult(openFilePaths: ["/tmp/show/Opening.key"], windowNames: [])
        let mutation = reduce(state, .presentationQueryCompleted(id: staleID, result: result), bridgeMode: .presentationQueryOwned)

        XCTAssertNil(mutation.state.presentationQuery.latestCompletedRequestID)
        XCTAssertNil(mutation.state.presentationQuery.latestResult)
    }

    func testPresentationQueryFailedStoresFailureForActiveRequest() {
        let id = UUID()
        var state = LiveRuntimeState()
        state.presentationQuery.activeRequestID = id
        let mutation = reduce(
            state,
            .presentationQueryFailed(id: id, action: "keynote.scan.windows", sanitizedMessage: "permissionDenied"),
            bridgeMode: .presentationQueryOwned
        )

        XCTAssertNil(mutation.state.presentationQuery.activeRequestID)
        XCTAssertEqual(mutation.state.presentationQuery.latestFailure?.id, id)
        XCTAssertEqual(mutation.state.presentationQuery.latestFailure?.action, "keynote.scan.windows")
        XCTAssertEqual(mutation.state.presentationQuery.latestFailure?.sanitizedMessage, "permissionDenied")
        XCTAssertNil(mutation.state.presentationQuery.latestResult)
    }

    func testPresentationQueryFailedIgnoresStaleRequest() {
        var state = LiveRuntimeState()
        state.presentationQuery.activeRequestID = UUID()
        let mutation = reduce(
            state,
            .presentationQueryFailed(id: UUID(), action: "keynote.scan.windows", sanitizedMessage: "failed"),
            bridgeMode: .presentationQueryOwned
        )

        XCTAssertNil(mutation.state.presentationQuery.latestFailure)
    }

    func testPresentationQueryResultConsumedPreventsReapplication() {
        let id = UUID()
        var state = LiveRuntimeState()
        state.presentationQuery.latestCompletedRequestID = id
        state.presentationQuery.latestResult = .empty
        let mutation = reduce(state, .presentationQueryResultConsumed(id: id), bridgeMode: .presentationQueryOwned)

        XCTAssertTrue(mutation.state.presentationQuery.consumedRequestIDs.contains(id))
        XCTAssertNil(mutation.state.presentationQuery.latestResult)
    }

    func testPresentationQueryReducerDoesNotMutateProgramQueue() {
        let id = UUID()
        var state = LiveRuntimeState()
        state.presentationQuery.activeRequestID = id
        let originalProgram = ProgramItem(title: "Existing", subtitle: "KEY")
        state.program.items = [originalProgram]
        let result = PresentationQueryResult(openFilePaths: ["/tmp/show/New.key"], windowNames: [])

        let mutation = reduce(state, .presentationQueryCompleted(id: id, result: result), bridgeMode: .presentationQueryOwned)

        XCTAssertEqual(mutation.state.program.items, [originalProgram])
    }

    func testPresentationQueryReducerDoesNotWriteSupport() {
        let id = UUID()
        var state = LiveRuntimeState()
        state.presentationQuery.activeRequestID = id
        let mutation = reduce(
            state,
            .presentationQueryFailed(id: id, action: "keynote.scan.windows", sanitizedMessage: "failed"),
            bridgeMode: .presentationQueryOwned
        )

        XCTAssertTrue(mutation.state.support.events.isEmpty)
        XCTAssertFalse(mutation.effects.contains { effect in
            if case .recordSupportEvent = effect { return true }
            return false
        })
    }

    private func reduce(_ action: LiveRuntimeAction, bridgeMode: LiveRuntimeBridgeMode) -> LiveRuntimeMutation {
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
            environment: LiveRuntimeEnvironment(bridgeMode: bridgeMode)
        )
    }

    private func makeViewModel() -> SwitcherViewModel {
        let suiteName = "PresentationQueryRuntimeOwnershipTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false, userDefaults: defaults)
    }
}
