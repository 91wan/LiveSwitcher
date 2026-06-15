import XCTest
@testable import LiveSwitcher

@MainActor
final class SupportRuntimeProductionBoundaryTests: XCTestCase {
    func testProductionRuntimeWiresSupportAndAutomationCommand() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)

        XCTAssertTrue(viewModel.runtimeConnectedPortKinds.contains(.support))
        XCTAssertTrue(viewModel.runtimeConnectedPortKinds.contains(.automation))
    }

    func testProductionSupportEventIngressRecordsThroughRuntimeState() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)

        viewModel.recordSupportEvent(
            kind: .preflightAction,
            detail: "action=manualReview",
            timestamp: Date(timeIntervalSince1970: 100)
        )

        XCTAssertFalse(viewModel.runtime.actionLog.contains { $0.actionName == "supportEventRecorded" })
        XCTAssertEqual(viewModel.supportEvents, viewModel.runtime.state.support.events)
    }

    func testAutomationNoticeOwnedBoundaryStillBlocksSupportPortEffect() {
        let event = LiveSupportEvent(
            timestamp: Date(timeIntervalSince1970: 100),
            kind: .preflightAction,
            detail: "action=manualReview"
        )

        let mutation = LiveRuntimeReducer.reduce(
            state: LiveRuntimeState(),
            action: .supportEventRecorded(event),
            environment: .productionAutomationNoticeOwning(now: Date(timeIntervalSince1970: 100))
        )

        XCTAssertFalse(mutation.effects.contains(.recordSupportEvent(event)))
    }

    func testProductionViewModelRuntimeBridgeModeRemainsPanicOwned() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)

        XCTAssertEqual(viewModel.runtimeBridgeMode, .panicOwned)
    }

    func testProductionConnectedPortsRemainPanicOwnedSet() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)

        XCTAssertEqual(
            viewModel.runtimeConnectedPortKinds,
            [
                .media,
                .bgm,
                .bgmTimer,
                .panicDelay,
                .projection,
                .ppt,
                .automationNotice,
                .support,
                .automation,
                .presentationQuery,
                .programActivation,
                .audioRouting,
                .imageAssets,
                .persistence
            ]
        )
    }

    func testNoNewSupportBridgeModeAdded() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeAction.swift")

        XCTAssertFalse(source.contains("supportIngressOwned"))
        XCTAssertFalse(source.contains("supportProjectionOwned"))
    }

    func testNoNewSupportPortAdded() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimePorts.swift")

        XCTAssertFalse(source.contains("supportIngress"))
        XCTAssertFalse(source.contains("supportProjection"))
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
