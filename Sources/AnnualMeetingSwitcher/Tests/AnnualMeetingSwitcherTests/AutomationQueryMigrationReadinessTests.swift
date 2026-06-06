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

    func testNoPresentationQueryEffectsYet() throws {
        let effect = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeEffect.swift")

        XCTAssertFalse(effect.contains("scanPresentationQuery"))
        XCTAssertFalse(effect.contains("presentationQuery"))
    }

    func testNoPresentationQueryCallbackActionsYet() throws {
        let action = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeAction.swift")

        XCTAssertFalse(action.contains("presentationQueryCompleted"))
        XCTAssertFalse(action.contains("presentationQueryFailed"))
    }

    func testResultReturningQueriesRemainViewModelOwned() throws {
        let source = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+PresentationAutomation.swift"
        )

        XCTAssertTrue(source.contains("func scanAndAddKeynoteWindows()"))
        XCTAssertTrue(source.contains("presentationQueryService.scanPresentationQuery()"))
        XCTAssertFalse(source.contains(".automationScriptRequested(script: \"keynote.scan"))
    }

    func testPresentationQueryServiceIsReadyForFutureRuntimePort() throws {
        let source = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Models/PresentationQueryService.swift"
        )

        XCTAssertTrue(source.contains("struct PresentationQueryService"))
        XCTAssertTrue(source.contains("var runAppleScript: (String, String) throws -> NSAppleEventDescriptor"))
        XCTAssertTrue(source.contains("var queryOpenKeynoteFiles: () -> [String]"))
    }

    func testPresentationQueryServiceHasNoKeynoteControllerDependency() throws {
        let source = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Models/PresentationQueryService.swift"
        )

        XCTAssertFalse(source.contains("KeynoteController"))
        XCTAssertFalse(source.contains("init(keynoteController:"))
    }

    func testPresentationQueryResultBuilderHasNoKeynoteControllerDependency() throws {
        let source = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Models/PresentationQueryResultBuilder.swift"
        )

        XCTAssertFalse(source.contains("KeynoteController"))
    }

    func testPresentationQueryServiceRemainsViewModelOwned() throws {
        let source = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+PresentationAutomation.swift"
        )

        XCTAssertTrue(source.contains("presentationQueryService.scanPresentationQuery()"))
        XCTAssertFalse(source.contains("dispatchRuntimeFacadeAction(.presentationQuery"))
    }

    func testInfrastructureDomainHardeningDidNotIntroduceQueryOwnership() throws {
        let state = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeState.swift")
        let effect = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeEffect.swift")

        XCTAssertTrue(state.contains("case imageAssets"))
        XCTAssertTrue(state.contains("case persistence"))
        XCTAssertFalse(state.contains("automationQuery"))
        XCTAssertFalse(effect.contains("AutomationQueryPort"))
    }
}
