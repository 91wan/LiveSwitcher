import XCTest
@testable import LiveSwitcher

final class ProgramActivationRuntimeReducerBehaviorTests: XCTestCase {
    func testRequestedProgramActivationStartsActiveRequest() {
        let id = UUID()
        let mutation = reduce(.operatorRequestedProgramActivation(id: id, plan: activationPlan()))

        XCTAssertEqual(mutation.state.programActivation.activeRequestID, id)
    }

    func testRequestedProgramActivationClearsLatestCompletedRequest() {
        let id = UUID()
        var state = LiveRuntimeState()
        state.programActivation.latestCompletedRequestID = UUID()

        let mutation = reduce(state, .operatorRequestedProgramActivation(id: id, plan: activationPlan()))

        XCTAssertNil(mutation.state.programActivation.latestCompletedRequestID)
    }

    func testRequestedProgramActivationEmitsExecuteEffect() {
        let id = UUID()
        let plan = activationPlan()
        let mutation = reduce(.operatorRequestedProgramActivation(id: id, plan: plan))

        XCTAssertEqual(mutation.effects, [.executeProgramActivation(id: id, plan: plan)])
    }

    func testRequestedProgramActivationEmitsOnlyExecuteProgramActivationEffect() {
        let mutation = reduce(.operatorRequestedProgramActivation(id: UUID(), plan: activationPlan()))

        XCTAssertEqual(mutation.effects.count, 1)
        if case .executeProgramActivation = mutation.effects.first {
        } else {
            XCTFail("Expected executeProgramActivation effect")
        }
    }

    func testRequestedProgramActivationDoesNotStorePlanInState() {
        let mutation = reduce(.operatorRequestedProgramActivation(id: UUID(), plan: activationPlan()))
        let summary = String(describing: mutation.state.programActivation)

        XCTAssertFalse(summary.contains("Private Title"))
        XCTAssertFalse(summary.contains("Secret Subtitle"))
        XCTAssertFalse(summary.contains("/tmp/Private Title.mp4"))
    }

    func testRequestedProgramActivationDoesNotMutateProgramQueue() {
        let state = queuedState()
        let originalProgram = state.program

        let mutation = reduce(state, .operatorRequestedProgramActivation(id: UUID(), plan: activationPlan()))

        XCTAssertEqual(mutation.state.program, originalProgram)
    }

    func testRequestedProgramActivationDoesNotMutateCurrentProgramSelection() {
        let state = queuedState()
        let originalCurrentID = state.program.currentID

        let mutation = reduce(state, .operatorRequestedProgramActivation(id: UUID(), plan: activationPlan()))

        XCTAssertEqual(mutation.state.program.currentID, originalCurrentID)
    }

    func testRequestedProgramActivationDoesNotRecordSupport() {
        let mutation = reduce(.operatorRequestedProgramActivation(id: UUID(), plan: activationPlan()))

        XCTAssertTrue(mutation.effects.allSatisfy { effect in
            if case .recordSupportEvent = effect { return false }
            return true
        })
    }

    func testProgramActivationCompletedClearsActiveRequest() {
        let id = UUID()
        let mutation = reduce(activeState(id), .programActivationCompleted(id: id))

        XCTAssertNil(mutation.state.programActivation.activeRequestID)
    }

    func testProgramActivationCompletedStoresLatestCompletedRequestID() {
        let id = UUID()
        let mutation = reduce(activeState(id), .programActivationCompleted(id: id))

        XCTAssertEqual(mutation.state.programActivation.latestCompletedRequestID, id)
    }

    func testProgramActivationCompletedDoesNotMutateProgramQueue() {
        let id = UUID()
        var state = queuedState()
        state.programActivation.activeRequestID = id
        let originalProgram = state.program

        let mutation = reduce(state, .programActivationCompleted(id: id))

        XCTAssertEqual(mutation.state.program, originalProgram)
    }

    func testProgramActivationCompletedDoesNotRecordSupport() {
        let id = UUID()
        let mutation = reduce(activeState(id), .programActivationCompleted(id: id))

        XCTAssertTrue(mutation.effects.allSatisfy { effect in
            if case .recordSupportEvent = effect { return false }
            return true
        })
    }

    private func reduce(_ action: LiveRuntimeAction) -> LiveRuntimeMutation {
        reduce(LiveRuntimeState(), action)
    }

    private func reduce(_ state: LiveRuntimeState, _ action: LiveRuntimeAction) -> LiveRuntimeMutation {
        LiveRuntimeReducer.reduce(
            state: state,
            action: action,
            environment: .productionProgramActivationOwning()
        )
    }

    private func activeState(_ id: UUID) -> LiveRuntimeState {
        var state = LiveRuntimeState()
        state.programActivation.activeRequestID = id
        return state
    }

    private func queuedState() -> LiveRuntimeState {
        let item = ProgramItem(title: "Queued", subtitle: "VIDEO", sourceURL: URL(fileURLWithPath: "/tmp/queued.mp4"))
        var state = LiveRuntimeState()
        state.program.items = [item]
        state.program.currentID = item.id
        return state
    }

    private func activationPlan() -> ProgramActivationPlan {
        ProgramActivationPlan(
            item: ProgramItem(title: "Private Title", subtitle: "Secret Subtitle", sourceURL: URL(fileURLWithPath: "/tmp/Private Title.mp4")),
            runtimeSelection: .queued(UUID()),
            preSelectionEffects: [],
            postSelectionEffects: []
        )
    }
}
