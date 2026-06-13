import XCTest
@testable import LiveSwitcher

@MainActor
final class ProgramActivationRuntimeActionLogTests: XCTestCase {
    func testActivationRequestIsLoggedByRedactedNameOnly() {
        let store = LiveRuntimeStore(
            effectRunner: .recording(),
            environment: .productionProgramActivationOwning()
        )

        store.dispatch(.operatorRequestedProgramActivation(id: UUID(), plan: activationPlan()))

        XCTAssertTrue(store.actionLog.contains { $0.actionName == "operatorRequestedProgramActivation" })
    }

    func testActivationCompletedIsNotLogged() {
        let id = UUID()
        var state = LiveRuntimeState()
        state.programActivation.activeRequestID = id
        let store = LiveRuntimeStore(
            initialState: state,
            effectRunner: .recording(),
            environment: .productionProgramActivationOwning()
        )

        store.dispatch(.programActivationCompleted(id: id))

        XCTAssertFalse(store.actionLog.contains { $0.actionName == "programActivationCompleted" })
    }

    func testActivationActionLogDoesNotContainPlanTitleOrPath() {
        let store = LiveRuntimeStore(
            effectRunner: .recording(),
            environment: .productionProgramActivationOwning()
        )

        store.dispatch(.operatorRequestedProgramActivation(id: UUID(), plan: activationPlan()))

        let log = store.actionLog.map { "\($0.actionName)|\($0.oldStateSummary)|\($0.newStateSummary)" }.joined(separator: "\n")
        XCTAssertFalse(log.contains("Private Title"))
        XCTAssertFalse(log.contains("/tmp/Private Title.mp4"))
    }

    func testStaleActivationEffectDoesNotAppendCompletionActionLog() {
        let staleID = UUID()
        let activeID = UUID()
        var state = LiveRuntimeState()
        state.programActivation.activeRequestID = activeID
        let store = LiveRuntimeStore(
            initialState: state,
            effectRunner: .recording(),
            environment: .productionProgramActivationOwning()
        )

        store.dispatch(.programActivationCompleted(id: staleID))

        XCTAssertFalse(store.actionLog.contains { $0.actionName == "programActivationCompleted" })
    }

    func testRejectedSelectionActivationRequestDoesNotLeakProgramTitleInActionLog() {
        let log = rejectedSelectionActionLog()

        XCTAssertFalse(log.contains("Private Title"))
    }

    func testRejectedSelectionActivationRequestDoesNotLeakFilePathInActionLog() {
        let log = rejectedSelectionActionLog()

        XCTAssertFalse(log.contains("/tmp/Private Title.mp4"))
    }

    private func rejectedSelectionActionLog() -> String {
        let store = LiveRuntimeStore(
            effectRunner: .recording(),
            environment: .productionProgramActivationOwning()
        )
        store.dispatch(.operatorRequestedProgramActivation(id: UUID(), plan: activationPlan()))
        return store.actionLog
            .map { "\($0.actionName)|\($0.oldStateSummary)|\($0.newStateSummary)" }
            .joined(separator: "\n")
    }

    private func activationPlan() -> ProgramActivationPlan {
        ProgramActivationPlan(
            item: ProgramItem(title: "Private Title", subtitle: "VIDEO", sourceURL: URL(fileURLWithPath: "/tmp/Private Title.mp4")),
            runtimeSelection: .queued(UUID()),
            preSelectionEffects: [],
            postSelectionEffects: []
        )
    }
}
