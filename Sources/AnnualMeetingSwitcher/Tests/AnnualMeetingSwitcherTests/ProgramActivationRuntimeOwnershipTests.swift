import XCTest
@testable import LiveSwitcher

final class ProgramActivationRuntimeOwnershipTests: XCTestCase {
    func testProgramSelectionOwnedDoesNotOwnProgramActivationLifecycle() {
        let id = UUID()
        let mutation = LiveRuntimeReducer.reduce(
            state: LiveRuntimeState(),
            action: .operatorRequestedProgramActivation(id: id, plan: activationPlan()),
            environment: .productionProgramSelectionOwning()
        )

        XCTAssertNil(mutation.state.programActivation.activeRequestID)
        XCTAssertTrue(mutation.effects.isEmpty)
    }

    func testProgramActivationOwnedRecordsRequestAndEmitsActivationEffect() {
        let id = UUID()
        let plan = activationPlan()

        let mutation = LiveRuntimeReducer.reduce(
            state: LiveRuntimeState(),
            action: .operatorRequestedProgramActivation(id: id, plan: plan),
            environment: .productionProgramActivationOwning()
        )

        XCTAssertEqual(mutation.state.programActivation.activeRequestID, id)
        XCTAssertEqual(mutation.effects, [.executeProgramActivation(id: id, plan: plan)])
    }

    func testActivationRequestDoesNotMutateSelectionOrQueue() {
        let queued = ProgramItem(title: "Queued", subtitle: "VIDEO", sourceURL: URL(fileURLWithPath: "/tmp/queued.mp4"))
        var state = LiveRuntimeState()
        state.program.items = [queued]
        state.program.currentID = queued.id
        let originalProgram = state.program

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .operatorRequestedProgramActivation(id: UUID(), plan: activationPlan()),
            environment: .productionProgramActivationOwning()
        )

        XCTAssertEqual(mutation.state.program, originalProgram)
    }

    func testActivationCompletedDoesNotMutateSelectionOrQueue() {
        let queued = ProgramItem(title: "Queued", subtitle: "VIDEO", sourceURL: URL(fileURLWithPath: "/tmp/queued.mp4"))
        let requestID = UUID()
        var state = LiveRuntimeState()
        state.program.items = [queued]
        state.program.currentID = queued.id
        state.programActivation.activeRequestID = requestID
        let originalProgram = state.program

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .programActivationCompleted(id: requestID),
            environment: .productionProgramActivationOwning()
        )

        XCTAssertEqual(mutation.state.program, originalProgram)
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

