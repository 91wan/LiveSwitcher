import XCTest
@testable import LiveSwitcher

final class AgendaMarkerRuntimeBehaviorTests: XCTestCase {
    func testAddAgendaMarkerUsesInputWithoutImplicitStart() throws {
        let previousStart = Date(timeIntervalSince1970: 100)
        var previous = programItem("Opening")
        previous.scheduledStartAt = previousStart
        previous.scheduledDuration = 60
        let input = AgendaMarkerInput(title: "  茶歇  ", scheduledStartAt: nil, duration: 15 * 60)

        let mutation = reduce(queueState([previous]), .operatorAddedAgendaMarker(input))
        let marker = try XCTUnwrap(mutation.state.program.items.last)

        XCTAssertTrue(marker.isAgendaMarker)
        XCTAssertEqual(marker.title, "茶歇")
        XCTAssertNil(marker.scheduledStartAt)
        XCTAssertEqual(marker.scheduledDuration, 15 * 60)
        XCTAssertNil(marker.sourceURL)
        XCTAssertEqual(marker.subtitle, ProgramItem.agendaMarkerSubtitle)
    }

    func testAddAgendaMarkerPreservesExplicitStartAndDuration() throws {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let input = AgendaMarkerInput(title: "提醒", scheduledStartAt: start, duration: 999 * 60)

        let mutation = reduce(queueState([]), .operatorAddedAgendaMarker(input))
        let marker = try XCTUnwrap(mutation.state.program.items.first)

        XCTAssertEqual(marker.title, "提醒")
        XCTAssertEqual(marker.scheduledStartAt, start)
        XCTAssertEqual(marker.scheduledDuration, 999 * 60)
    }

    func testUpdateAgendaMarkerIsAtomicAndPreservesIdentityAndQueuePosition() throws {
        let first = programItem("Opening")
        let marker = ProgramItem.agendaMarker(
            title: "茶歇",
            scheduledStartAt: Date(timeIntervalSince1970: 100),
            durationMinutes: 15
        )
        let last = programItem("Awards")
        let newStart = Date(timeIntervalSince1970: 200)
        let input = AgendaMarkerInput(title: "转场", scheduledStartAt: newStart, duration: 20 * 60)

        let mutation = reduce(
            queueState([first, marker, last]),
            .operatorUpdatedAgendaMarker(id: marker.id, input: input)
        )

        XCTAssertEqual(mutation.state.program.items.map(\.id), [first.id, marker.id, last.id])
        let updated = try XCTUnwrap(mutation.state.program.items.first { $0.id == marker.id })
        XCTAssertEqual(updated.title, "转场")
        XCTAssertEqual(updated.scheduledStartAt, newStart)
        XCTAssertEqual(updated.scheduledDuration, 20 * 60)
        XCTAssertNil(updated.sourceURL)
        XCTAssertEqual(updated.subtitle, ProgramItem.agendaMarkerSubtitle)
    }

    func testUpdateAgendaMarkerCanClearScheduledStart() throws {
        let marker = ProgramItem.agendaMarker(
            title: "提醒",
            scheduledStartAt: Date(timeIntervalSince1970: 100),
            durationMinutes: 15
        )
        let input = AgendaMarkerInput(title: "提醒", scheduledStartAt: nil, duration: 1 * 60)

        let mutation = reduce(queueState([marker]), .operatorUpdatedAgendaMarker(id: marker.id, input: input))
        let updated = try XCTUnwrap(mutation.state.program.items.first)

        XCTAssertNil(updated.scheduledStartAt)
        XCTAssertEqual(updated.scheduledDuration, 60)
    }

    func testUpdateAgendaMarkerRejectsNormalPrograms() {
        let program = programItem("Opening")
        let input = AgendaMarkerInput(title: "转场", scheduledStartAt: Date(), duration: 20 * 60)

        let mutation = reduce(queueState([program]), .operatorUpdatedAgendaMarker(id: program.id, input: input))

        XCTAssertEqual(mutation.state.program.items, [program])
    }

    func testGenericScheduleUpdateDoesNotMutateAgendaMarkers() {
        let marker = ProgramItem.agendaMarker(
            title: "茶歇",
            scheduledStartAt: Date(timeIntervalSince1970: 100),
            durationMinutes: 15
        )

        let mutation = reduce(
            queueState([marker]),
            .operatorUpdatedProgramItemSchedule(
                id: marker.id,
                scheduledStartAt: Date(timeIntervalSince1970: 200),
                scheduledDuration: 30 * 60
            )
        )

        XCTAssertEqual(mutation.state.program.items, [marker])
    }

    func testAgendaMarkerMutationsDoNotChangeCurrentSelection() {
        let program = programItem("Opening")
        let marker = ProgramItem.agendaMarker(title: "茶歇")
        var state = queueState([program, marker])
        state.program.currentID = program.id
        let input = AgendaMarkerInput(title: "提醒", scheduledStartAt: nil, duration: 15 * 60)

        let mutation = reduce(state, .operatorUpdatedAgendaMarker(id: marker.id, input: input))

        XCTAssertEqual(mutation.state.program.currentID, program.id)
    }

    private func reduce(
        _ state: LiveRuntimeState = LiveRuntimeState(),
        _ action: LiveRuntimeAction
    ) -> LiveRuntimeMutation {
        LiveRuntimeReducer.reduce(
            state: state,
            action: action,
            environment: LiveRuntimeEnvironment(bridgeMode: .programQueueOwned)
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
}
