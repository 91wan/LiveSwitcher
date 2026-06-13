import XCTest
@testable import LiveSwitcher

final class ProgramActivationRuntimePortContractTests: XCTestCase {
    func testProgramActivationPortHasNoDefaultNoOpImplementation() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimePorts.swift")

        XCTAssertTrue(source.contains("protocol ProgramActivationPort"))
        XCTAssertFalse(source.contains("extension ProgramActivationPort"))
    }

    func testClosureProgramActivationPortExecutesHandler() {
        let port = ClosureProgramActivationPort()
        let id = UUID()
        let plan = activationPlan()
        var received: (UUID, ProgramActivationPlan)?
        port.executeHandler = { requestID, requestPlan, _ in
            received = (requestID, requestPlan)
        }

        port.execute(id: id, plan: plan, context: LiveRuntimeEffectExecutionContext(
            currentState: { LiveRuntimeState() },
            dispatch: { _ in }
        ))

        XCTAssertEqual(received?.0, id)
        XCTAssertEqual(received?.1, plan)
    }

    func testExecuteProgramActivationEffectCallsProgramActivationPort() {
        let port = ProgramActivationPortSpy()
        let runner = LiveRuntimeEffectRunner(recordsOnly: false, programActivation: port)
        let id = UUID()
        let plan = activationPlan()

        runner.run(
            [.executeProgramActivation(id: id, plan: plan)],
            currentState: { LiveRuntimeState() },
            dispatch: { _ in }
        )

        XCTAssertEqual(port.ids, [id])
        XCTAssertEqual(port.plans, [plan])
    }

    func testProgramActivationPortCanDispatchCompletionThroughContext() {
        let port = ProgramActivationPortSpy()
        port.onExecute = { id, _, context in
            context.dispatch(.programActivationCompleted(id: id))
        }
        let runner = LiveRuntimeEffectRunner(recordsOnly: false, programActivation: port)
        let id = UUID()
        var actions: [LiveRuntimeAction] = []

        runner.run(
            [.executeProgramActivation(id: id, plan: activationPlan())],
            currentState: { LiveRuntimeState() },
            dispatch: { actions.append($0) }
        )

        XCTAssertEqual(actions, [.programActivationCompleted(id: id)])
    }

    func testProgramActivationPortDoesNotMutateProgramQueueDirectly() {
        let port = ProgramActivationPortSpy()
        let runner = LiveRuntimeEffectRunner(recordsOnly: false, programActivation: port)
        var state = LiveRuntimeState()
        state.program.items = [ProgramItem(title: "Existing", subtitle: "KEY")]

        runner.run(
            [.executeProgramActivation(id: UUID(), plan: activationPlan())],
            currentState: { state },
            dispatch: { _ in }
        )

        XCTAssertEqual(state.program.items.map(\.title), ["Existing"])
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

private final class ProgramActivationPortSpy: ProgramActivationPort {
    private(set) var ids: [UUID] = []
    private(set) var plans: [ProgramActivationPlan] = []
    var onExecute: ((UUID, ProgramActivationPlan, LiveRuntimeEffectExecutionContext) -> Void)?

    func execute(id: UUID, plan: ProgramActivationPlan, context: LiveRuntimeEffectExecutionContext) {
        ids.append(id)
        plans.append(plan)
        onExecute?(id, plan, context)
    }
}

