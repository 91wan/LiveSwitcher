import XCTest
@testable import LiveSwitcher

@MainActor
final class AutomationCommandRuntimeFailureTests: XCTestCase {
    func testAutomationPortFailureRecordsAppleScriptFailedSupport() async throws {
        let viewModel = makeFailingViewModel()
        let finished = makeCompletionExpectation(on: viewModel)

        viewModel.dispatchRuntimeFacadeAction(
            .automationScriptRequested(script: privateScript, action: "keynote.next-slide")
        )
        await fulfillment(of: [finished], timeout: 1)

        XCTAssertTrue(viewModel.supportEvents.contains { $0.kind == .appleScriptFailed })
    }

    func testAutomationPortFailureCreatesAutomationNotice() async throws {
        let viewModel = makeFailingViewModel()
        let finished = makeCompletionExpectation(on: viewModel)

        viewModel.dispatchRuntimeFacadeAction(
            .automationScriptRequested(script: privateScript, action: "keynote.next-slide")
        )
        await fulfillment(of: [finished], timeout: 1)

        XCTAssertEqual(viewModel.automationRuntimeNotice?.action, "keynote.next-slide")
    }

    func testAutomationPortFailureCoalescesRepeatedSupportEvents() async throws {
        let viewModel = makeFailingViewModel()
        let finished = makeCompletionExpectation(on: viewModel, expectedFulfillmentCount: 2)

        viewModel.dispatchRuntimeFacadeAction(
            .automationScriptRequested(script: privateScript, action: "keynote.next-slide")
        )
        viewModel.dispatchRuntimeFacadeAction(
            .automationScriptRequested(script: privateScript, action: "keynote.next-slide")
        )
        await fulfillment(of: [finished], timeout: 1)

        let events = viewModel.supportEvents.filter { $0.kind == .appleScriptFailed }
        XCTAssertEqual(events.count, 1)
        XCTAssertTrue(events.first?.detail.contains("count=2") == true)
    }

    func testAutomationPortFailureSuppressesRepeatedVisibleNotice() async throws {
        let viewModel = makeFailingViewModel()
        let firstFinished = makeCompletionExpectation(on: viewModel)

        viewModel.dispatchRuntimeFacadeAction(
            .automationScriptRequested(script: privateScript, action: "keynote.next-slide")
        )
        await fulfillment(of: [firstFinished], timeout: 1)
        let firstNotice = viewModel.automationRuntimeNotice
        let secondFinished = makeCompletionExpectation(on: viewModel)
        viewModel.dispatchRuntimeFacadeAction(
            .automationScriptRequested(script: privateScript, action: "keynote.next-slide")
        )
        await fulfillment(of: [secondFinished], timeout: 1)

        XCTAssertEqual(viewModel.automationRuntimeNotice, firstNotice)
    }

    func testAutomationPortFailureDoesNotExposeRawScriptInSupport() async throws {
        let viewModel = makeFailingViewModel()
        let finished = makeCompletionExpectation(on: viewModel)

        viewModel.dispatchRuntimeFacadeAction(
            .automationScriptRequested(script: privateScript, action: "keynote.next-slide")
        )
        await fulfillment(of: [finished], timeout: 1)

        let renderedSupport = viewModel.supportEvents.map(\.detail).joined(separator: "\n")
        XCTAssertFalse(renderedSupport.localizedStandardContains("/Users/operator/private-show.key"))
        XCTAssertFalse(renderedSupport.localizedStandardContains("tell application"))
    }

    func testAutomationPortFailureDoesNotExposeRawScriptInNotice() async throws {
        let viewModel = makeFailingViewModel()
        let finished = makeCompletionExpectation(on: viewModel)

        viewModel.dispatchRuntimeFacadeAction(
            .automationScriptRequested(script: privateScript, action: "keynote.next-slide")
        )
        await fulfillment(of: [finished], timeout: 1)

        let notice = try XCTUnwrap(viewModel.automationRuntimeNotice)
        XCTAssertFalse(notice.title.localizedStandardContains("/Users/operator/private-show.key"))
        XCTAssertFalse(notice.message.localizedStandardContains("/Users/operator/private-show.key"))
        XCTAssertFalse(notice.title.localizedStandardContains("tell application"))
        XCTAssertFalse(notice.message.localizedStandardContains("tell application"))
    }

    func testAutomationFailedReducerDoesNotWriteSupportInAutomationCommandOwned() {
        let mutation = LiveRuntimeReducer.reduce(
            state: LiveRuntimeState(),
            action: .automationFailed(action: "keynote.next-slide", sanitizedMessage: "failed"),
            environment: .productionAutomationCommandOwning(now: Date(timeIntervalSince1970: 100))
        )

        XCTAssertTrue(mutation.state.support.events.isEmpty)
    }

    private var privateScript: String {
        "tell application \"Keynote\" to open POSIX file \"/Users/operator/private-show.key\""
    }

    private func makeFailingViewModel() -> SwitcherViewModel {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)
        viewModel.testHooks.automationCommandRunner = { _, action in
            throw AppleScriptError.executionFailed(
                action: action,
                message: "/Users/operator/private-show.key failed"
            )
        }
        return viewModel
    }

    private func makeCompletionExpectation(
        on viewModel: SwitcherViewModel,
        expectedFulfillmentCount: Int = 1
    ) -> XCTestExpectation {
        let finished = expectation(description: "automation command finished")
        finished.expectedFulfillmentCount = expectedFulfillmentCount
        viewModel.testHooks.automationCommandDidFinish = { finished.fulfill() }
        return finished
    }
}
