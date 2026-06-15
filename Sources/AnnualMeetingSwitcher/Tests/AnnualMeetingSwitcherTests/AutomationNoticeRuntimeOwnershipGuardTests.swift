import XCTest
@testable import LiveSwitcher

final class AutomationNoticeRuntimeOwnershipGuardTests: XCTestCase {
    func testAutomationFailedNoopsBeforeAutomationNoticeOwnership() {
        assertNoopBeforeOwnership(.automationFailed(action: "keynote.next-slide", sanitizedMessage: "failed"))
    }

    func testAutomationNoticeRequestedNoopsBeforeAutomationNoticeOwnership() {
        assertNoopBeforeOwnership(.automationNoticeRequested(action: "keynote.next-slide"))
    }

    func testAutomationNoticeExpiredNoopsBeforeAutomationNoticeOwnership() {
        let notice = AutomationRuntimeNoticePolicy.make(action: "keynote.next-slide")
        var state = guardedState()
        state.automation.notice = notice

        let mutation = reduce(state, .automationNoticeExpired(notice.id), environment: .productionPPTOwning(now: now))

        XCTAssertEqual(mutation.state.automation, state.automation)
        XCTAssertTrue(mutation.effects.isEmpty)
    }

    func testAutomationNoticeDismissedNoopsBeforeAutomationNoticeOwnership() {
        assertNoopBeforeOwnership(.automationNoticeDismissed)
    }

    func testAutomationFailedMutatesWhenAutomationNoticeOwned() throws {
        let mutation = reduce(
            LiveRuntimeState(),
            .automationFailed(action: "keynote.next-slide", sanitizedMessage: "failed"),
            environment: .productionAutomationNoticeOwning(now: now)
        )

        XCTAssertEqual(try XCTUnwrap(mutation.state.automation.notice).action, "keynote.next-slide")
        XCTAssertTrue(mutation.state.support.events.isEmpty)
    }

    func testAutomationNoticeRequestedMutatesWhenAutomationNoticeOwned() throws {
        let mutation = reduce(
            LiveRuntimeState(),
            .automationNoticeRequested(action: "keynote.next-slide"),
            environment: .productionAutomationNoticeOwning(now: now)
        )

        XCTAssertEqual(try XCTUnwrap(mutation.state.automation.notice).action, "keynote.next-slide")
    }

    func testAutomationNoticeExpiredMutatesWhenAutomationNoticeOwned() {
        let notice = AutomationRuntimeNoticePolicy.make(action: "keynote.next-slide")
        var state = LiveRuntimeState()
        state.automation.notice = notice

        let mutation = reduce(
            state,
            .automationNoticeExpired(notice.id),
            environment: .productionAutomationNoticeOwning(now: now)
        )

        XCTAssertNil(mutation.state.automation.notice)
    }

    func testAutomationNoticeDismissedMutatesWhenAutomationNoticeOwned() {
        var state = LiveRuntimeState()
        state.automation.notice = AutomationRuntimeNoticePolicy.make(action: "keynote.next-slide")

        let mutation = reduce(
            state,
            .automationNoticeDismissed,
            environment: .productionAutomationNoticeOwning(now: now)
        )

        XCTAssertNil(mutation.state.automation.notice)
    }

    func testAllAutomationNoticeCasesHaveExplicitAutomationNoticeOwnershipGuard() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeReducer.swift")

        [
            "case .automationFailed(let action, let sanitizedMessage):",
            "case .automationNoticeRequested(let action):",
            "case .automationNoticeExpired(let id):",
            "case .automationNoticeDismissed:"
        ].forEach { casePattern in
            guard let range = source.range(of: casePattern) else {
                XCTFail("Missing \(casePattern)")
                return
            }
            let endIndex = source.index(range.lowerBound, offsetBy: 420, limitedBy: source.endIndex) ?? source.endIndex
            let body = String(source[range.lowerBound..<endIndex])
            XCTAssertTrue(body.contains("guard isRuntimeOwned(.automationNotice, in: bridgeMode) else { break }"), "\(casePattern) lacks .automationNotice guard")
        }
    }

    private func assertNoopBeforeOwnership(_ action: LiveRuntimeAction) {
        let state = guardedState()
        let mutation = reduce(state, action, environment: .productionPPTOwning(now: now))

        XCTAssertEqual(mutation.state.automation, state.automation)
        XCTAssertEqual(mutation.state.support, state.support)
        XCTAssertTrue(mutation.effects.isEmpty)
    }

    private func guardedState() -> LiveRuntimeState {
        var state = LiveRuntimeState()
        state.automation.notice = AutomationRuntimeNoticePolicy.make(action: "existing.notice")
        state.automation.suppressionUntilByAction = ["existing.notice": now.addingTimeInterval(30)]
        return state
    }

    private func reduce(
        _ state: LiveRuntimeState,
        _ action: LiveRuntimeAction,
        environment: LiveRuntimeEnvironment
    ) -> LiveRuntimeMutation {
        LiveRuntimeReducer.reduce(state: state, action: action, environment: environment)
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

    private let now = Date(timeIntervalSince1970: 100)
}
