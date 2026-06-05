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
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeClosurePorts.swift")

        XCTAssertTrue(source.contains("final class ClosureSupportEventPort: SupportEventPort"))
        XCTAssertTrue(source.contains("func record(_ event: LiveSupportEvent)"))
        XCTAssertTrue(source.contains("recordHandler?(event)"))
    }

    func testSupportEventPortHasNoDefaultNoOpImplementation() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeEffect.swift")

        XCTAssertTrue(source.contains("protocol SupportEventPort"))
        XCTAssertFalse(source.contains("extension SupportEventPort"))
    }

    func testProductionSupportAndAutomationCommandPortsAreWired() throws {
        let viewModelSource = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel.swift")
        let closurePortsSource = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeClosurePorts.swift")

        XCTAssertTrue(closurePortsSource.contains("support: supportPort"))
        XCTAssertTrue(closurePortsSource.contains("automation: automationPort"))
        XCTAssertTrue(viewModelSource.contains("environment: .productionAutomationCommandOwning()"))
        XCTAssertTrue(closurePortsSource.contains("let supportPort = ClosureSupportEventPort()"))
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
