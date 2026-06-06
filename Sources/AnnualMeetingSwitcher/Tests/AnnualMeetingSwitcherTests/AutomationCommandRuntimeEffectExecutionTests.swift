import XCTest
@testable import LiveSwitcher

@MainActor
final class AutomationCommandRuntimeEffectExecutionTests: XCTestCase {
    func testRunAppleScriptEffectCallsAutomationPort() {
        let automation = AutomationCommandPortSpy()
        let runner = LiveRuntimeEffectRunner(recordsOnly: false, automation: automation)

        runner.run(
            [.runAppleScript(script: "tell application \"Keynote\"", action: "keynote.next-slide")],
            currentState: { LiveRuntimeState() },
            dispatch: { _ in }
        )

        XCTAssertEqual(
            automation.runs,
            [AutomationCommandRun(script: "tell application \"Keynote\"", action: "keynote.next-slide")]
        )
    }

    func testProductionRuntimeWiresAutomationPort() {
        let viewModel = makeViewModel()

        XCTAssertEqual(viewModel.runtimeBridgeMode, .presentationQueryOwned)
        XCTAssertTrue(viewModel.runtimeConnectedPortKinds.contains(.automation))
    }

    func testAutomationPortFailureCallsHandleAppleScriptFailure() async throws {
        let viewModel = makeViewModel()
        let finished = expectation(description: "automation command finished")
        viewModel.testHooks.automationCommandDidFinish = { finished.fulfill() }
        viewModel.testHooks.automationCommandRunner = { _, _ in
            throw AppleScriptError.executionFailed(action: "keynote.next-slide", message: "failed")
        }

        viewModel.dispatchRuntimeFacadeAction(
            .automationScriptRequested(script: "tell application \"Keynote\"", action: "keynote.next-slide")
        )
        await fulfillment(of: [finished], timeout: 1)

        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "automationFailed" })
    }

    func testAutomationPortFailureRecordsSupportThroughViewModel() async throws {
        let viewModel = makeViewModel()
        let finished = expectation(description: "automation command finished")
        viewModel.testHooks.automationCommandDidFinish = { finished.fulfill() }
        viewModel.testHooks.automationCommandRunner = { _, _ in
            throw AppleScriptError.executionFailed(action: "keynote.next-slide", message: "failed")
        }

        viewModel.dispatchRuntimeFacadeAction(
            .automationScriptRequested(script: "tell application \"Keynote\"", action: "keynote.next-slide")
        )
        await fulfillment(of: [finished], timeout: 1)

        XCTAssertTrue(viewModel.supportEvents.contains { $0.kind == .appleScriptFailed })
    }

    func testAutomationPortFailureDispatchesAutomationFailedNotice() async throws {
        let viewModel = makeViewModel()
        let finished = expectation(description: "automation command finished")
        viewModel.testHooks.automationCommandDidFinish = { finished.fulfill() }
        viewModel.testHooks.automationCommandRunner = { _, _ in
            throw AppleScriptError.executionFailed(action: "keynote.next-slide", message: "failed")
        }

        viewModel.dispatchRuntimeFacadeAction(
            .automationScriptRequested(script: "tell application \"Keynote\"", action: "keynote.next-slide")
        )
        await fulfillment(of: [finished], timeout: 1)

        XCTAssertEqual(viewModel.automationRuntimeNotice?.action, "keynote.next-slide")
    }

    func testAutomationPortDoesNotRecordSupportOnSuccess() async throws {
        let viewModel = makeViewModel()
        let finished = expectation(description: "automation command finished")
        viewModel.testHooks.automationCommandDidFinish = { finished.fulfill() }
        viewModel.testHooks.automationCommandRunner = { _, _ in }

        viewModel.dispatchRuntimeFacadeAction(
            .automationScriptRequested(script: "tell application \"Keynote\"", action: "keynote.next-slide")
        )
        await fulfillment(of: [finished], timeout: 1)

        XCTAssertTrue(viewModel.supportEvents.isEmpty)
        XCTAssertNil(viewModel.automationRuntimeNotice)
    }

    func testAutomationPortFailureUsesDeterministicCompletionHook() async {
        let viewModel = makeViewModel()
        let finished = expectation(description: "automation command finished")
        viewModel.testHooks.automationCommandDidFinish = { finished.fulfill() }
        viewModel.testHooks.automationCommandRunner = { _, _ in
            throw AppleScriptError.executionFailed(action: "keynote.next-slide", message: "failed")
        }

        viewModel.dispatchRuntimeFacadeAction(
            .automationScriptRequested(script: "tell application \"Keynote\"", action: "keynote.next-slide")
        )

        await fulfillment(of: [finished], timeout: 1)
    }

    func testAutomationPortSuccessUsesDeterministicCompletionHook() async {
        let viewModel = makeViewModel()
        let finished = expectation(description: "automation command finished")
        viewModel.testHooks.automationCommandDidFinish = { finished.fulfill() }
        viewModel.testHooks.automationCommandRunner = { _, _ in }

        viewModel.dispatchRuntimeFacadeAction(
            .automationScriptRequested(script: "tell application \"Keynote\"", action: "keynote.next-slide")
        )

        await fulfillment(of: [finished], timeout: 1)
    }

    private func makeViewModel() -> SwitcherViewModel {
        SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)
    }
}

private struct AutomationCommandRun: Equatable {
    var script: String
    var action: String
}

private final class AutomationCommandPortSpy: AutomationPort {
    private(set) var runs: [AutomationCommandRun] = []

    func run(script: String, action: String) {
        runs.append(AutomationCommandRun(script: script, action: action))
    }
}
