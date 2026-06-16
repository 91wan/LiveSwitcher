import XCTest
@testable import LiveSwitcher

final class ProgramQueueRuntimeOwnershipGuardTests: XCTestCase {
    func testProgramQueueActionsNoopBeforeProgramQueueOwnership() {
        for action in programQueueActions {
            let state = queueState([programItem("Existing")])
            let mutation = reduce(state, action, bridgeMode: .presentationQueryOwned)

            XCTAssertEqual(mutation.state.program, state.program, action.redactedName)
            XCTAssertTrue(mutation.effects.isEmpty, action.redactedName)
        }
    }

    func testProgramQueueActionsMutateWhenProgramQueueOwned() {
        for (state, action) in programQueueMutationScenarios {
            let mutation = reduce(state, action, bridgeMode: .programQueueOwned)

            XCTAssertNotEqual(mutation.state.program.items, state.program.items, action.redactedName)
        }
    }

    func testFacadeLoadedProgramQueueNoopsBeforeProgramQueueOwnership() {
        let state = queueState([programItem("Existing")])
        let loaded = programItem("Loaded")
        let mutation = reduce(state, .facadeLoadedProgramQueue([loaded]), bridgeMode: .presentationQueryOwned)

        XCTAssertEqual(mutation.state.program, state.program)
    }

    func testAllProgramQueueCasesHaveExplicitProgramQueueOwnershipGuard() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeReducer.swift")

        for casePattern in [
            ".operatorAddedProgramItems(let items)",
            ".operatorRemovedProgramItem(let id)",
            ".operatorMovedProgramItems(let fromOffsets, let toOffset)",
            ".operatorUpdatedProgramItemSchedule(let id, let scheduledStartAt, let scheduledDuration)",
            ".operatorAddedAgendaMarker(let title)",
            ".facadeLoadedProgramQueue(let items)"
        ] {
            assertCase(
                casePattern,
                in: source,
                contains: "guard isRuntimeOwned(.programQueue, in: bridgeMode) else { break }"
            )
        }
    }

    private var programQueueActions: [LiveRuntimeAction] {
        let item = programItem("Action")
        return [
            .operatorAddedProgramItems([item]),
            .operatorRemovedProgramItem(item.id),
            .operatorMovedProgramItems(fromOffsets: [0], toOffset: 1),
            .operatorUpdatedProgramItemSchedule(id: item.id, scheduledStartAt: Date(), scheduledDuration: 20),
            .operatorAddedAgendaMarker(title: "Break")
        ]
    }

    private var programQueueMutationScenarios: [(LiveRuntimeState, LiveRuntimeAction)] {
        let existing = programItem("Existing")
        let added = programItem("Added")
        let first = programItem("First")
        let second = programItem("Second")
        let scheduled = programItem("Scheduled")
        return [
            (queueState([existing]), .operatorAddedProgramItems([added])),
            (queueState([existing]), .operatorRemovedProgramItem(existing.id)),
            (queueState([first, second]), .operatorMovedProgramItems(fromOffsets: [0], toOffset: 2)),
            (queueState([scheduled]), .operatorUpdatedProgramItemSchedule(id: scheduled.id, scheduledStartAt: Date(), scheduledDuration: 20)),
            (queueState([existing]), .operatorAddedAgendaMarker(title: "Break"))
        ]
    }

    private func reduce(
        _ state: LiveRuntimeState,
        _ action: LiveRuntimeAction,
        bridgeMode: LiveRuntimeBridgeMode
    ) -> LiveRuntimeMutation {
        LiveRuntimeReducer.reduce(
            state: state,
            action: action,
            environment: LiveRuntimeEnvironment(bridgeMode: bridgeMode)
        )
    }

    private func queueState(_ items: [ProgramItem]) -> LiveRuntimeState {
        var state = LiveRuntimeState()
        state.program.items = items
        return state
    }

    private func programItem(_ title: String) -> ProgramItem {
        ProgramItem(title: title, subtitle: "MEDIA", sourceURL: URL(fileURLWithPath: "/tmp/\(title).mp4"))
    }

    private func assertCase(
        _ casePattern: String,
        in source: String,
        contains expected: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let range = source.range(of: "case \(casePattern):") else {
            return XCTFail("Missing case \(casePattern)", file: file, line: line)
        }
        let endIndex = source.index(range.lowerBound, offsetBy: 360, limitedBy: source.endIndex) ?? source.endIndex
        let body = String(source[range.lowerBound..<endIndex])

        XCTAssertTrue(body.contains(expected), expected, file: file, line: line)
    }
}
