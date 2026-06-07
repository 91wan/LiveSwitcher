import XCTest

final class ViewModelProgramActivationBehaviorTests: XCTestCase {
    func testProgramActivationViewModelExecutionContract() throws {
        let source = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+ProgramActivation.swift"
        )

        XCTAssertTrue(source.contains("func switchToProgram(_ item: ProgramItem)"))
        XCTAssertTrue(source.contains("guard programSourceIsAvailable(item) else { return }"))
        XCTAssertTrue(source.contains("ProgramActivationPlanner.plan("))
        XCTAssertTrue(source.contains("executeProgramActivationPlan(plan)"))

        XCTAssertTrue(source.contains("private func executeProgramActivationPlan(_ plan: ProgramActivationPlan)"))
        XCTAssertTrue(source.contains("if case .invalidDeck(let url) = plan.sideEffect"))
        XCTAssertTrue(source.contains("actionHandlers.invalidDeck(url)"))
        XCTAssertTrue(source.contains("if plan.shouldStopCurrentDeckPresentation"))
        XCTAssertTrue(source.contains("actionHandlers.deckStop()"))
        XCTAssertTrue(source.contains("dispatchRuntimeProgramSelection(plan.runtimeSelection)"))
        XCTAssertTrue(source.contains("setCurrentProgramFromOperatorSelection(plan.item)"))
        XCTAssertTrue(source.contains("currentHTMLURL = nil"))

        XCTAssertTrue(source.contains("actionHandlers.keynotePresentation(url)"))
        XCTAssertTrue(source.contains("actionHandlers.pptxOpen(url)"))
        XCTAssertTrue(source.contains("openHTMLInOutputWindow(url: url)"))
        XCTAssertTrue(source.contains("actionHandlers.activeDeckPresentation()"))

        XCTAssertTrue(source.contains("dispatchRuntimeFacadeAction(.operatorSelectedProgram(id))"))
        XCTAssertTrue(source.contains("dispatchRuntimeFacadeAction(.operatorSelectedDetachedProgram(item))"))
        XCTAssertTrue(source.contains("recordSupportEvent("))
        XCTAssertTrue(source.contains("showAutomationRuntimeNotice(action: \"program.source.missing\")"))
    }
}
