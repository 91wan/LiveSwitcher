import XCTest
@testable import LiveSwitcher

final class AutomationNoticeRuntimeReducerExtractionTests: XCTestCase {
    func testAutomationNoticeRuntimeReducerFileExists() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/AutomationNoticeRuntimeReducer.swift")

        XCTAssertTrue(source.contains("enum AutomationNoticeRuntimeReducer"))
    }

    func testAutomationNoticeRuntimeReducerOwnsRequestLogic() throws {
        var state = LiveRuntimeState()
        var effects: [LiveRuntimeEffect] = []
        let now = Date(timeIntervalSince1970: 100)

        AutomationNoticeRuntimeReducer.request(
            action: "keynote.next-slide",
            state: &state,
            effects: &effects,
            now: now
        )

        let notice = try XCTUnwrap(state.automation.notice)
        XCTAssertEqual(notice.action, "keynote.next-slide")
        XCTAssertEqual(state.automation.suppressionUntilByAction["keynote.next-slide"], now.addingTimeInterval(15))
        XCTAssertTrue(effects.contains { effect in
            if case .showAutomationNotice(let emittedNotice) = effect {
                return emittedNotice == notice
            }
            return false
        })
    }

    func testAutomationNoticeRuntimeReducerOwnsExpireLogic() {
        var state = LiveRuntimeState()
        let notice = AutomationRuntimeNoticePolicy.make(action: "keynote.next-slide")
        state.automation.notice = notice

        AutomationNoticeRuntimeReducer.expire(id: notice.id, state: &state)

        XCTAssertNil(state.automation.notice)
    }

    func testAutomationNoticeRuntimeReducerOwnsDismissLogic() {
        var state = LiveRuntimeState()
        state.automation.notice = AutomationRuntimeNoticePolicy.make(action: "keynote.next-slide")

        AutomationNoticeRuntimeReducer.dismiss(state: &state)

        XCTAssertNil(state.automation.notice)
    }

    func testLiveRuntimeReducerDelegatesAutomationNoticeActionsAndDoesNotOwnMutationBodies() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeReducer.swift")

        XCTAssertTrue(source.contains("AutomationNoticeRuntimeReducer.request("))
        XCTAssertTrue(source.contains("AutomationNoticeRuntimeReducer.expire("))
        XCTAssertTrue(source.contains("AutomationNoticeRuntimeReducer.dismiss("))

        [
            "state.automation.notice =",
            "state.automation.suppressionUntilByAction =",
            "AutomationRuntimeNoticePolicy.make",
            "effects.append(.showAutomationNotice",
            "effects.append(.expireAutomationNotice",
            "private static func requestAutomationNotice"
        ].forEach { forbidden in
            XCTAssertFalse(source.contains(forbidden), "LiveRuntimeReducer still owns automation notice mutation body: \(forbidden)")
        }
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
