import XCTest
@testable import LiveSwitcher

@MainActor
final class SupportRuntimePriorityRetentionTests: XCTestCase {
    func testCriticalEventsSurviveSupportRuntimeOverflow() {
        var state = SupportRuntimeState()
        state.eventLimit = 3

        state.record(kind: .panicModeChanged, detail: "isOn=true", at: Date(timeIntervalSince1970: 100))
        state.record(kind: .systemVolumeSynced, detail: "deviceID=1,volume=0.5", at: Date(timeIntervalSince1970: 101))
        state.record(kind: .mediaRestarted, detail: "source=current", at: Date(timeIntervalSince1970: 102))
        state.record(kind: .pageInterceptEnabled, detail: "state=enabled", at: Date(timeIntervalSince1970: 103))

        XCTAssertTrue(state.events.contains { $0.kind == .panicModeChanged })
        XCTAssertLessThanOrEqual(state.events.count, state.eventLimit)
    }

    func testSupportOwnedSyncPreservesRuntimeEventLimit() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)
        var state = viewModel.runtime.state
        state.support.eventLimit = 4
        viewModel.runtime.replaceStateForFacadeSync(state, clearActionLog: false)

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false)

        XCTAssertEqual(viewModel.runtime.state.support.eventLimit, 4)
    }
}
