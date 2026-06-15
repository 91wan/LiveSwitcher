import XCTest
@testable import LiveSwitcher

final class ProjectionRuntimeReducerExtractionTests: XCTestCase {
    func testProjectionRuntimeReducerOwnsToggleMutation() {
        var state = LiveRuntimeState()
        state.projection.hasExternalDisplay = true
        var effects: [LiveRuntimeEffect] = []

        ProjectionRuntimeReducer.toggleProjection(
            state: &state,
            effects: &effects,
            canWriteSupport: true,
            now: Date(timeIntervalSince1970: 100)
        )

        XCTAssertTrue(state.projection.isBroadcasting)
        XCTAssertEqual(effects, [.startProjection])
        XCTAssertTrue(state.support.events.contains { $0.kind == .projectionStarted })
    }

    func testLiveRuntimeReducerRoutesProjectionActionsInsteadOfOwningMutationBodies() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeReducer.swift")
        let reducerSource = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/ProjectionRuntimeReducer.swift")

        XCTAssertTrue(source.contains("ProjectionRuntimeReducer.toggleProjection("))
        XCTAssertTrue(source.contains("ProjectionRuntimeReducer.startFailed("))
        XCTAssertTrue(source.contains("ProjectionRuntimeReducer.externalDisplayLost("))
        XCTAssertTrue(source.contains("ProjectionRuntimeReducer.externalDisplayAvailable("))
        XCTAssertTrue(source.contains("ProjectionRuntimeReducer.externalDisplayUnavailable("))
        XCTAssertTrue(reducerSource.contains("enum ProjectionRuntimeReducer"))

        [
            "state.projection.isBroadcasting =",
            "state.projection.hasExternalDisplay =",
            "state.projection.safetyNotice =",
            "state.projection.lastDisplayLostAt =",
            "effects.append(.startProjection)",
            "effects.append(.stopProjection)",
            "state.support.record(kind: .projection"
        ].forEach { forbidden in
            XCTAssertFalse(source.contains(forbidden), "LiveRuntimeReducer still contains projection mutation: \(forbidden)")
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
