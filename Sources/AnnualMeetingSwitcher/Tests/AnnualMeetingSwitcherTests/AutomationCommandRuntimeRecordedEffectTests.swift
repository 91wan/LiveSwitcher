import XCTest
@testable import LiveSwitcher

@MainActor
final class AutomationCommandRuntimeRecordedEffectTests: XCTestCase {
    func testRecordedRunAppleScriptEffectRedactsScriptSource() {
        let runtime = automationCommandRuntime()

        runtime.dispatch(.automationScriptRequested(script: privateScript, action: "keynote.open.present"))

        XCTAssertEqual(runtime.recordedEffects, [.runAppleScript(script: "<redacted>", action: "keynote.open.present")])
    }

    func testRecordedRunAppleScriptEffectKeepsActionName() {
        let runtime = automationCommandRuntime()

        runtime.dispatch(.automationScriptRequested(script: privateScript, action: "keynote.open.present"))

        XCTAssertTrue(runtime.recordedEffects.contains(.runAppleScript(script: "<redacted>", action: "keynote.open.present")))
    }

    func testRecordedRunAppleScriptEffectDoesNotContainFilePath() {
        let runtime = automationCommandRuntime()

        runtime.dispatch(.automationScriptRequested(script: privateScript, action: "keynote.open.present"))

        XCTAssertFalse(renderedRecordedEffects(runtime).localizedStandardContains("/Users/operator/private-show.key"))
        XCTAssertFalse(renderedRecordedEffects(runtime).localizedStandardContains("private-show.key"))
    }

    func testAutomationPortStillReceivesRawScriptForExecution() {
        let automation = AutomationCommandRecordedEffectPortSpy()
        let runner = LiveRuntimeEffectRunner(recordsOnly: false, automation: automation)
        let runtime = LiveRuntimeStore(
            effectRunner: runner,
            environment: .productionAutomationCommandOwning(now: Date(timeIntervalSince1970: 100))
        )

        runtime.dispatch(.automationScriptRequested(script: privateScript, action: "keynote.open.present"))

        XCTAssertEqual(automation.scripts, [privateScript])
        XCTAssertFalse(renderedRecordedEffects(runtime).localizedStandardContains(privateScript))
    }

    func testNonAutomationEffectsAreRecordedNormally() {
        let runner = LiveRuntimeEffectRunner.recording()
        let effect = LiveRuntimeEffect.saveConsoleMode(.live)

        runner.run([effect], currentState: { LiveRuntimeState() }, dispatch: { _ in })

        XCTAssertEqual(runner.recordedEffects, [effect])
    }

    func testRuntimeRecordedEffectsDoNotContainTellApplication() {
        let runtime = automationCommandRuntime()

        runtime.dispatch(.automationScriptRequested(script: privateScript, action: "keynote.open.present"))

        XCTAssertFalse(renderedRecordedEffects(runtime).localizedStandardContains("tell application"))
    }

    private var privateScript: String {
        "tell application \"Keynote\" to open POSIX file \"/Users/operator/private-show.key\""
    }

    private func automationCommandRuntime() -> LiveRuntimeStore {
        LiveRuntimeStore(
            effectRunner: .recording(),
            environment: .productionAutomationCommandOwning(now: Date(timeIntervalSince1970: 100))
        )
    }

    private func renderedRecordedEffects(_ runtime: LiveRuntimeStore) -> String {
        String(describing: runtime.recordedEffects)
    }
}

private final class AutomationCommandRecordedEffectPortSpy: AutomationPort {
    private(set) var scripts: [String] = []

    func run(script: String, action: String) {
        scripts.append(script)
    }
}
