import XCTest
@testable import LiveSwitcher

@MainActor
final class AutomationCommandRuntimeActionLogTests: XCTestCase {
    func testAutomationScriptRequestedIsLoggedByRedactedName() {
        let runtime = automationCommandRuntime()

        runtime.dispatch(.automationScriptRequested(script: "tell application \"Keynote\"", action: "keynote.next-slide"))

        XCTAssertTrue(runtime.actionLog.contains { $0.actionName == "automationScriptRequested" })
    }

    func testAutomationScriptRequestedActionLogDoesNotContainScriptSource() {
        let runtime = automationCommandRuntime()
        let script = "tell application \"Keynote\" to open POSIX file \"/Users/operator/private-show.key\""

        runtime.dispatch(.automationScriptRequested(script: script, action: "keynote.open.present"))

        let entry = runtime.actionLog.last
        XCTAssertFalse(entry?.actionName.localizedStandardContains("tell application") == true)
        XCTAssertFalse(entry?.oldStateSummary.localizedStandardContains("tell application") == true)
        XCTAssertFalse(entry?.newStateSummary.localizedStandardContains("tell application") == true)
    }

    func testAutomationScriptRequestedActionLogDoesNotContainFilePath() {
        let runtime = automationCommandRuntime()

        runtime.dispatch(
            .automationScriptRequested(
                script: "tell application \"Keynote\" to open POSIX file \"/Users/operator/private-show.key\"",
                action: "keynote.open.present"
            )
        )

        let renderedLog = runtime.actionLog.map {
            "\($0.actionName)|\($0.oldStateSummary)|\($0.newStateSummary)"
        }.joined(separator: "\n")
        XCTAssertFalse(renderedLog.localizedStandardContains("/Users/operator/private-show.key"))
    }

    func testAutomationFailureIsLoggedSeparately() {
        let runtime = automationCommandRuntime()

        runtime.dispatch(.automationScriptRequested(script: "tell application \"Keynote\"", action: "keynote.next-slide"))
        runtime.dispatch(.automationFailed(action: "keynote.next-slide", sanitizedMessage: "failed"))

        XCTAssertTrue(runtime.actionLog.contains { $0.actionName == "automationScriptRequested" })
        XCTAssertTrue(runtime.actionLog.contains { $0.actionName == "automationFailed" })
    }

    func testSupportEventRecordedStillDoesNotPolluteActionLog() {
        let runtime = automationCommandRuntime()

        runtime.dispatch(.supportEventRecorded(LiveSupportEvent(
            timestamp: Date(timeIntervalSince1970: 100),
            kind: .appleScriptFailed,
            detail: "action=keynote.next-slide,error=failed"
        )))

        XCTAssertFalse(runtime.actionLog.contains { $0.actionName == "supportEventRecorded" })
    }

    private func automationCommandRuntime() -> LiveRuntimeStore {
        LiveRuntimeStore(
            effectRunner: .recording(),
            environment: .productionAutomationCommandOwning(now: Date(timeIntervalSince1970: 100))
        )
    }
}
