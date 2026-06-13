import XCTest
@testable import LiveSwitcher

@MainActor
final class ProgramActivationRuntimeEffectTests: XCTestCase {
    func testExecuteProgramActivationEffectRequiresProgramActivationDomain() {
        XCTAssertEqual(
            LiveRuntimeEffect.executeProgramActivation(id: UUID(), plan: activationPlan()).requiredBridgeDomain,
            .programActivation
        )
    }

    func testActivationEffectIsFilteredBeforeProgramActivationOwnedMode() {
        let mutation = LiveRuntimeReducer.reduce(
            state: LiveRuntimeState(),
            action: .operatorRequestedProgramActivation(id: UUID(), plan: activationPlan()),
            environment: .productionProgramSelectionOwning()
        )

        XCTAssertTrue(mutation.effects.isEmpty)
    }

    func testRecordedActivationEffectRedactsProgramTitleAndFilePath() {
        let item = ProgramItem(
            title: "Private CEO Keynote",
            subtitle: "Secret",
            sourceURL: URL(fileURLWithPath: "/Users/operator/private.key")
        )
        let plan = ProgramActivationPlan(
            item: item,
            runtimeSelection: .detached(item),
            preSelectionEffects: [.presentInvalidDeckAlert(item.sourceURL!)],
            postSelectionEffects: [.presentKeynote(item.sourceURL!)]
        )
        let store = LiveRuntimeStore(
            effectRunner: .recording(),
            environment: .productionProgramActivationOwning()
        )

        store.dispatch(.operatorRequestedProgramActivation(id: UUID(), plan: plan))

        let recorded = String(describing: store.recordedEffects)
        XCTAssertFalse(recorded.contains("Private CEO Keynote"))
        XCTAssertFalse(recorded.contains("Secret"))
        XCTAssertFalse(recorded.contains("/Users/operator/private.key"))
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
