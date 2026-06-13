import XCTest
@testable import LiveSwitcher

@MainActor
final class ProgramActivationRuntimeRecordingTests: XCTestCase {
    func testExecuteProgramActivationRequiresProgramActivationDomain() {
        XCTAssertEqual(
            LiveRuntimeEffect.executeProgramActivation(id: UUID(), plan: activationPlan()).requiredBridgeDomain,
            .programActivation
        )
    }

    func testExecuteProgramActivationRecordedEffectRedactsProgramTitle() {
        let recorded = recordedActivationEffect()

        XCTAssertFalse(String(describing: recorded).contains("Private Title"))
    }

    func testExecuteProgramActivationRecordedEffectRedactsProgramSubtitle() {
        let recorded = recordedActivationEffect()

        XCTAssertFalse(String(describing: recorded).contains("Secret Subtitle"))
    }

    func testExecuteProgramActivationRecordedEffectRemovesSourceURL() throws {
        let recorded = try XCTUnwrap(recordedActivationPlan())

        XCTAssertNil(recorded.item.sourceURL)
        if case .detached(let item) = recorded.runtimeSelection {
            XCTAssertNil(item.sourceURL)
        } else {
            XCTFail("Expected detached runtime selection")
        }
    }

    func testExecuteProgramActivationRecordedEffectPreservesRequestID() throws {
        let id = UUID()
        let recorded = try XCTUnwrap(recordedActivationEffect(id: id))

        if case .executeProgramActivation(let recordedID, _) = recorded {
            XCTAssertEqual(recordedID, id)
        } else {
            XCTFail("Expected executeProgramActivation effect")
        }
    }

    func testExecuteProgramActivationRecordedEffectPreservesPhaseShape() throws {
        let recorded = try XCTUnwrap(recordedActivationPlan())

        XCTAssertEqual(recorded.preSelectionEffects.count, 2)
        XCTAssertEqual(recorded.postSelectionEffects.count, 4)
        XCTAssertEqual(recorded.preSelectionEffects.first, .stopDeck)
        XCTAssertEqual(recorded.postSelectionEffects.first, .clearHTML)
        XCTAssertEqual(recorded.postSelectionEffects.last, .presentActiveDeck)
    }

    func testRuntimeRecordedEffectsStillRedactAutomationScripts() {
        let runner = LiveRuntimeEffectRunner.recording()

        runner.run(
            [.runAppleScript(script: "tell application \"Keynote\" to open POSIX file \"/tmp/private.key\"", action: "keynote.open")],
            currentState: { LiveRuntimeState() },
            dispatch: { _ in XCTFail("Effect runner should not dispatch") }
        )

        XCTAssertEqual(runner.recordedEffects, [.runAppleScript(script: "<redacted>", action: "keynote.open")])
    }

    func testExecuteProgramActivationRecordedEffectStillRedactsPlanAfterHardening() {
        let recorded = String(describing: recordedActivationEffect() as Any)

        XCTAssertFalse(recorded.contains("Private Title"))
        XCTAssertFalse(recorded.contains("Secret Subtitle"))
        XCTAssertFalse(recorded.contains("/Users/operator/private.key"))
    }

    private func recordedActivationPlan() throws -> ProgramActivationPlan? {
        let effect = try XCTUnwrap(recordedActivationEffect())
        if case .executeProgramActivation(_, let plan) = effect {
            return plan
        }
        XCTFail("Expected executeProgramActivation effect")
        return nil
    }

    private func recordedActivationEffect(id: UUID = UUID()) -> LiveRuntimeEffect? {
        let store = LiveRuntimeStore(
            effectRunner: .recording(),
            environment: .productionProgramActivationOwning()
        )

        store.dispatch(.operatorRequestedProgramActivation(id: id, plan: activationPlan()))

        return store.recordedEffects.first
    }

    private func activationPlan() -> ProgramActivationPlan {
        let item = ProgramItem(
            title: "Private Title",
            subtitle: "Secret Subtitle",
            sourceURL: URL(fileURLWithPath: "/Users/operator/private.key")
        )
        return ProgramActivationPlan(
            item: item,
            runtimeSelection: .detached(item),
            preSelectionEffects: [.stopDeck, .presentInvalidDeckAlert(item.sourceURL!)],
            postSelectionEffects: [.clearHTML, .presentKeynote(item.sourceURL!), .openHTML(item.sourceURL!), .presentActiveDeck]
        )
    }
}
