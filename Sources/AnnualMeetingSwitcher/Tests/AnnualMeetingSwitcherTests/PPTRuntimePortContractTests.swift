import XCTest
@testable import LiveSwitcher

@MainActor
final class PPTRuntimePortContractTests: XCTestCase {
    func testStartPPTEventTapEffectCallsPPTPortStart() {
        let ppt = PPTRuntimePortContractSpy()
        let runner = LiveRuntimeEffectRunner(recordsOnly: false, ppt: ppt)

        runner.run([.startPPTEventTap], currentState: { LiveRuntimeState() }, dispatch: { _ in })

        XCTAssertEqual(ppt.calls, ["start"])
    }

    func testStopPPTEventTapEffectCallsPPTPortStopWithReason() {
        let ppt = PPTRuntimePortContractSpy()
        let runner = LiveRuntimeEffectRunner(recordsOnly: false, ppt: ppt)

        runner.run([.stopPPTEventTap(reason: .operatorDisabled)], currentState: { LiveRuntimeState() }, dispatch: { _ in })

        XCTAssertEqual(ppt.calls, ["stop:operatorDisabled"])
    }

    func testProductionRuntimeWiresPPTPort() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)

        XCTAssertTrue(viewModel.runtimeConnectedPortKinds.contains(.ppt))
    }

    func testProductionRuntimeWiresAutomationNoticeSupportAndAutomationCommandExecution() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)

        XCTAssertTrue(viewModel.runtimeConnectedPortKinds.contains(.automationNotice))
        XCTAssertTrue(viewModel.runtimeConnectedPortKinds.contains(.support))
        XCTAssertTrue(viewModel.runtimeConnectedPortKinds.contains(.automation))
    }

    func testPPTEventTapPortHasNoDefaultNoOpImplementation() throws {
        let source = try sourceText("Runtime/LiveRuntimeEffect.swift")

        XCTAssertTrue(source.contains("protocol PPTEventTapPort"))
        XCTAssertFalse(source.contains("extension PPTEventTapPort"))
    }

    private func sourceText(_ relativePath: String) throws -> String {
        try String(contentsOf: sourceURL(relativePath), encoding: .utf8)
    }

    private func sourceURL(_ relativePath: String) throws -> URL {
        var directory = URL(fileURLWithPath: #filePath)
        while directory.pathComponents.count > 1 {
            directory.deleteLastPathComponent()
            let candidate = directory
                .appendingPathComponent("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher")
                .appendingPathComponent(relativePath)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        throw XCTSkip("Could not locate \(relativePath) from test source path.")
    }
}

private final class PPTRuntimePortContractSpy: PPTEventTapPort {
    private(set) var calls: [String] = []

    func start() {
        calls.append("start")
    }

    func stop(reason: PPTStopReason) {
        calls.append("stop:\(reason.rawValue)")
    }
}
