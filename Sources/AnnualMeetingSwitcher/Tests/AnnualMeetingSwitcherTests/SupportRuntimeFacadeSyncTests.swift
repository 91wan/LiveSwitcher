import XCTest
@testable import LiveSwitcher

@MainActor
final class SupportRuntimeFacadeSyncTests: XCTestCase {
    func testSupportFacadeSyncNoopsBeforeSupportOwnership() {
        let viewModel = makeViewModel(bridgeMode: .automationNoticeOwned)
        let facadeEvent = LiveSupportEvent(
            timestamp: Date(timeIntervalSince1970: 50),
            kind: .projectionStarted,
            detail: "source=facade"
        )
        let runtimeEvent = LiveSupportEvent(
            timestamp: Date(timeIntervalSince1970: 100),
            kind: .appleScriptFailed,
            detail: "source=runtime"
        )
        var state = viewModel.runtime.state
        state.support.events = [runtimeEvent]
        viewModel.runtime.replaceStateForFacadeSync(state, clearActionLog: false)
        viewModel.applySupportEventsProjectionFromRuntime([facadeEvent])

        viewModel.syncSupportFacadeFromRuntime()

        XCTAssertEqual(viewModel.supportEvents, [facadeEvent])
    }

    func testSupportOwnedFacadeSyncMirrorsRuntimeEvents() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)
        var state = viewModel.runtime.state
        state.support.record(kind: .projectionStarted, detail: "source=runtime", at: Date(timeIntervalSince1970: 100))
        viewModel.runtime.replaceStateForFacadeSync(state, clearActionLog: false)

        viewModel.syncSupportFacadeFromRuntime()

        XCTAssertEqual(viewModel.supportEvents, state.support.events)
    }

    func testSupportFacadeSyncProjectsEventsWhenSupportOwned() {
        let viewModel = makeViewModel(bridgeMode: .supportOwned)
        let runtimeEvent = LiveSupportEvent(
            timestamp: Date(timeIntervalSince1970: 100),
            kind: .appleScriptFailed,
            detail: "source=runtime"
        )
        var state = viewModel.runtime.state
        state.support.events = [runtimeEvent]
        viewModel.runtime.replaceStateForFacadeSync(state, clearActionLog: false)

        viewModel.syncSupportFacadeFromRuntime()

        XCTAssertEqual(viewModel.supportEvents, [runtimeEvent])
    }

    func testSupportFacadeSyncPreservesFacadeBeforeSupportOwnership() {
        let viewModel = makeViewModel(bridgeMode: .automationNoticeOwned)
        let existing = LiveSupportEvent(
            timestamp: Date(timeIntervalSince1970: 50),
            kind: .projectionStarted,
            detail: "source=facade"
        )
        viewModel.applySupportEventsProjectionFromRuntime([existing])

        viewModel.syncSupportFacadeFromRuntime()

        XCTAssertEqual(viewModel.supportEvents, [existing])
    }

    func testSupportFacadeSyncUsesSupportOwnershipGuard() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+RuntimeFacadeSync.swift")
        let body = try XCTUnwrap(source.extractedRuntimeFunctionBody(named: "syncSupportFacadeFromRuntime"))

        XCTAssertTrue(body.contains("guard runtime.bridgeMode.owns(.support) else { return }"))
    }

    func testSupportOwnedFacadeSyncPreservesCoalescedCountsAndEventLimit() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)
        var state = viewModel.runtime.state
        state.support.eventLimit = 3
        state.support.record(kind: .appleScriptFailed, detail: "action=keynote.open,error=failed", at: Date(timeIntervalSince1970: 100))
        state.support.record(kind: .appleScriptFailed, detail: "action=keynote.open,error=failed", at: Date(timeIntervalSince1970: 101))
        viewModel.runtime.replaceStateForFacadeSync(state, clearActionLog: false)

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false)

        XCTAssertEqual(viewModel.runtime.state.support.eventLimit, 3)
        XCTAssertEqual(viewModel.runtime.state.support.coalescedCounts, state.support.coalescedCounts)
    }

    func testNonSupportOwnedSnapshotStillMirrorsFacadeEvents() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+RuntimeSnapshot.swift")

        XCTAssertTrue(source.contains("guard !runtime.bridgeMode.owns(.support) else"))
        XCTAssertTrue(source.contains("state.support.events = supportEvents"))
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

    private func makeViewModel(bridgeMode: LiveRuntimeBridgeMode) -> SwitcherViewModel {
        let runtime = LiveRuntimeStore(
            effectRunner: .recording(),
            environment: LiveRuntimeEnvironment(bridgeMode: bridgeMode)
        )
        let suiteName = "SupportRuntimeFacadeSyncTests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
        return SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            userDefaults: userDefaults,
            runtime: runtime
        )
    }
}
