import XCTest
@testable import LiveSwitcher

final class ProgramQueueRuntimeReducerExtractionTests: XCTestCase {
    func testProgramQueueRuntimeReducerFileExists() {
        XCTAssertTrue(FileManager.default.fileExists(atPath: runtimeFile("ProgramQueueRuntimeReducer.swift")))
    }

    func testProgramQueueRuntimeReducerOwnsProgramQueueMutationRouting() throws {
        guard FileManager.default.fileExists(atPath: runtimeFile("ProgramQueueRuntimeReducer.swift")) else {
            XCTFail("ProgramQueueRuntimeReducer.swift is missing")
            return
        }
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/ProgramQueueRuntimeReducer.swift")

        for expected in [
            "static func addProgramItems",
            "state.program.appendProgramItems(items)",
            "static func removeProgramItem",
            "state.program.removeProgramItem(id: id)",
            "static func moveProgramItems",
            "state.program.moveProgramItems(fromOffsets: fromOffsets, toOffset: toOffset)",
            "static func updateProgramItemSchedule",
            "state.program.updateProgramItemSchedule(",
            "static func addAgendaMarker",
            "state.program.appendAgendaMarker(input: input)",
            "static func updateAgendaMarker",
            "state.program.updateAgendaMarker(id: id, input: input)",
            "static func loadProgramQueueFromFacade",
            "state.program.replaceProgramQueueFromFacade(items)"
        ] {
            XCTAssertTrue(source.contains(expected), expected)
        }
    }

    func testLiveRuntimeReducerDelegatesProgramQueueActions() throws {
        let source = try sourceText(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/Reducers/ProgramRuntimeActionDispatcher.swift"
        )

        for expected in [
            "ProgramQueueRuntimeReducer.addProgramItems(items, state: &state)",
            "ProgramQueueRuntimeReducer.removeProgramItem(id: id, state: &state)",
            "ProgramQueueRuntimeReducer.moveProgramItems(fromOffsets: fromOffsets, toOffset: toOffset, state: &state)",
            "ProgramQueueRuntimeReducer.updateProgramItemSchedule(",
            "ProgramQueueRuntimeReducer.addAgendaMarker(input: input, state: &state)",
            "ProgramQueueRuntimeReducer.updateAgendaMarker(id: id, input: input, state: &state)",
            "ProgramQueueRuntimeReducer.loadProgramQueueFromFacade(items, state: &state)"
        ] {
            XCTAssertTrue(source.contains(expected), expected)
        }
    }

    func testLiveRuntimeReducerDoesNotContainProgramQueueMutationCalls() throws {
        let source = try sourceText(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/Reducers/ProgramRuntimeActionDispatcher.swift"
        )

        for forbidden in [
            "state.program.appendProgramItems(",
            "state.program.removeProgramItem(",
            "state.program.moveProgramItems(",
            "state.program.updateProgramItemSchedule(",
            "state.program.appendAgendaMarker(",
            "state.program.replaceProgramQueueFromFacade("
        ] {
            XCTAssertFalse(source.contains(forbidden), forbidden)
        }
    }

    private func runtimeFile(_ name: String) -> String {
        let tests = URL(fileURLWithPath: #filePath)
        return tests
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/AnnualMeetingSwitcher/Runtime/\(name)")
            .path
    }
}
