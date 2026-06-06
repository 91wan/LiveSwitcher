import XCTest
@testable import LiveSwitcher

@MainActor
final class LiveRuntimeEffectExecutionContextTests: XCTestCase {
    func testEffectExecutionContextCarriesCurrentState() {
        var state = LiveRuntimeState()
        state.audio.isSpeakerMode = true
        let context = LiveRuntimeEffectExecutionContext(
            currentState: { state },
            dispatch: { _ in }
        )

        XCTAssertTrue(context.currentState().audio.isSpeakerMode)
    }

    func testEffectExecutionContextCarriesDispatch() {
        var received: LiveRuntimeAction?
        let context = LiveRuntimeEffectExecutionContext(
            currentState: { LiveRuntimeState() },
            dispatch: { received = $0 }
        )

        context.dispatch(.operatorToggledProjection)

        XCTAssertEqual(received, .operatorToggledProjection)
    }

    func testEffectExecutionContextCanDispatchRuntimeAction() {
        var actions: [LiveRuntimeAction] = []
        let context = LiveRuntimeEffectExecutionContext(
            currentState: { LiveRuntimeState() },
            dispatch: { actions.append($0) }
        )

        context.dispatch(.automationNoticeDismissed)

        XCTAssertEqual(actions, [.automationNoticeDismissed])
    }

    func testEffectExecutionContextDoesNotStoreMutableState() throws {
        let source = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeEffectExecutionContext.swift"
        )

        XCTAssertTrue(source.contains("struct LiveRuntimeEffectExecutionContext"))
        XCTAssertTrue(source.contains("let currentState: () -> LiveRuntimeState"))
        XCTAssertTrue(source.contains("let dispatch: (LiveRuntimeAction) -> Void"))
        XCTAssertFalse(source.contains("var currentState"))
        XCTAssertFalse(source.contains("var dispatch"))
    }

    func testEffectExecutionContextCallersRemainMainActorThroughRuntimeStore() throws {
        let source = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeStore.swift"
        )

        XCTAssertTrue(source.contains("@MainActor"))
        XCTAssertTrue(source.contains("final class LiveRuntimeStore"))
        XCTAssertTrue(source.contains("dispatch: { [weak self] action in self?.dispatch(action) }"))
    }
}
