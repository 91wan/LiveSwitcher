import XCTest
@testable import LiveSwitcher

final class ProgramActivationRuntimeStateTests: XCTestCase {
    func testProgramActivationStateDefaultsToIdle() {
        let state = ProgramActivationRuntimeState()

        XCTAssertNil(state.activeRequestID)
        XCTAssertNil(state.latestCompletedRequestID)
        XCTAssertFalse(state.isActive)
    }

    func testProgramActivationRequestMarksActiveRequest() {
        let id = UUID()
        let plan = activationPlan()

        let mutation = LiveRuntimeReducer.reduce(
            state: LiveRuntimeState(),
            action: .operatorRequestedProgramActivation(id: id, plan: plan),
            environment: .productionProgramActivationOwning()
        )

        XCTAssertEqual(mutation.state.programActivation.activeRequestID, id)
        XCTAssertNil(mutation.state.programActivation.latestCompletedRequestID)
        XCTAssertTrue(mutation.state.programActivation.isActive)
    }

    func testProgramActivationCompletedClearsActiveRequestAndStoresLatestCompletedID() {
        let id = UUID()
        var state = LiveRuntimeState()
        state.programActivation.activeRequestID = id

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .programActivationCompleted(id: id),
            environment: .productionProgramActivationOwning()
        )

        XCTAssertNil(mutation.state.programActivation.activeRequestID)
        XCTAssertEqual(mutation.state.programActivation.latestCompletedRequestID, id)
        XCTAssertFalse(mutation.state.programActivation.isActive)
    }

    func testProgramActivationCompletionIgnoresStaleRequest() {
        let activeID = UUID()
        var state = LiveRuntimeState()
        state.programActivation.activeRequestID = activeID

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .programActivationCompleted(id: UUID()),
            environment: .productionProgramActivationOwning()
        )

        XCTAssertEqual(mutation.state.programActivation.activeRequestID, activeID)
        XCTAssertNil(mutation.state.programActivation.latestCompletedRequestID)
    }

    func testProgramActivationStateDoesNotStoreProgramActivationPlanOrFileURLs() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/ProgramActivationRuntimeState.swift")

        XCTAssertFalse(source.contains("ProgramActivationPlan"))
        XCTAssertFalse(source.contains("URL"))
    }

    private func activationPlan() -> ProgramActivationPlan {
        ProgramActivationPlan(
            item: ProgramItem(title: "Private", subtitle: "VIDEO", sourceURL: URL(fileURLWithPath: "/tmp/private.mp4")),
            runtimeSelection: .queued(UUID()),
            preSelectionEffects: [],
            postSelectionEffects: []
        )
    }
}

