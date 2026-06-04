import XCTest
@testable import LiveSwitcher

@MainActor
final class AutomationNoticeRuntimeEffectExecutionTests: XCTestCase {
    func testShowAutomationNoticeEffectCallsAutomationNoticePort() {
        let port = AutomationNoticePortSpy()
        let runner = LiveRuntimeEffectRunner(recordsOnly: false, automationNotice: port)
        let notice = AutomationRuntimeNoticePolicy.make(action: "keynote.next-slide")

        runner.run([.showAutomationNotice(notice)], currentState: { LiveRuntimeState() }, dispatch: { _ in })

        XCTAssertEqual(port.calls, ["show:keynote.next-slide"])
    }

    func testExpireAutomationNoticeEffectCallsAutomationNoticePort() {
        let port = AutomationNoticePortSpy()
        let runner = LiveRuntimeEffectRunner(recordsOnly: false, automationNotice: port)
        let id = UUID()
        let expiresAt = Date(timeIntervalSince1970: 123)

        runner.run([.expireAutomationNotice(id, at: expiresAt)], currentState: { LiveRuntimeState() }, dispatch: { _ in })

        XCTAssertEqual(port.calls, ["expire:\(id.uuidString):123.0"])
    }

    func testAutomationNoticePortShowUpdatesViewModelFacade() throws {
        let viewModel = makeViewModel()

        viewModel.dispatchRuntimeFacadeAction(.automationNoticeRequested(action: "keynote.next-slide"))

        XCTAssertEqual(try XCTUnwrap(viewModel.automationRuntimeNotice).action, "keynote.next-slide")
    }

    func testAutomationNoticePortExpireDispatchesRuntimeExpiry() throws {
        let source = try sourceText("ViewModel.swift")

        XCTAssertTrue(source.contains("automationNoticePort.expireHandler"))
        XCTAssertTrue(source.contains("dispatchRuntimeFacadeAction(.automationNoticeExpired(id))"))
        XCTAssertFalse(source.contains("automationNoticePort.expireHandler = { id, date in\n            Thread.sleep"))
    }

    func testAutomationNoticePortDoesNotRecordSupportEvent() throws {
        let viewModel = makeViewModel()

        viewModel.dispatchRuntimeFacadeAction(.automationNoticeRequested(action: "keynote.next-slide"))

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
        let suiteName = "AutomationNoticeRuntimeEffectExecutionTests.\(UUID().uuidString)"
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

private final class AutomationNoticePortSpy: AutomationNoticePort {
    private(set) var calls: [String] = []

    func show(_ notice: AutomationRuntimeNotice) {
        calls.append("show:\(notice.action)")
    }

    func expire(id: UUID, at date: Date) {
        calls.append("expire:\(id.uuidString):\(date.timeIntervalSince1970)")
    }
}
