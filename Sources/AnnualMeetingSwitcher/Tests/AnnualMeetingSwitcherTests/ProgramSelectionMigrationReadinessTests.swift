import XCTest
@testable import LiveSwitcher

final class ProgramSelectionMigrationReadinessTests: XCTestCase {
    func testProgramSelectionMutationsLiveInDedicatedFile() throws {
        let source = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/ProgramSelectionRuntimeMutations.swift"
        )

        XCTAssertTrue(source.contains("func reduceSelectedProgram"))
        XCTAssertTrue(source.contains("func selectedProgramItem"))
    }

    func testProgramSelectionHelpersNoLongerLiveInReducerFile() throws {
        let source = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeReducer.swift"
        )

        XCTAssertFalse(source.contains("private static func reduceSelectedProgram"))
        XCTAssertFalse(source.contains("private static func selectedProgramItem"))
    }

    func testProgramActivationStillHasNoRuntimeActivationDomainOrEffects() throws {
        let runtimeState = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeState.swift"
        )
        let effect = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeEffect.swift"
        )
        let action = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeAction.swift"
        )

        XCTAssertFalse(runtimeState.contains("programActivationOwned"))
        XCTAssertFalse(runtimeState.contains("case programActivation"))
        XCTAssertFalse(effect.contains("activateProgram"))
        XCTAssertFalse(action.contains("programActivationCompleted"))
        XCTAssertFalse(action.contains("programActivationFailed"))
    }

    func testActivationExecutorStillOwnsSideEffectDispatch() throws {
        let source = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+ProgramActivation.swift"
        )

        XCTAssertTrue(source.contains("actionHandlers.keynotePresentation"))
        XCTAssertTrue(source.contains("actionHandlers.pptxOpen"))
        XCTAssertTrue(source.contains("openHTMLInOutputWindow(url: url)"))
        XCTAssertTrue(source.contains("actionHandlers.activeDeckPresentation"))
        XCTAssertFalse(source.contains("activateProgram"))
    }
}
