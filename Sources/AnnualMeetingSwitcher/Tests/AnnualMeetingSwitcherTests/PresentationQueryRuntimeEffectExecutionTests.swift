import XCTest
@testable import LiveSwitcher

final class PresentationQueryRuntimeEffectExecutionTests: XCTestCase {
    func testScanPresentationQueryEffectRequiresPresentationQueryDomain() {
        XCTAssertEqual(LiveRuntimeEffect.scanPresentationQuery(id: UUID()).requiredBridgeDomain, .presentationQuery)
    }

    func testScanPresentationQueryEffectCallsPresentationQueryPort() {
        let port = PresentationQueryPortSpy()
        let runner = LiveRuntimeEffectRunner(recordsOnly: false, presentationQuery: port)
        let id = UUID()

        runner.run(
            [.scanPresentationQuery(id: id)],
            currentState: { LiveRuntimeState() },
            dispatch: { _ in }
        )

        XCTAssertEqual(port.ids, [id])
    }

    func testPresentationQueryPortCanDispatchCompletedActionThroughContext() {
        let port = PresentationQueryPortSpy()
        port.onScan = { id, context in
            context.dispatch(.presentationQueryCompleted(id: id, result: .empty))
        }
        let runner = LiveRuntimeEffectRunner(recordsOnly: false, presentationQuery: port)
        let id = UUID()
        var actions: [LiveRuntimeAction] = []

        runner.run(
            [.scanPresentationQuery(id: id)],
            currentState: { LiveRuntimeState() },
            dispatch: { actions.append($0) }
        )

        XCTAssertEqual(actions, [.presentationQueryCompleted(id: id, result: .empty)])
    }

    func testPresentationQueryPortCanDispatchFailedActionThroughContext() {
        let port = PresentationQueryPortSpy()
        port.onScan = { id, context in
            context.dispatch(.presentationQueryFailed(id: id, action: "keynote.scan.windows", sanitizedMessage: "failed"))
        }
        let runner = LiveRuntimeEffectRunner(recordsOnly: false, presentationQuery: port)
        let id = UUID()
        var actions: [LiveRuntimeAction] = []

        runner.run(
            [.scanPresentationQuery(id: id)],
            currentState: { LiveRuntimeState() },
            dispatch: { actions.append($0) }
        )

        XCTAssertEqual(actions, [.presentationQueryFailed(id: id, action: "keynote.scan.windows", sanitizedMessage: "failed")])
    }

    func testPresentationQueryPortUsesContextCurrentState() {
        let port = PresentationQueryPortSpy()
        port.onScan = { _, context in
            XCTAssertEqual(context.currentState().presentationQuery.activeRequestID, UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        }
        let runner = LiveRuntimeEffectRunner(recordsOnly: false, presentationQuery: port)
        var state = LiveRuntimeState()
        state.presentationQuery.activeRequestID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")

        runner.run(
            [.scanPresentationQuery(id: UUID())],
            currentState: { state },
            dispatch: { _ in }
        )
    }

    func testPresentationQueryPortDoesNotMutateProgramQueueDirectly() {
        let port = PresentationQueryPortSpy()
        let runner = LiveRuntimeEffectRunner(recordsOnly: false, presentationQuery: port)
        var state = LiveRuntimeState()
        state.program.items = [ProgramItem(title: "Existing", subtitle: "KEY")]

        runner.run(
            [.scanPresentationQuery(id: UUID())],
            currentState: { state },
            dispatch: { _ in }
        )

        XCTAssertEqual(state.program.items.map(\.title), ["Existing"])
    }
}

private final class PresentationQueryPortSpy: PresentationQueryPort {
    private(set) var ids: [UUID] = []
    var onScan: ((UUID, LiveRuntimeEffectExecutionContext) -> Void)?

    func scan(id: UUID, context: LiveRuntimeEffectExecutionContext) {
        ids.append(id)
        onScan?(id, context)
    }
}
