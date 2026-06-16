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

    func testProgramActivationActionsNoopBeforeProgramActivationOwnership() {
        let id = UUID()
        let mutation = LiveRuntimeReducer.reduce(
            state: LiveRuntimeState(),
            action: .operatorRequestedProgramActivation(id: id, plan: activationPlan()),
            environment: .productionProgramSelectionOwning()
        )

        XCTAssertNil(mutation.state.programActivation.activeRequestID)
        XCTAssertTrue(mutation.effects.isEmpty)
    }

    func testProgramActivationCompletionNoopsBeforeProgramActivationOwnership() {
        let id = UUID()
        var state = LiveRuntimeState()
        state.programActivation.activeRequestID = id

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .programActivationCompleted(id: id),
            environment: .productionProgramSelectionOwning()
        )

        XCTAssertEqual(mutation.state.programActivation.activeRequestID, id)
        XCTAssertNil(mutation.state.programActivation.latestCompletedRequestID)
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

    func testProgramActivationActionsMutateWhenProgramActivationOwned() {
        let id = UUID()
        let plan = activationPlan()

        let requested = LiveRuntimeReducer.reduce(
            state: LiveRuntimeState(),
            action: .operatorRequestedProgramActivation(id: id, plan: plan),
            environment: .productionProgramActivationOwning()
        )
        let completed = LiveRuntimeReducer.reduce(
            state: requested.state,
            action: .programActivationCompleted(id: id),
            environment: .productionProgramActivationOwning()
        )

        XCTAssertEqual(requested.state.programActivation.activeRequestID, id)
        XCTAssertEqual(requested.effects, [.executeProgramActivation(id: id, plan: plan)])
        XCTAssertNil(completed.state.programActivation.activeRequestID)
        XCTAssertEqual(completed.state.programActivation.latestCompletedRequestID, id)
    }

    func testAllProgramActivationCasesHaveExplicitProgramActivationOwnershipGuard() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeReducer.swift")

        for casePattern in [
            ".operatorRequestedProgramActivation(let id, let plan)",
            ".programActivationCompleted(let id)"
        ] {
            let body = try caseBody(casePattern, in: source)
            XCTAssertTrue(body.contains("guard isRuntimeOwned(.programActivation, in: bridgeMode) else { break }"), casePattern)
        }
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

    private func caseBody(_ casePattern: String, in source: String) throws -> String {
        guard let range = source.range(of: "case \(casePattern):") else {
            throw NSError(domain: "Missing case \(casePattern)", code: 1)
        }
        let nextCase = source[range.upperBound...].range(of: "\n        case ")
        let end = nextCase?.lowerBound ?? source.endIndex
        return String(source[range.lowerBound..<end])
    }
}
