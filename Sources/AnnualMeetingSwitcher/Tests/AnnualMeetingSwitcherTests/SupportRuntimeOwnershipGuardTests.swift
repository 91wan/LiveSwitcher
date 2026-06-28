import XCTest
@testable import LiveSwitcher

final class SupportRuntimeOwnershipGuardTests: XCTestCase {
    func testSupportEventRecordedNoopsBeforeSupportOwnership() {
        let state = guardedState()
        let mutation = reduce(state, .supportEventRecorded(supportEvent()), bridgeMode: .automationNoticeOwned)

        XCTAssertEqual(mutation.state.support, state.support)
        XCTAssertTrue(mutation.effects.isEmpty)
    }

    func testSupportEventRecordedDoesNotMutateSupportBeforeSupportOwnership() {
        let mutation = reduce(.supportEventRecorded(supportEvent()), bridgeMode: .automationNoticeOwned)

        XCTAssertTrue(mutation.state.support.events.isEmpty)
    }

    func testSupportEventRecordedDoesNotEmitRecordSupportEffectBeforeSupportOwnership() {
        let mutation = reduce(.supportEventRecorded(supportEvent()), bridgeMode: .automationNoticeOwned)

        XCTAssertFalse(mutation.effects.contains { effect in
            if case .recordSupportEvent = effect { return true }
            return false
        })
    }

    func testSupportEventRecordedMutatesWhenSupportOwned() {
        let mutation = reduce(.supportEventRecorded(supportEvent()), bridgeMode: .supportOwned)

        XCTAssertEqual(mutation.state.support.events.map(\.kind), [.projectionStarted])
    }

    func testSupportEventRecordedEmitsRecordSupportEffectWhenSupportOwned() {
        let mutation = reduce(.supportEventRecorded(supportEvent()), bridgeMode: .supportOwned)

        XCTAssertEqual(mutation.effects, mutation.state.support.events.map(LiveRuntimeEffect.recordSupportEvent))
    }

    func testProductionPanicOwnedSupportEventRecordedMutatesSupport() {
        let mutation = reduce(.supportEventRecorded(supportEvent()), bridgeMode: .panicOwned)

        XCTAssertEqual(mutation.state.support.events.map(\.kind), [.projectionStarted])
    }

    func testAllSupportCasesHaveExplicitSupportOwnershipGuard() throws {
        let source = try sourceText(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/Reducers/SupportRuntimeActionDispatcher.swift"
        )
        let casePattern = "case .supportEventRecorded(let event):"

        guard let range = source.range(of: casePattern) else {
            return XCTFail("Missing \(casePattern)")
        }
        let endIndex = source.index(range.lowerBound, offsetBy: 260, limitedBy: source.endIndex) ?? source.endIndex
        let body = String(source[range.lowerBound..<endIndex])

        XCTAssertTrue(body.contains("guard LiveRuntimeReducer.isRuntimeOwned(.support, in: bridgeMode) else { return true }"))
    }

    private func guardedState() -> LiveRuntimeState {
        var state = LiveRuntimeState()
        _ = state.support.record(
            kind: .panicModeChanged,
            detail: "isOn=true",
            at: Date(timeIntervalSince1970: 90)
        )
        return state
    }

    private func supportEvent() -> LiveSupportEvent {
        LiveSupportEvent(
            timestamp: Date(timeIntervalSince1970: 100),
            kind: .projectionStarted,
            detail: "source=viewModel"
        )
    }

    private func reduce(
        _ action: LiveRuntimeAction,
        bridgeMode: LiveRuntimeBridgeMode
    ) -> LiveRuntimeMutation {
        reduce(LiveRuntimeState(), action, bridgeMode: bridgeMode)
    }

    private func reduce(
        _ state: LiveRuntimeState,
        _ action: LiveRuntimeAction,
        bridgeMode: LiveRuntimeBridgeMode
    ) -> LiveRuntimeMutation {
        LiveRuntimeReducer.reduce(
            state: state,
            action: action,
            environment: LiveRuntimeEnvironment(now: Date(timeIntervalSince1970: 100), bridgeMode: bridgeMode)
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
