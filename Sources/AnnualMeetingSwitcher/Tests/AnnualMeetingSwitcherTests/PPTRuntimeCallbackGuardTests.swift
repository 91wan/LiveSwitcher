import XCTest
@testable import LiveSwitcher

final class PPTRuntimeCallbackGuardTests: XCTestCase {
    func testPPTEventTapCallbacksNoopBeforePPTOwnership() {
        let actions: [LiveRuntimeAction] = [
            .pptEventTapStarted,
            .pptEventTapFailed(reason: "permissionDenied"),
            .pptEventTapStopped(reason: .operatorDisabled)
        ]

        for action in actions {
            var state = LiveRuntimeState()
            state.ppt.isRequested = true
            state.ppt.isEventTapActive = false
            state.ppt.lastFailureReason = "existing"
            let originalPPT = state.ppt

            let mutation = LiveRuntimeReducer.reduce(
                state: state,
                action: action,
                environment: .productionProjectionOwned()
            )

            XCTAssertEqual(mutation.state.ppt, originalPPT, "Unexpected PPT mutation for \(action.redactedName)")
            XCTAssertTrue(mutation.effects.isEmpty, "Unexpected PPT effect for \(action.redactedName)")
        }
    }

    func testPPTEventTapCallbacksMutateWhenPPTOwned() {
        let started = reduce(LiveRuntimeState(), .pptEventTapStarted)
        XCTAssertTrue(started.state.ppt.isRequested)
        XCTAssertTrue(started.state.ppt.isEventTapActive)

        let failed = reduce(started.state, .pptEventTapFailed(reason: "permissionDenied"))
        XCTAssertFalse(failed.state.ppt.isRequested)
        XCTAssertFalse(failed.state.ppt.isEventTapActive)
        XCTAssertEqual(failed.state.ppt.lastFailureReason, "permissionDenied")

        let stopped = reduce(started.state, .pptEventTapStopped(reason: .operatorDisabled))
        XCTAssertFalse(stopped.state.ppt.isRequested)
        XCTAssertFalse(stopped.state.ppt.isEventTapActive)
    }

    func testAllPPTCallbackCasesHaveExplicitPPTOwnershipGuard() throws {
        let source = try sourceText(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/Reducers/PanicProjectionRuntimeActionDispatcher.swift"
        )

        [
            "case .pptEventTapStarted:",
            "case .pptEventTapFailed(let reason):",
            "case .pptEventTapStopped(let reason):"
        ].forEach { casePattern in
            guard let range = source.range(of: casePattern) else {
                XCTFail("Missing \(casePattern)")
                return
            }
            let endIndex = source.index(range.lowerBound, offsetBy: 260, limitedBy: source.endIndex) ?? source.endIndex
            let body = String(source[range.lowerBound..<endIndex])
            XCTAssertTrue(
                body.contains("guard LiveRuntimeReducer.isRuntimeOwned(.ppt, in: bridgeMode) else { return true }"),
                "\(casePattern) lacks .ppt guard"
            )
        }
    }

    private func reduce(_ state: LiveRuntimeState, _ action: LiveRuntimeAction) -> LiveRuntimeMutation {
        LiveRuntimeReducer.reduce(
            state: state,
            action: action,
            environment: .productionPPTOwning()
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
