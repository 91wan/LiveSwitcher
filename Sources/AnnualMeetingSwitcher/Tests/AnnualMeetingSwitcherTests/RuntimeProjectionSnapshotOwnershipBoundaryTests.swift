import AppKit
import XCTest
@testable import LiveSwitcher

@MainActor
final class RuntimeProjectionSnapshotOwnershipBoundaryTests: XCTestCase {
    func testProjectionOwnedToggleUsesRuntimeExternalDisplayAvailableWhenFacadeIsStaleFalse() {
        let viewModel = makeProjectionOwnedViewModel(
            runtimeProjection: projectionState(hasExternalDisplay: true),
            facadeHasExternalDisplay: false,
            providerHasExternalDisplay: false
        )

        viewModel.handleBroadcastToggle()

        XCTAssertTrue(viewModel.runtime.state.projection.isBroadcasting)
        XCTAssertTrue(viewModel.runtime.recordedEffects.contains(.startProjection))
    }

    func testProjectionOwnedToggleDoesNotFailClosedFromStaleFacadeUnavailable() {
        let viewModel = makeProjectionOwnedViewModel(
            runtimeProjection: projectionState(hasExternalDisplay: true),
            facadeHasExternalDisplay: false,
            providerHasExternalDisplay: false
        )

        viewModel.handleBroadcastToggle()

        XCTAssertNil(viewModel.runtime.state.projection.safetyNotice)
        XCTAssertFalse(viewModel.supportEvents.contains { $0.kind == .projectionStartFailed })
    }

    func testProjectionOwnedToggleCanStartWhenRuntimeHasExternalDisplayTrueAndFacadeFalse() {
        let viewModel = makeProjectionOwnedViewModel(
            runtimeProjection: projectionState(hasExternalDisplay: true),
            facadeHasExternalDisplay: false,
            providerHasExternalDisplay: false
        )

        viewModel.dispatchRuntimeFacadeAction(.operatorToggledProjection)

        XCTAssertTrue(viewModel.runtime.state.projection.isBroadcasting)
        XCTAssertTrue(viewModel.runtime.recordedEffects.contains(.startProjection))
    }

    func testProjectionOwnedToggleCanFailClosedWhenRuntimeHasExternalDisplayFalseAndFacadeTrue() {
        let viewModel = makeProjectionOwnedViewModel(
            runtimeProjection: projectionState(hasExternalDisplay: false),
            facadeHasExternalDisplay: true,
            providerHasExternalDisplay: true
        )

        viewModel.dispatchRuntimeFacadeAction(.operatorToggledProjection)

        XCTAssertFalse(viewModel.runtime.state.projection.isBroadcasting)
        XCTAssertFalse(viewModel.runtime.state.projection.hasExternalDisplay)
        XCTAssertEqual(viewModel.runtime.state.projection.safetyNotice, "未检测到外接屏幕，未开始投射")
        XCTAssertFalse(viewModel.runtime.recordedEffects.contains(.startProjection))
    }

    func testProjectionOwnedUnavailableCallbackStateIsNotRevertedByNextFacadeSync() {
        let viewModel = makeProjectionOwnedViewModel(
            runtimeProjection: projectionState(hasExternalDisplay: true, isBroadcasting: true),
            facadeHasExternalDisplay: true,
            providerHasExternalDisplay: true
        )

        viewModel.dispatchRuntimeFacadeAction(.projectionExternalDisplayUnavailable)
        viewModel.updateExternalDisplayAvailabilityForProjection(true)
        viewModel.syncRuntimeStateFromFacade(clearActionLog: false)

        XCTAssertFalse(viewModel.runtime.state.projection.hasExternalDisplay)
        XCTAssertFalse(viewModel.runtime.state.projection.isBroadcasting)
    }

    func testProjectionOwnedAvailableCallbackStateIsNotRevertedByNextFacadeSync() {
        let viewModel = makeProjectionOwnedViewModel(
            runtimeProjection: projectionState(hasExternalDisplay: false),
            facadeHasExternalDisplay: false,
            providerHasExternalDisplay: false
        )

        viewModel.dispatchRuntimeFacadeAction(.projectionExternalDisplayAvailable)
        viewModel.updateExternalDisplayAvailabilityForProjection(false)
        viewModel.syncRuntimeStateFromFacade(clearActionLog: false)

        XCTAssertTrue(viewModel.runtime.state.projection.hasExternalDisplay)
    }

    func testSyncProjectionIntoRuntimeSnapshotExists() throws {
        let source = try runtimeSnapshotSource()

        XCTAssertTrue(source.contains("syncProjectionIntoRuntimeSnapshot"))
    }

    func testOldSyncProjectionAvailabilityIntoRuntimeSnapshotIsRemoved() throws {
        let source = try runtimeSnapshotSource()

        XCTAssertFalse(source.contains("syncProjectionAvailabilityIntoRuntimeSnapshot"))
    }

    func testMakeRuntimeStateSnapshotDoesNotWriteProjectionAvailabilityBeforeOwnershipGuard() throws {
        let source = try runtimeSnapshotSource()
        let body = try XCTUnwrap(source.extractedRuntimeFunctionBody(named: "makeRuntimeStateSnapshot"))

        XCTAssertFalse(body.contains("state.projection.hasExternalDisplay = isExternalDisplayAvailable"))
        XCTAssertTrue(body.contains("syncProjectionIntoRuntimeSnapshot(&state)"))
    }

    func testNoProjectionSnapshotBridgeModeDomainOrPortAdded() {
        let forbidden = ["projectionSnapshotOwned", "projectionFacadeOwned", "externalDisplayOwned"]
        let bridgeModes = Set(LiveRuntimeBridgeMode.allCases.map(\.rawValue))
        let domains = Set(LiveRuntimeDomain.allCases.map(\.rawValue))
        let ports = Set(LiveRuntimeEffectPortKind.allCases.map(\.rawValue))

        for rawValue in forbidden {
            XCTAssertFalse(bridgeModes.contains(rawValue), rawValue)
            XCTAssertFalse(domains.contains(rawValue), rawValue)
            XCTAssertFalse(ports.contains(rawValue), rawValue)
        }
    }

    private func makeProjectionOwnedViewModel(
        runtimeProjection: ProjectionRuntimeState,
        facadeHasExternalDisplay: Bool,
        providerHasExternalDisplay: Bool
    ) -> SwitcherViewModel {
        let runtime = LiveRuntimeStore(
            effectRunner: .recording(),
            environment: LiveRuntimeEnvironment(bridgeMode: .projectionOwned)
        )
        let viewModel = SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            runtime: runtime
        )
        var state = viewModel.runtime.state
        state.projection = runtimeProjection
        viewModel.runtime.replaceStateForFacadeSync(state, clearActionLog: true)
        viewModel.updateExternalDisplayAvailabilityForProjection(facadeHasExternalDisplay)
        viewModel.externalScreenProvider = { providerHasExternalDisplay ? NSScreen.main : nil }
        return viewModel
    }

    private func projectionState(
        hasExternalDisplay: Bool,
        isBroadcasting: Bool = false
    ) -> ProjectionRuntimeState {
        var projection = ProjectionRuntimeState()
        projection.hasExternalDisplay = hasExternalDisplay
        projection.isBroadcasting = isBroadcasting
        return projection
    }

    private func runtimeSnapshotSource() throws -> String {
        try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+RuntimeSnapshot.swift")
    }
}
