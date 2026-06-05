import XCTest
@testable import LiveSwitcher

@MainActor
final class SupportRuntimeFacadeSyncTests: XCTestCase {
    func testSupportOwnedFacadeSyncMirrorsRuntimeEvents() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)
        var state = viewModel.runtime.state
        state.support.record(kind: .projectionStarted, detail: "source=runtime", at: Date(timeIntervalSince1970: 100))
        viewModel.runtime.replaceStateForFacadeSync(state, clearActionLog: false)

        viewModel.syncSupportFacadeFromRuntime()

        XCTAssertEqual(viewModel.supportEvents, state.support.events)
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
}
