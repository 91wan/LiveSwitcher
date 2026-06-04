import XCTest
@testable import LiveSwitcher

@MainActor
final class PPTRuntimeOwnershipTests: XCTestCase {
    func testSetPPTModeOnUsesRuntimePort() {
        let ppt = PPTRuntimeOwnershipPPTPortSpy()
        let viewModel = makeViewModel(ppt: ppt)

        viewModel.setPPTMode(true, source: .liveMode)

        XCTAssertEqual(ppt.calls, ["start"])
        XCTAssertTrue(viewModel.runtime.recordedEffects.contains(.startPPTEventTap))
    }

    func testSetPPTModeOffUsesRuntimePort() {
        let ppt = PPTRuntimeOwnershipPPTPortSpy()
        let viewModel = makeViewModel(ppt: ppt)
        viewModel.dispatchRuntimeFacadeAction(.pptEventTapStarted)

        viewModel.setPPTMode(false, source: .liveMode)

        XCTAssertEqual(ppt.calls, ["stop:operatorDisabled"])
        XCTAssertTrue(viewModel.runtime.recordedEffects.contains(.stopPPTEventTap(reason: .operatorDisabled)))
    }

    func testTogglePPTModeUsesRuntimeState() {
        let ppt = PPTRuntimeOwnershipPPTPortSpy()
        let viewModel = makeViewModel(ppt: ppt)
        viewModel.runtime.dispatch(.pptEventTapStarted)
        viewModel.syncPPTFacadeFromRuntime()

        viewModel.togglePPTMode(source: .command)

        XCTAssertEqual(ppt.calls, ["stop:operatorDisabled"])
    }

    func testSetPPTModeDoesNotDirectlySetIsPageInterceptEnabled() throws {
        let body = try functionBody(named: "setPPTMode")

        XCTAssertFalse(body.contains("isPageInterceptEnabled = enabled"))
    }

    func testSetPPTModeDoesNotDirectlyCallStartPageIntercept() throws {
        let body = try functionBody(named: "setPPTMode")

        XCTAssertFalse(body.contains("requestPageInterceptStartForModeToggle"))
        XCTAssertFalse(body.contains("startPageIntercept"))
    }

    func testSetPPTModeDoesNotRecordSuccessBeforeCallback() {
        let ppt = PPTRuntimeOwnershipPPTPortSpy()
        let viewModel = makeViewModel(ppt: ppt)

        viewModel.setPPTMode(true, source: .liveMode)

        XCTAssertFalse(viewModel.supportEvents.contains { $0.kind == .pptModeChanged && $0.detail.contains("isOn=true") })
        XCTAssertFalse(viewModel.supportEvents.contains { $0.kind == .pageInterceptEnabled })
    }

    func testDuplicateSetPPTModeOnNoopsWhenAlreadyRequestedOrActive() {
        let ppt = PPTRuntimeOwnershipPPTPortSpy()
        let viewModel = makeViewModel(ppt: ppt)

        viewModel.setPPTMode(true, source: .liveMode)
        viewModel.setPPTMode(true, source: .liveMode)

        XCTAssertEqual(ppt.calls, ["start"])
    }

    func testDuplicateSetPPTModeOffNoopsWhenAlreadyOff() {
        let ppt = PPTRuntimeOwnershipPPTPortSpy()
        let viewModel = makeViewModel(ppt: ppt)

        viewModel.setPPTMode(false, source: .liveMode)

        XCTAssertTrue(ppt.calls.isEmpty)
    }

    private func makeViewModel(ppt: PPTRuntimeOwnershipPPTPortSpy) -> SwitcherViewModel {
        let runtime = LiveRuntimeStore(
            effectRunner: LiveRuntimeEffectRunner(recordsOnly: false, ppt: ppt),
            environment: .productionPPTOwning()
        )
        return SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            runtime: runtime
        )
    }

    private func functionBody(named name: String) throws -> String {
        let source = try sourceText("ViewModel.swift")
        guard let start = source.range(of: "func \(name)")?.lowerBound else {
            XCTFail("Missing function \(name)")
            return ""
        }
        var index = start
        var depth = 0
        var hasOpened = false
        while index < source.endIndex {
            let character = source[index]
            if character == "{" {
                depth += 1
                hasOpened = true
            } else if character == "}" {
                depth -= 1
                if hasOpened && depth == 0 {
                    return String(source[start...index])
                }
            }
            index = source.index(after: index)
        }
        XCTFail("Could not parse \(name)")
        return ""
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

private final class PPTRuntimeOwnershipPPTPortSpy: PPTEventTapPort {
    private(set) var calls: [String] = []

    func start() {
        calls.append("start")
    }

    func stop(reason: PPTStopReason) {
        calls.append("stop:\(reason.rawValue)")
    }
}
