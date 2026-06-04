import XCTest
@testable import LiveSwitcher

@MainActor
final class RuntimeProjectionMigrationReadinessTests: XCTestCase {
    func testProjectionIsStillProductionOwnedThroughPPTOwningMode() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)

        XCTAssertEqual(viewModel.runtimeBridgeMode, .pptOwned)
        XCTAssertTrue(viewModel.runtimeBridgeMode.owns(.projection))
    }

    func testProductionRuntimeWiresProjectionPortNow() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)

        XCTAssertTrue(viewModel.runtimeConnectedPortKinds.contains(.projection))
    }

    func testProjectionOwnedModeIncludesAudioMediaBGMProjection() {
        XCTAssertEqual(
            LiveRuntimeBridgeMode.projectionOwned.ownedDomains,
            [.audio, .media, .bgm, .projection]
        )
    }

    func testProjectionOwnedModeDoesNotOwnPPTAutomationSupport() {
        let mode = LiveRuntimeBridgeMode.projectionOwned

        XCTAssertFalse(mode.owns(.ppt))
        XCTAssertFalse(mode.owns(.automation))
        XCTAssertFalse(mode.owns(.support))
    }

    func testProjectionEffectsRequireProjectionDomain() {
        XCTAssertEqual(LiveRuntimeEffect.startProjection.requiredBridgeDomain, .projection)
        XCTAssertEqual(LiveRuntimeEffect.stopProjection.requiredBridgeDomain, .projection)
        XCTAssertEqual(LiveRuntimeEffect.showOutputWindow.requiredBridgeDomain, .projection)
        XCTAssertEqual(LiveRuntimeEffect.hideOutputWindow.requiredBridgeDomain, .projection)
    }

    func testProductionBridgeModeMustBeExplicitAfterPPTMigration() throws {
        let storeSource = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeStore.swift")
        let viewModelSource = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel.swift")

        XCTAssertFalse(storeSource.contains("defaultEnvironment(for:"))
        XCTAssertFalse(storeSource.contains("connectedPortKinds.contains(.persistence)"))
        XCTAssertTrue(viewModelSource.contains("environment: .productionPPTOwning()"))
    }

    private func sourceText(_ relativePath: String) throws -> String {
        try String(contentsOf: repositoryRoot().appendingPathComponent(relativePath), encoding: .utf8)
    }

    private func repositoryRoot() throws -> URL {
        var directory = URL(fileURLWithPath: #filePath)
        while directory.pathComponents.count > 1 {
            directory.deleteLastPathComponent()
            if FileManager.default.fileExists(atPath: directory.appendingPathComponent("docs").path) {
                return directory
            }
        }
        throw XCTSkip("Could not locate repository root from test source path.")
    }
}
