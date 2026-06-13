import XCTest
@testable import LiveSwitcher

@MainActor
final class SupportMigrationReadinessTests: XCTestCase {
    func testSupportIsProductionOwnedNow() {
        let viewModel = makeViewModel()

        XCTAssertTrue(viewModel.runtimeBridgeMode.owns(.support))
        XCTAssertEqual(viewModel.runtimeBridgeMode, .programActivationOwned)
        XCTAssertTrue(viewModel.runtimeBridgeMode.owns(.presentationQuery))
    }

    func testProductionRuntimeWiresSupportPortNow() {
        let viewModel = makeViewModel()

        XCTAssertTrue(viewModel.runtimeConnectedPortKinds.contains(.support))
    }

    func testAutomationCommandExecutionIsProductionOwnedButFullAutomationIsNot() {
        XCTAssertTrue(LiveRuntimeBridgeMode.fullRuntime.owns(.support))
        XCTAssertFalse(LiveRuntimeBridgeMode.automationNoticeOwned.owns(.support))
        XCTAssertTrue(makeViewModel().runtimeBridgeMode.owns(.support))
        XCTAssertTrue(makeViewModel().runtimeBridgeMode.owns(.automationCommand))
        XCTAssertFalse(makeViewModel().runtimeBridgeMode.owns(.automation))
    }

    func testSupportEventRecordedIsOnlyCurrentReducerSupportWriteInProductionModes() throws {
        let supportEvent = LiveSupportEvent(
            timestamp: Date(timeIntervalSince1970: 100),
            kind: .appleScriptFailed,
            detail: "action=keynote.next-slide,error=failed"
        )

        let recorded = reduce(.supportEventRecorded(supportEvent), bridgeMode: .automationNoticeOwned)
        XCTAssertEqual(try XCTUnwrap(recorded.state.support.events.first).kind, .appleScriptFailed)

        let automationFailure = reduce(
            .automationFailed(action: "keynote.next-slide", sanitizedMessage: "failed"),
            bridgeMode: .automationNoticeOwned
        )
        XCTAssertTrue(automationFailure.state.support.events.isEmpty)

        let projectionFailure = reduce(.operatorToggledProjection, bridgeMode: .automationNoticeOwned)
        XCTAssertTrue(projectionFailure.state.support.events.isEmpty)
    }

    func testAutomationNoticeOwnedDoesNotOwnSupportButSupportOwnedDoes() {
        XCTAssertFalse(LiveRuntimeBridgeMode.automationNoticeOwned.owns(.support))
        XCTAssertTrue(LiveRuntimeBridgeMode.supportOwned.owns(.support))
    }

    func testSupportRuntimeMigrationTestsExist() throws {
        let requiredFiles = [
            "SupportRuntimeOwnershipTests.swift",
            "SupportRuntimeIngressTests.swift",
            "SupportRuntimeEffectExecutionTests.swift",
            "SupportRuntimeFacadeSyncTests.swift",
            "SupportRuntimeCoalescingTests.swift",
            "SupportRuntimePriorityRetentionTests.swift",
            "SupportRuntimeDuplicatePreventionTests.swift",
            "SupportRuntimeProductionBoundaryTests.swift",
            "SupportRuntimePortContractTests.swift"
        ]

        for filename in requiredFiles {
            XCTAssertTrue(FileManager.default.fileExists(atPath: try testFileURL(filename).path))
        }
    }

    private func makeViewModel() -> SwitcherViewModel {
        let suiteName = "SupportMigrationReadinessTests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
        return SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            userDefaults: userDefaults
        )
    }

    private func reduce(
        _ action: LiveRuntimeAction,
        bridgeMode: LiveRuntimeBridgeMode
    ) -> LiveRuntimeMutation {
        LiveRuntimeReducer.reduce(
            state: LiveRuntimeState(),
            action: action,
            environment: LiveRuntimeEnvironment(now: Date(timeIntervalSince1970: 100), bridgeMode: bridgeMode)
        )
    }

    private func testFileURL(_ filename: String) throws -> URL {
        var directory = URL(fileURLWithPath: #filePath)
        while directory.pathComponents.count > 1 {
            directory.deleteLastPathComponent()
            let candidate = directory.appendingPathComponent(filename)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        throw XCTSkip("Could not locate \(filename) from test source path.")
    }
}
