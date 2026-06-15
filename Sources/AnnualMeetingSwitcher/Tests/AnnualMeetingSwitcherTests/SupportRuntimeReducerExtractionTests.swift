import XCTest
@testable import LiveSwitcher

final class SupportRuntimeReducerExtractionTests: XCTestCase {
    func testSupportRuntimeReducerFileExists() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/SupportRuntimeReducer.swift")

        XCTAssertTrue(source.contains("enum SupportRuntimeReducer"))
    }

    func testSupportRuntimeReducerOwnsRecordLogic() throws {
        var state = LiveRuntimeState()
        var effects: [LiveRuntimeEffect] = []
        let event = supportEvent()

        SupportRuntimeReducer.record(event: event, state: &state, effects: &effects)

        let recorded = try XCTUnwrap(state.support.events.first)
        XCTAssertEqual(recorded.kind, event.kind)
        XCTAssertEqual(recorded.detail, event.detail)
        XCTAssertEqual(effects, [.recordSupportEvent(recorded)])
    }

    func testSupportRuntimeReducerOwnsReducerSupportWriteLogic() {
        var state = LiveRuntimeState()

        SupportRuntimeReducer.record(
            kind: .appleScriptFailed,
            detail: "action=keynote.next-slide,error=failed",
            at: Date(timeIntervalSince1970: 100),
            state: &state
        )

        XCTAssertEqual(state.support.events.map(\.kind), [.appleScriptFailed])
    }

    func testLiveRuntimeReducerDelegatesSupportEventRecorded() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeReducer.swift")

        XCTAssertTrue(source.contains("SupportRuntimeReducer.record("))
    }

    func testLiveRuntimeReducerDoesNotContainSupportMutationBody() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeReducer.swift")

        [
            "state.support.record(event:",
            "state.support.record(kind:",
            "effects.append(.recordSupportEvent"
        ].forEach { forbidden in
            XCTAssertFalse(source.contains(forbidden), "LiveRuntimeReducer still owns support mutation body: \(forbidden)")
        }
    }

    private func supportEvent() -> LiveSupportEvent {
        LiveSupportEvent(
            timestamp: Date(timeIntervalSince1970: 100),
            kind: .projectionStarted,
            detail: "source=viewModel"
        )
    }

    private func sourceText(_ relativePath: String) throws -> String {
        try String(contentsOf: repositoryRoot().appendingPathComponent(relativePath), encoding: .utf8)
    }

    private func repositoryRoot() throws -> URL {
        var directory = URL(fileURLWithPath: #filePath)
        while directory.pathComponents.count > 1 {
            directory.deleteLastPathComponent()
            if FileManager.default.fileExists(atPath: directory.appendingPathComponent("docs").path) {
                return directory
            }
        }
        throw XCTSkip("Could not locate repository root from test source path.")
    }
}
