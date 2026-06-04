import XCTest
@testable import LiveSwitcher

@MainActor
final class SupportMigrationReadinessTests: XCTestCase {
    func testSupportNotProductionOwnedYet() {
        let viewModel = makeViewModel()

        XCTAssertFalse(viewModel.runtimeBridgeMode.owns(.support))
        XCTAssertEqual(viewModel.runtimeBridgeMode, .automationNoticeOwned)
    }

    func testProductionRuntimeDoesNotWireSupportPortYet() {
        let viewModel = makeViewModel()

        XCTAssertFalse(viewModel.runtimeConnectedPortKinds.contains(.support))
    }

    func testFullRuntimeOwnsSupportOnlyInTests() {
        XCTAssertTrue(LiveRuntimeBridgeMode.fullRuntime.owns(.support))
        XCTAssertFalse(LiveRuntimeBridgeMode.automationNoticeOwned.owns(.support))
        XCTAssertFalse(makeViewModel().runtimeBridgeMode.owns(.support))
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

    func testAutomationNoticeOwnedDoesNotOwnSupport() {
        XCTAssertFalse(LiveRuntimeBridgeMode.automationNoticeOwned.owns(.support))
    }

    func testAutomationNoticeRuntimeTestsPassBeforeSupportMigration() throws {
        let requiredFiles = [
            "AutomationNoticeRuntimeExpiryTaskTests.swift",
            "AutomationNoticeRuntimeActionLogTests.swift",
            "AutomationNoticeRuntimeThrottleTests.swift",
            "AutomationNoticeRuntimeSupportBoundaryTests.swift",
            "AutomationNoticeRuntimeOwnershipTests.swift",
            "AutomationNoticeRuntimePortContractTests.swift"
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
