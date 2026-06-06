import XCTest

final class AutomationQueryMigrationReadinessTests: XCTestCase {
    func testNoAutomationQueryOwnedBridgeModeYet() throws {
        let state = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeState.swift")

        XCTAssertFalse(state.contains("automationQueryOwned"))
    }

    func testNoAutomationQueryDomainYet() throws {
        let state = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeState.swift")

        XCTAssertFalse(state.contains("automationQuery"))
    }

    func testNoAutomationQueryPortYet() throws {
        let effect = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeEffect.swift")

        XCTAssertFalse(effect.contains("AutomationQueryPort"))
        XCTAssertFalse(effect.contains("scanKeynoteWindow"))
        XCTAssertFalse(effect.contains("scanOpenKeynoteFile"))
    }

    func testResultReturningQueriesRemainViewModelOwned() throws {
        let source = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+PresentationAutomation.swift"
        )

        XCTAssertTrue(source.contains("func scanAndAddKeynoteWindows()"))
        XCTAssertTrue(source.contains("presentationQueryService.scanKeynoteWindowNames()"))
        XCTAssertFalse(source.contains(".automationScriptRequested(script: \"keynote.scan"))
    }

    func testPresentationQueryServiceIsReadyForFutureRuntimePort() throws {
        let source = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Models/PresentationQueryService.swift"
        )

        XCTAssertTrue(source.contains("struct PresentationQueryService"))
        XCTAssertTrue(source.contains("var runAppleScript: (String, String) throws -> NSAppleEventDescriptor"))
        XCTAssertTrue(source.contains("var scanOpenKeynoteFiles: () -> [String]"))
    }
}
