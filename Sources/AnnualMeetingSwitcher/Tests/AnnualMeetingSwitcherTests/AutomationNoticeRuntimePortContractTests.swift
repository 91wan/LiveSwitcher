import XCTest
@testable import LiveSwitcher

@MainActor
final class AutomationNoticeRuntimePortContractTests: XCTestCase {
    func testProductionRuntimeWiresAutomationNoticePort() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)

        XCTAssertTrue(viewModel.runtimeConnectedPortKinds.contains(.automationNotice))
    }

    func testProductionRuntimeWiresAutomationNoticeAndAutomationCommandExecution() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)

        XCTAssertTrue(viewModel.runtimeConnectedPortKinds.contains(.automationNotice))
        XCTAssertTrue(viewModel.runtimeConnectedPortKinds.contains(.automation))
        XCTAssertFalse(viewModel.runtimeBridgeMode.owns(.automation))
        XCTAssertTrue(viewModel.runtimeBridgeMode.owns(.automationCommand))
    }

    func testProductionRuntimeWiresAutomationCommandPort() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)

        XCTAssertTrue(viewModel.runtimeConnectedPortKinds.contains(.automation))
    }

    func testProductionRuntimeWiresSupportPortAfterSupportMigration() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)

        XCTAssertTrue(viewModel.runtimeConnectedPortKinds.contains(.support))
    }

    func testRunAppleScriptEffectRequiresAutomationCommandDomain() {
        XCTAssertEqual(
            LiveRuntimeEffect.runAppleScript(script: "tell app", action: "keynote.next-slide").requiredBridgeDomain,
            .automationCommand
        )
    }

    func testAutomationNoticeOwnedModeBlocksRunAppleScriptEffect() {
        let mutation = LiveRuntimeReducer.reduce(
            state: LiveRuntimeState(),
            action: .automationFailed(action: "keynote.next-slide", sanitizedMessage: "failed"),
            environment: LiveRuntimeEnvironment(bridgeMode: .automationNoticeOwned)
        )

        XCTAssertFalse(mutation.effects.contains { effect in
            if case .runAppleScript = effect { return true }
            return false
        })
    }

    func testAutomationNoticeOwnedModeAllowsShowAutomationNoticeEffect() {
        let mutation = LiveRuntimeReducer.reduce(
            state: LiveRuntimeState(),
            action: .automationNoticeRequested(action: "keynote.next-slide"),
            environment: LiveRuntimeEnvironment(bridgeMode: .automationNoticeOwned)
        )

        XCTAssertTrue(mutation.effects.contains { effect in
            if case .showAutomationNotice = effect { return true }
            return false
        })
    }

    func testAutomationNoticePortHasNoDefaultNoOpImplementation() throws {
        let source = try sourceText("Runtime/LiveRuntimePorts.swift")

        XCTAssertTrue(source.contains("protocol AutomationNoticePort"))
        XCTAssertFalse(source.contains("extension AutomationNoticePort"))
    }

    func testProductionClosureAutomationNoticePortImplementsShowAndExpire() throws {
        let source = try sourceText("Runtime/LiveRuntimeClosurePorts.swift")

        XCTAssertTrue(source.contains("final class ClosureAutomationNoticePort: AutomationNoticePort"))
        XCTAssertTrue(source.contains("func show(_ notice: AutomationRuntimeNotice)"))
        XCTAssertTrue(source.contains("func expire(id: UUID, at date: Date)"))
    }

    func testAutomationNoticePortShowDoesNotRecordSupportEvent() {
        let viewModel = makeViewModel()

        viewModel.dispatchRuntimeFacadeAction(.automationNoticeRequested(action: "keynote.next-slide"))

        XCTAssertTrue(viewModel.supportEvents.isEmpty)
        XCTAssertTrue(viewModel.runtime.state.support.events.isEmpty)
    }

    func testAutomationNoticePortExpireDoesNotRecordSupportEvent() throws {
        let viewModel = makeViewModel()

        viewModel.dispatchRuntimeFacadeAction(.automationNoticeRequested(action: "keynote.next-slide"))
        let notice = try XCTUnwrap(viewModel.automationRuntimeNotice)
        let expiresAt = try XCTUnwrap(notice.expiresAt)
        viewModel.expireAutomationRuntimeNotice(id: notice.id, now: expiresAt)

        XCTAssertTrue(viewModel.supportEvents.isEmpty)
        XCTAssertTrue(viewModel.runtime.state.support.events.isEmpty)
    }

    func testAutomationNoticePortDoesNotRunAppleScript() {
        let viewModel = makeViewModel()

        viewModel.dispatchRuntimeFacadeAction(.automationNoticeRequested(action: "keynote.next-slide"))

        XCTAssertFalse(viewModel.runtime.recordedEffects.contains { effect in
            if case .runAppleScript = effect { return true }
            return false
        })
    }

    private func makeViewModel() -> SwitcherViewModel {
        let suiteName = "AutomationNoticeRuntimePortContractTests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
        return SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            userDefaults: userDefaults
        )
    }

    private func sourceText(_ relativePath: String) throws -> String {
        try String(contentsOf: sourceURL(relativePath), encoding: .utf8)
    }

    private func sourceURL(_ relativePath: String) throws -> URL {
        var directory = URL(fileURLWithPath: #filePath)
        while directory.pathComponents.count > 1 {
            directory.deleteLastPathComponent()
            let candidate = directory
                .appendingPathComponent("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher")
                .appendingPathComponent(relativePath)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        throw XCTSkip("Could not locate \(relativePath) from test source path.")
    }
}
