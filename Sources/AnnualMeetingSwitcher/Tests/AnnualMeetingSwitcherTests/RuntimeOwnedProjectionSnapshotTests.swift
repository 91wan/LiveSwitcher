import XCTest
@testable import LiveSwitcher

@MainActor
final class RuntimeOwnedProjectionSnapshotTests: XCTestCase {
    func testProjectionOwnedSnapshotPreservesRuntimeHasExternalDisplayTrue() {
        let viewModel = makeProjectionOwnedViewModel(
            runtimeProjection: projectionState(hasExternalDisplay: true),
            facadeHasExternalDisplay: false
        )

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false)

        XCTAssertTrue(viewModel.runtime.state.projection.hasExternalDisplay)
    }

    func testProjectionOwnedSnapshotPreservesRuntimeHasExternalDisplayFalse() {
        let viewModel = makeProjectionOwnedViewModel(
            runtimeProjection: projectionState(hasExternalDisplay: false),
            facadeHasExternalDisplay: true
        )

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false)

        XCTAssertFalse(viewModel.runtime.state.projection.hasExternalDisplay)
    }

    func testProjectionOwnedSnapshotPreservesRuntimeBroadcasting() {
        let viewModel = makeProjectionOwnedViewModel(
            runtimeProjection: projectionState(isBroadcasting: true),
            facadeIsBroadcasting: false
        )

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false)

        XCTAssertTrue(viewModel.runtime.state.projection.isBroadcasting)
    }

    func testProjectionOwnedSnapshotPreservesRuntimeSafetyNotice() {
        let notice = "runtime notice"
        let viewModel = makeProjectionOwnedViewModel(
            runtimeProjection: projectionState(safetyNotice: notice),
            facadeSafetyNotice: "facade notice"
        )

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false)

        XCTAssertEqual(viewModel.runtime.state.projection.safetyNotice, notice)
    }

    func testProjectionOwnedSnapshotPreservesRuntimeLastDisplayLostAt() {
        let lostAt = Date(timeIntervalSince1970: 123)
        let viewModel = makeProjectionOwnedViewModel(
            runtimeProjection: projectionState(lastDisplayLostAt: lostAt)
        )

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false)

        XCTAssertEqual(viewModel.runtime.state.projection.lastDisplayLostAt, lostAt)
    }

    func testProjectionOwnedSnapshotDoesNotOverwriteRuntimeProjectionWithStaleFacadeAvailabilityFalse() {
        let viewModel = makeProjectionOwnedViewModel(
            runtimeProjection: projectionState(hasExternalDisplay: true, isBroadcasting: true),
            facadeHasExternalDisplay: false,
            facadeIsBroadcasting: false,
            facadeSafetyNotice: "facade stale"
        )

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false)

        XCTAssertTrue(viewModel.runtime.state.projection.hasExternalDisplay)
        XCTAssertTrue(viewModel.runtime.state.projection.isBroadcasting)
        XCTAssertNil(viewModel.runtime.state.projection.safetyNotice)
    }

    func testProjectionOwnedSnapshotDoesNotOverwriteRuntimeProjectionWithStaleFacadeAvailabilityTrue() {
        let notice = "runtime unavailable"
        let viewModel = makeProjectionOwnedViewModel(
            runtimeProjection: projectionState(hasExternalDisplay: false, safetyNotice: notice),
            facadeHasExternalDisplay: true,
            facadeIsBroadcasting: true,
            facadeSafetyNotice: nil
        )

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false)

        XCTAssertFalse(viewModel.runtime.state.projection.hasExternalDisplay)
        XCTAssertFalse(viewModel.runtime.state.projection.isBroadcasting)
        XCTAssertEqual(viewModel.runtime.state.projection.safetyNotice, notice)
    }

    func testNonProjectionOwnedSnapshotUsesFacadeExternalDisplayAvailability() {
        let viewModel = makeViewModel(
            bridgeMode: .bgmOwned,
            runtimeProjection: projectionState(hasExternalDisplay: false),
            facadeHasExternalDisplay: true
        )

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false)

        XCTAssertTrue(viewModel.runtime.state.projection.hasExternalDisplay)
    }

    func testNonProjectionOwnedSnapshotUsesFacadeBroadcasting() {
        let viewModel = makeViewModel(
            bridgeMode: .bgmOwned,
            runtimeProjection: projectionState(isBroadcasting: false),
            facadeIsBroadcasting: true
        )

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false)

        XCTAssertTrue(viewModel.runtime.state.projection.isBroadcasting)
    }

    func testNonProjectionOwnedSnapshotUsesFacadeSafetyNotice() {
        let notice = "facade notice"
        let viewModel = makeViewModel(
            bridgeMode: .bgmOwned,
            runtimeProjection: projectionState(safetyNotice: "runtime notice"),
            facadeSafetyNotice: notice
        )

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false)

        XCTAssertEqual(viewModel.runtime.state.projection.safetyNotice, notice)
    }

    private func makeProjectionOwnedViewModel(
        runtimeProjection: ProjectionRuntimeState,
        facadeHasExternalDisplay: Bool = false,
        facadeIsBroadcasting: Bool = false,
        facadeSafetyNotice: String? = nil
    ) -> SwitcherViewModel {
        makeViewModel(
            bridgeMode: .projectionOwned,
            runtimeProjection: runtimeProjection,
            facadeHasExternalDisplay: facadeHasExternalDisplay,
            facadeIsBroadcasting: facadeIsBroadcasting,
            facadeSafetyNotice: facadeSafetyNotice
        )
    }

    private func makeViewModel(
        bridgeMode: LiveRuntimeBridgeMode,
        runtimeProjection: ProjectionRuntimeState,
        facadeHasExternalDisplay: Bool = false,
        facadeIsBroadcasting: Bool = false,
        facadeSafetyNotice: String? = nil
    ) -> SwitcherViewModel {
        let runtime = LiveRuntimeStore(
            effectRunner: .recording(),
            environment: LiveRuntimeEnvironment(bridgeMode: bridgeMode)
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
        viewModel.isBroadcasting = facadeIsBroadcasting
        viewModel.broadcastSafetyNotice = facadeSafetyNotice
        return viewModel
    }

    private func projectionState(
        hasExternalDisplay: Bool = false,
        isBroadcasting: Bool = false,
        safetyNotice: String? = nil,
        lastDisplayLostAt: Date? = nil
    ) -> ProjectionRuntimeState {
        var projection = ProjectionRuntimeState()
        projection.hasExternalDisplay = hasExternalDisplay
        projection.isBroadcasting = isBroadcasting
        projection.safetyNotice = safetyNotice
        projection.lastDisplayLostAt = lastDisplayLostAt
        return projection
    }
}
