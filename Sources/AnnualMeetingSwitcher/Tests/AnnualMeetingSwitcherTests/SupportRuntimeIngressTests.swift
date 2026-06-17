import XCTest
@testable import LiveSwitcher

final class SupportRuntimeIngressTests: XCTestCase {
    func testSupportEventRecordedWritesRuntimeSupportState() throws {
        let event = supportEvent()

        let mutation = reduce(.supportEventRecorded(event), bridgeMode: .supportOwned)

        let recorded = try XCTUnwrap(mutation.state.support.events.first)
        XCTAssertEqual(recorded.kind, event.kind)
        XCTAssertEqual(recorded.detail, event.detail)
    }

    func testSupportEventRecordedEmitsAcceptedRecordSupportEffectWhenSupportOwned() {
        let event = supportEvent()

        let mutation = reduce(.supportEventRecorded(event), bridgeMode: .supportOwned)

        XCTAssertEqual(mutation.effects, mutation.state.support.events.map(LiveRuntimeEffect.recordSupportEvent))
    }

    func testAutomationNoticeOwnedStillBlocksRecordSupportEffect() {
        let event = supportEvent()

        let mutation = reduce(.supportEventRecorded(event), bridgeMode: .automationNoticeOwned)

        XCTAssertFalse(mutation.effects.contains(.recordSupportEvent(event)))
    }

    func testRecordSupportEventDispatchesRuntimeSupportEventRecorded() throws {
        let body = try viewModelFunctionBody(named: "func recordSupportEvent")

        XCTAssertTrue(body.contains("dispatchRuntimeFacadeAction(.supportEventRecorded(event))"))
    }

    func testRecordSupportEventReliesOnRuntimeFacadeSyncPolicy() throws {
        let body = try viewModelFunctionBody(named: "func recordSupportEvent")

        XCTAssertFalse(body.contains("syncSupportFacadeFromRuntime()"))
        XCTAssertTrue(LiveRuntimeFacadeSyncPolicy.options(for: .supportEventRecorded(supportEvent())).syncSupport)
    }

    func testRecordSupportEventDoesNotAppendSupportEventsDirectly() throws {
        let body = try viewModelFunctionBody(named: "func recordSupportEvent")

        XCTAssertFalse(body.contains("supportEvents.append"))
        XCTAssertFalse(body.contains("supportEvents = runtime.state.support.events"))
    }

    func testRecordSupportEventDoesNotRunRedactionOrTrimLocally() throws {
        let body = try viewModelFunctionBody(named: "func recordSupportEvent")

        XCTAssertFalse(body.contains("LiveSupportRedactor"))
        XCTAssertFalse(body.contains("safeEventDetail"))
        XCTAssertFalse(body.contains("eventLimit"))
        XCTAssertFalse(body.contains("removeFirst"))
    }

    private func supportEvent() -> LiveSupportEvent {
        LiveSupportEvent(
            timestamp: Date(timeIntervalSince1970: 100),
            kind: .appleScriptFailed,
            detail: "action=keynote.next-slide,error=failed"
        )
    }

    private func reduce(
        _ action: LiveRuntimeAction,
        bridgeMode: LiveRuntimeBridgeMode
    ) -> LiveRuntimeMutation {
        LiveRuntimeReducer.reduce(
            state: LiveRuntimeState(),
            action: action,
            environment: LiveRuntimeEnvironment(now: Date(timeIntervalSince1970: 100), bridgeMode: bridgeMode)
        )
    }

    private func viewModelFunctionBody(named marker: String) throws -> String {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+SupportFacade.swift")
        guard let markerRange = source.range(of: marker) else {
            XCTFail("Missing \(marker)")
            return ""
        }
        let suffix = source[markerRange.lowerBound...]
        guard let nextMark = suffix.range(of: "\n    // MARK:", options: [], range: suffix.index(after: suffix.startIndex)..<suffix.endIndex) else {
            return String(suffix)
        }
        return String(suffix[..<nextMark.lowerBound])
    }
}

private func sourceText(_ relativePath: String) throws -> String {
    var directory = URL(fileURLWithPath: #filePath)
    while directory.pathComponents.count > 1 {
        directory.deleteLastPathComponent()
        let candidate = directory.appendingPathComponent(relativePath)
        if FileManager.default.fileExists(atPath: candidate.path) {
            return try String(contentsOf: candidate)
        }
    }
    throw XCTSkip("Could not locate \(relativePath) from test source path.")
}
