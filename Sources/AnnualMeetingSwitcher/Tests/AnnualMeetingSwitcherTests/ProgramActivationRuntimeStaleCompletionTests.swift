import XCTest
@testable import LiveSwitcher

final class ProgramActivationRuntimeStaleCompletionTests: XCTestCase {
    func testProgramActivationCompletedIgnoresStaleRequestID() {
        let activeID = UUID()
        var state = LiveRuntimeState()
        state.programActivation.activeRequestID = activeID

        let mutation = reduce(state, .programActivationCompleted(id: UUID()))

        XCTAssertEqual(mutation.state.programActivation.activeRequestID, activeID)
    }

    func testProgramActivationCompletedDoesNotClearNewerActiveRequest() {
        let newerID = UUID()
        var state = LiveRuntimeState()
        state.programActivation.activeRequestID = newerID

        let mutation = reduce(state, .programActivationCompleted(id: UUID()))

        XCTAssertEqual(mutation.state.programActivation.activeRequestID, newerID)
    }

    func testProgramActivationCompletedDoesNotOverwriteLatestCompletedForStaleID() {
        let latestID = UUID()
        var state = LiveRuntimeState()
        state.programActivation.activeRequestID = UUID()
        state.programActivation.latestCompletedRequestID = latestID

        let mutation = reduce(state, .programActivationCompleted(id: UUID()))

        XCTAssertEqual(mutation.state.programActivation.latestCompletedRequestID, latestID)
    }

    func testNewProgramActivationRequestReplacesPriorActiveRequest() {
        let priorID = UUID()
        let newID = UUID()
        var state = LiveRuntimeState()
        state.programActivation.activeRequestID = priorID

        let mutation = reduce(state, .operatorRequestedProgramActivation(id: newID, plan: activationPlan()))

        XCTAssertEqual(mutation.state.programActivation.activeRequestID, newID)
    }

    func testNewProgramActivationRequestClearsLatestCompletedRequest() {
        let newID = UUID()
        var state = LiveRuntimeState()
        state.programActivation.latestCompletedRequestID = UUID()

        let mutation = reduce(state, .operatorRequestedProgramActivation(id: newID, plan: activationPlan()))

        XCTAssertNil(mutation.state.programActivation.latestCompletedRequestID)
    }

    private func reduce(_ state: LiveRuntimeState, _ action: LiveRuntimeAction) -> LiveRuntimeMutation {
        LiveRuntimeReducer.reduce(
            state: state,
            action: action,
            environment: .productionProgramActivationOwning()
        )
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
