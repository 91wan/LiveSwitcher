import XCTest
@testable import LiveSwitcher

@MainActor
final class LiveRuntimeEffectRunnerCallbackReadinessTests: XCTestCase {
    func testEffectRunnerDoesNotDiscardDispatchClosure() throws {
        let source = try runnerSource()

        XCTAssertFalse(source.contains("_ = dispatch"))
    }

    func testEffectRunnerCreatesExecutionContextWithDispatch() throws {
        let source = try runnerSource()

        XCTAssertTrue(source.contains("LiveRuntimeEffectExecutionContext("))
        XCTAssertTrue(source.contains("dispatch: dispatch"))
    }

    func testEffectRunnerCreatesExecutionContextWithCurrentState() throws {
        let source = try runnerSource()

        XCTAssertTrue(source.contains("currentState: currentState"))
    }

    func testEffectRunnerPrivateRunUsesExecutionContext() throws {
        let source = try runnerSource()

        XCTAssertTrue(source.contains("private func run(_ effect: LiveRuntimeEffect, context: LiveRuntimeEffectExecutionContext)"))
        XCTAssertTrue(source.contains("run($0, context: context)"))
        XCTAssertFalse(source.contains("run($0, currentState:"))
    }

    func testEffectRunnerStillRecordsRedactedEffectsBeforeExecution() {
        let automation = CallbackReadinessAutomationPortSpy()
        let runner = LiveRuntimeEffectRunner(recordsOnly: false, automation: automation)
        let rawScript = "tell application \"Keynote\" to open POSIX file \"/Users/operator/private.key\""

        runner.run(
            [.runAppleScript(script: rawScript, action: "keynote.open")],
            currentState: { LiveRuntimeState() },
            dispatch: { _ in XCTFail("Existing effects should not dispatch callback actions in this PR") }
        )

        XCTAssertEqual(runner.recordedEffects, [.runAppleScript(script: "<redacted>", action: "keynote.open")])
        XCTAssertEqual(automation.calls, ["keynote.open:\(rawScript)"])
    }

    func testEffectRunnerStillNoopsForRecordsOnlyAfterRecording() {
        let automation = CallbackReadinessAutomationPortSpy()
        let runner = LiveRuntimeEffectRunner(recordsOnly: true, automation: automation)

        runner.run(
            [.runAppleScript(script: "tell application \"Keynote\"", action: "keynote.next-slide")],
            currentState: { LiveRuntimeState() },
            dispatch: { _ in XCTFail("Records-only runner should not dispatch callback actions") }
        )

        XCTAssertEqual(runner.recordedEffects, [.runAppleScript(script: "<redacted>", action: "keynote.next-slide")])
        XCTAssertEqual(automation.calls, [])
    }

    func testEffectRunnerPortFieldsRemainPrivate() throws {
        let source = try runnerSource()

        XCTAssertTrue(source.contains("private let media"))
        XCTAssertTrue(source.contains("private let bgm"))
        XCTAssertTrue(source.contains("private let projection"))
        XCTAssertTrue(source.contains("private let persistence"))
    }

    func testEffectRunnerDidNotExposePortsAsInternalMutableState() throws {
        let source = try runnerSource()

        XCTAssertFalse(source.contains("var media: MediaPlaybackPort"))
        XCTAssertFalse(source.contains("var bgm: BGMPlaybackPort"))
        XCTAssertFalse(source.contains("var projection: ProjectionPort"))
        XCTAssertFalse(source.contains("var persistence: PersistencePort"))
    }

    private func runnerSource() throws -> String {
        try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeEffectRunner.swift"
        )
    }
}

private final class CallbackReadinessAutomationPortSpy: AutomationPort {
    private(set) var calls: [String] = []

    func run(script: String, action: String) {
        calls.append("\(action):\(script)")
    }
}
