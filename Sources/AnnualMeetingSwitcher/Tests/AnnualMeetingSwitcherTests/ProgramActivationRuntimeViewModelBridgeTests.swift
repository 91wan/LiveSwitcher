import XCTest
@testable import LiveSwitcher

final class ProgramActivationRuntimeViewModelBridgeTests: XCTestCase {
    func testProgramActivationSourceGateStaysInProgramActivationEntryPoint() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+ProgramActivation.swift")

        XCTAssertTrue(source.contains("programSourceIsAvailable(item)"))
        XCTAssertTrue(source.contains("ProgramActivationPlanner.plan("))
        XCTAssertTrue(source.contains(".operatorRequestedProgramActivation"))
    }

    func testProgramActivationRuntimeBridgeDoesNotOwnSourceAvailabilityOrPlanning() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+ProgramActivationRuntimeBridge.swift")

        XCTAssertFalse(source.contains("programSourceIsAvailable"))
        XCTAssertFalse(source.contains("ProgramSourceAvailabilityPolicy"))
        XCTAssertFalse(source.contains("ProgramActivationPlanner.plan"))
        XCTAssertFalse(source.contains("isLikelyValidDeckDocument"))
    }

    func testProgramActivationRuntimeBridgeDispatchesSelectionThroughContextAndCompletes() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+ProgramActivationRuntimeBridge.swift")

        XCTAssertTrue(source.contains("context.dispatch(.operatorSelectedProgram"))
        XCTAssertTrue(source.contains("context.dispatch(.operatorSelectedDetachedProgram"))
        XCTAssertTrue(source.contains("context.dispatch(.programActivationCompleted"))
        XCTAssertFalse(source.contains("dispatchRuntimeFacadeAction"))
    }
}

