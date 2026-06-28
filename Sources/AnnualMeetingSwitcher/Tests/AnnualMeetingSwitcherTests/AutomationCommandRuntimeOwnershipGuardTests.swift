import XCTest
@testable import LiveSwitcher

final class AutomationCommandRuntimeOwnershipGuardTests: XCTestCase {
    func testAutomationScriptRequestedNoopsBeforeAutomationCommandOwnership() {
        let mutation = reduce(.automationScriptRequested(script: privateScript, action: action), bridgeMode: .supportOwned)

        XCTAssertEqual(mutation.state, LiveRuntimeState())
        XCTAssertTrue(mutation.effects.isEmpty)
    }

    func testAutomationScriptRequestedEmitsRunAppleScriptWhenAutomationCommandOwned() {
        let mutation = reduce(.automationScriptRequested(script: privateScript, action: action), bridgeMode: .automationCommandOwned)

        XCTAssertEqual(mutation.effects, [.runAppleScript(script: privateScript, action: action)])
    }

    func testAutomationScriptRequestedDoesNotMutateState() {
        var state = LiveRuntimeState()
        state.support.record(kind: .appleScriptFailed, detail: "source=existing", at: Date(timeIntervalSince1970: 1))

        let mutation = reduce(state, .automationScriptRequested(script: privateScript, action: action), bridgeMode: .automationCommandOwned)

        XCTAssertEqual(mutation.state, state)
    }

    func testAllAutomationCommandCasesHaveExplicitAutomationCommandOwnershipGuard() throws {
        let source = try sourceText(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/Reducers/AutomationRuntimeActionDispatcher.swift"
        )
        let body = try caseBody(".automationScriptRequested(let script, let action)", in: source)

        XCTAssertTrue(
            body.contains("guard LiveRuntimeReducer.isRuntimeOwned(.automationCommand, in: bridgeMode) else { return true }")
        )
    }

    private func reduce(
        _ action: LiveRuntimeAction,
        bridgeMode: LiveRuntimeBridgeMode
    ) -> LiveRuntimeMutation {
        reduce(LiveRuntimeState(), action, bridgeMode: bridgeMode)
    }

    private func reduce(
        _ state: LiveRuntimeState,
        _ action: LiveRuntimeAction,
        bridgeMode: LiveRuntimeBridgeMode
    ) -> LiveRuntimeMutation {
        LiveRuntimeReducer.reduce(
            state: state,
            action: action,
            environment: LiveRuntimeEnvironment(now: Date(timeIntervalSince1970: 100), bridgeMode: bridgeMode)
        )
    }

    private func caseBody(_ casePattern: String, in source: String) throws -> String {
        guard let range = source.range(of: "case \(casePattern):") else {
            throw NSError(domain: "Missing case \(casePattern)", code: 1)
        }
        let nextCase = source[range.upperBound...].range(of: "\n        case ")
        let end = nextCase?.lowerBound ?? source.endIndex
        return String(source[range.lowerBound..<end])
    }

    private let privateScript = "tell application \"Keynote\" to open POSIX file \"/Users/operator/private-show.key\""
    private let action = "keynote.open.present"
}
