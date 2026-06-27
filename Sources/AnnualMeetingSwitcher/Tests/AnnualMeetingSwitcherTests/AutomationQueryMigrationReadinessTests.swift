import XCTest

final class AutomationQueryMigrationReadinessTests: XCTestCase {
    func testRuntimeEffectRunnerCarriesDispatchForFutureQueryCallbacks() throws {
        let runner = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeEffectRunner.swift"
        )
        let context = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeEffectExecutionContext.swift"
        )

        XCTAssertTrue(runner.contains("LiveRuntimeEffectExecutionContext("))
        XCTAssertTrue(runner.contains("dispatch: dispatch"))
        XCTAssertFalse(runner.contains("_ = dispatch"))
        XCTAssertTrue(context.contains("let dispatch: (LiveRuntimeAction) -> Void"))
    }

    func testNoBroadAutomationQueryOwnedBridgeModeExists() throws {
        let state = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeBridgeMode.swift")

        XCTAssertFalse(state.contains("automationQueryOwned"))
        XCTAssertTrue(state.contains("presentationQueryOwned"))
    }

    func testNoBroadAutomationQueryDomainExists() throws {
        let state = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeDomain.swift")

        XCTAssertFalse(state.contains("automationQuery"))
        XCTAssertTrue(state.contains("case presentationQuery"))
    }

    func testNoBroadAutomationQueryPortExists() throws {
        let ports = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimePorts.swift")

        XCTAssertFalse(ports.contains("AutomationQueryPort"))
        XCTAssertFalse(ports.contains("scanKeynoteWindow"))
        XCTAssertFalse(ports.contains("scanOpenKeynoteFile"))
        XCTAssertTrue(ports.contains("protocol PresentationQueryPort"))
    }

    func testNarrowPresentationQueryEffectExists() throws {
        let effect = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeEffect.swift")

        XCTAssertTrue(effect.contains("scanPresentationQuery"))
    }

    func testNarrowPresentationQueryCallbackActionsExist() throws {
        let action = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeAction.swift")

        XCTAssertTrue(action.contains("operatorRequestedPresentationQuery"))
        XCTAssertTrue(action.contains("presentationQueryCompleted"))
        XCTAssertTrue(action.contains("presentationQueryFailed"))
        XCTAssertTrue(action.contains("presentationQueryResultConsumed"))
    }

    func testResultReturningQueryRequestGoesThroughRuntime() throws {
        let source = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+PresentationAutomation.swift"
        )

        XCTAssertTrue(source.contains("func scanAndAddKeynoteWindows()"))
        XCTAssertTrue(source.contains("operatorRequestedPresentationQuery"))
        XCTAssertTrue(source.contains("consumePresentationQueryOutcomeFromRuntime"))
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

    func testPresentationQueryServiceRemainsBehindViewModelRuntimePort() throws {
        let source = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+PresentationAutomation.swift"
        )
        let wiring = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+RuntimeWiring.swift"
        )

        XCTAssertTrue(source.contains("presentationQueryService.scanPresentationQuery()"))
        XCTAssertTrue(source.contains("scanPresentationQueryForRuntimePort"))
        XCTAssertTrue(wiring.contains("ports.presentationQueryPort.scanHandler"))
        XCTAssertTrue(wiring.contains("presentationQueryCompleted"))
        XCTAssertTrue(wiring.contains("presentationQueryFailed"))
    }

    func testInfrastructureDomainHardeningDidNotIntroduceQueryOwnership() throws {
        let bridgeMode = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeBridgeMode.swift")
        let domain = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeDomain.swift")
        let effect = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeEffect.swift")
        let ports = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimePorts.swift")

        XCTAssertTrue(domain.contains("case imageAssets"))
        XCTAssertTrue(domain.contains("case persistence"))
        XCTAssertFalse(bridgeMode.contains("automationQuery"))
        XCTAssertFalse(domain.contains("automationQuery"))
        XCTAssertTrue(domain.contains("presentationQuery"))
        XCTAssertFalse(effect.contains("AutomationQueryPort"))
        XCTAssertFalse(ports.contains("AutomationQueryPort"))
    }

    func testRuntimeEffectInfrastructureSplitIntroducedOnlyNarrowPresentationQueryOwnership() throws {
        let bridgeMode = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeBridgeMode.swift")
        let domain = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeDomain.swift")
        let effect = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeEffect.swift")
        let ports = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimePorts.swift")
        let action = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeAction.swift")

        XCTAssertFalse(bridgeMode.contains("automationQueryOwned"))
        XCTAssertFalse(domain.contains("automationQuery"))
        XCTAssertTrue(bridgeMode.contains("presentationQueryOwned"))
        XCTAssertTrue(effect.contains("scanPresentationQuery"))
        XCTAssertFalse(ports.contains("AutomationQueryPort"))
        XCTAssertTrue(ports.contains("PresentationQueryPort"))
        XCTAssertFalse(ports.contains("AutomationQueryPort"))
        XCTAssertTrue(action.contains("presentationQueryCompleted"))
        XCTAssertTrue(action.contains("presentationQueryFailed"))
    }
}
