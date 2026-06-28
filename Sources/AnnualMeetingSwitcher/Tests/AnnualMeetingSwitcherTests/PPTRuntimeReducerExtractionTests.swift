import XCTest
@testable import LiveSwitcher

final class PPTRuntimeReducerExtractionTests: XCTestCase {
    func testPPTRuntimeReducerOwnsSetModeLogic() {
        var state = LiveRuntimeState()
        var effects: [LiveRuntimeEffect] = []

        PPTRuntimeReducer.setMode(
            true,
            source: .liveMode,
            state: &state,
            effects: &effects
        )

        XCTAssertTrue(state.ppt.isRequested)
        XCTAssertFalse(state.ppt.isEventTapActive)
        XCTAssertNil(state.ppt.lastFailureReason)
        XCTAssertEqual(effects, [.startPPTEventTap])
    }

    func testPPTRuntimeReducerOwnsCallbackLogic() {
        var state = LiveRuntimeState()

        PPTRuntimeReducer.eventTapStarted(state: &state)
        XCTAssertTrue(state.ppt.isRequested)
        XCTAssertTrue(state.ppt.isEventTapActive)

        PPTRuntimeReducer.eventTapFailed(reason: "permissionDenied", state: &state)
        XCTAssertFalse(state.ppt.isRequested)
        XCTAssertFalse(state.ppt.isEventTapActive)
        XCTAssertEqual(state.ppt.lastFailureReason, "permissionDenied")

        PPTRuntimeReducer.eventTapStopped(reason: .operatorDisabled, state: &state)
        XCTAssertFalse(state.ppt.isRequested)
        XCTAssertFalse(state.ppt.isEventTapActive)
    }

    func testLiveRuntimeReducerDelegatesPPTActionsAndDoesNotOwnMutationBodies() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/Reducers/PanicProjectionRuntimeActionDispatcher.swift")
        let reducerSource = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/PPTRuntimeReducer.swift")

        XCTAssertTrue(reducerSource.contains("enum PPTRuntimeReducer"))
        XCTAssertTrue(source.contains("PPTRuntimeReducer.toggleMode("))
        XCTAssertTrue(source.contains("PPTRuntimeReducer.setMode("))
        XCTAssertTrue(source.contains("PPTRuntimeReducer.eventTapStarted("))
        XCTAssertTrue(source.contains("PPTRuntimeReducer.eventTapFailed("))
        XCTAssertTrue(source.contains("PPTRuntimeReducer.eventTapStopped("))

        [
            "state.ppt.isRequested =",
            "state.ppt.isEventTapActive =",
            "state.ppt.lastFailureReason =",
            "effects.append(.startPPTEventTap)",
            "effects.append(.stopPPTEventTap",
            "private static func reducePPTModeSet"
        ].forEach { forbidden in
            XCTAssertFalse(source.contains(forbidden), "LiveRuntimeReducer still contains PPT mutation body: \(forbidden)")
        }
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
