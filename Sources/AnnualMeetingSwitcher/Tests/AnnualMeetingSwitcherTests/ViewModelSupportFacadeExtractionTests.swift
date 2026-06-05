import XCTest
@testable import LiveSwitcher

@MainActor
final class ViewModelSupportFacadeExtractionTests: XCTestCase {
    func testSupportFacadeMethodIsNotDeclaredInMainViewModel() throws {
        let source = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel.swift")

        XCTAssertFalse(source.contains("func recordSupportEvent("))
    }

    func testSupportFacadeMethodLivesInSupportFacadeExtension() throws {
        let source = try XCTUnwrap(
            optionalRepositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+SupportFacade.swift")
        )

        XCTAssertTrue(source.contains("func recordSupportEvent("))
    }

    func testRecordSupportEventStillDispatchesRuntimeSupportEventRecorded() throws {
        let source = try supportFacadeSource()
        let body = try XCTUnwrap(source.extractedRuntimeFunctionBody(named: "recordSupportEvent"))

        XCTAssertTrue(body.contains("dispatchRuntimeFacadeAction(.supportEventRecorded(event))"))
    }

    func testRecordSupportEventStillSyncsSupportFacade() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)

        viewModel.recordSupportEvent(
            kind: .projectionStarted,
            detail: "source=support-facade-test",
            timestamp: Date(timeIntervalSince1970: 100)
        )

        XCTAssertEqual(viewModel.supportEvents, viewModel.runtime.state.support.events)
        XCTAssertEqual(viewModel.supportEvents.first?.kind, .projectionStarted)
    }

    func testSupportEventRecordedStillDoesNotPolluteActionLog() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)

        viewModel.recordSupportEvent(
            kind: .projectionStarted,
            detail: "source=support-facade-test",
            timestamp: Date(timeIntervalSince1970: 100)
        )

        XCTAssertFalse(viewModel.runtime.actionLog.contains { $0.actionName == "supportEventRecorded" })
    }

    private func supportFacadeSource() throws -> String {
        if let source = try optionalRepositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+SupportFacade.swift") {
            return source
        }
        return try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel.swift")
    }
}
