import XCTest
@testable import LiveSwitcher

final class SupportRuntimePortContractTests: XCTestCase {
    func testRecordSupportEventRequiresSupportDomain() {
        let event = LiveSupportEvent(
            timestamp: Date(timeIntervalSince1970: 100),
            kind: .pageInterceptEnabled,
            detail: "state=enabled"
        )

        XCTAssertEqual(LiveRuntimeEffect.recordSupportEvent(event).requiredBridgeDomain, .support)
    }

    func testSupportOwnedAllowsRecordSupportEffect() {
        let event = LiveSupportEvent(
            timestamp: Date(timeIntervalSince1970: 100),
            kind: .pageInterceptEnabled,
            detail: "state=enabled"
        )

        let mutation = LiveRuntimeReducer.reduce(
            state: LiveRuntimeState(),
            action: .supportEventRecorded(event),
            environment: LiveRuntimeEnvironment(bridgeMode: .supportOwned)
        )

        XCTAssertTrue(mutation.effects.contains(.recordSupportEvent(event)))
    }

    func testAutomationNoticeOwnedBlocksRecordSupportEffect() {
        let event = LiveSupportEvent(
            timestamp: Date(timeIntervalSince1970: 100),
            kind: .pageInterceptEnabled,
            detail: "state=enabled"
        )

        let mutation = LiveRuntimeReducer.reduce(
            state: LiveRuntimeState(),
            action: .supportEventRecorded(event),
            environment: LiveRuntimeEnvironment(bridgeMode: .automationNoticeOwned)
        )

        XCTAssertFalse(mutation.effects.contains(.recordSupportEvent(event)))
    }

    func testClosureSupportPortExistsAndImplementsRecordWithoutStateMutation() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel.swift")

        XCTAssertTrue(source.contains("private final class ClosureSupportEventPort: SupportEventPort"))
        XCTAssertTrue(source.contains("func record(_ event: LiveSupportEvent)"))
        XCTAssertTrue(source.contains("recordHandler?(event)"))
    }

    func testProductionSupportPortIsWiredAndAutomationPortIsNot() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel.swift")
        let initializer = try XCTUnwrap(source.range(of: "LiveRuntimeEffectRunner("))
        let suffix = source[initializer.lowerBound...]
        let runnerArguments = try XCTUnwrap(suffix.range(of: "\n            ),"))
        let body = String(suffix[..<runnerArguments.lowerBound])

        XCTAssertTrue(body.contains("support: supportPort"))
        XCTAssertFalse(body.contains("automation:"))
        XCTAssertTrue(source.contains("environment: .productionSupportOwning()"))
        XCTAssertTrue(source.contains("let supportPort = ClosureSupportEventPort()"))
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
}
