import XCTest
@testable import LiveSwitcher

@MainActor
final class SupportRuntimePriorityRetentionTests: XCTestCase {
    func testCriticalEventsSurviveSupportRuntimeOverflow() {
        var state = SupportRuntimeState()
        state.eventLimit = 3

        let critical = state.record(kind: .panicModeChanged, detail: "isOn=true", at: Date(timeIntervalSince1970: 100))
        state.record(kind: .systemVolumeSynced, detail: "deviceID=1,volume=0.5", at: Date(timeIntervalSince1970: 101))
        state.record(kind: .mediaRestarted, detail: "source=current", at: Date(timeIntervalSince1970: 102))
        state.record(kind: .pageInterceptEnabled, detail: "state=enabled", at: Date(timeIntervalSince1970: 103))

        XCTAssertNotNil(critical)
        XCTAssertTrue(state.events.contains { $0.kind == .panicModeChanged })
        XCTAssertLessThanOrEqual(state.events.count, state.eventLimit)
    }

    func testLowPriorityEventReturnsNilWhenCriticalEventOccupiesFullLimit() {
        var state = SupportRuntimeState()
        state.eventLimit = 1
        state.record(kind: .projectionLost, detail: "externalDisplay=false", at: Date(timeIntervalSince1970: 100))

        let accepted = state.record(kind: .systemVolumeSynced, detail: "deviceID=1,volume=0.5", at: Date(timeIntervalSince1970: 101))

        XCTAssertNil(accepted)
        XCTAssertEqual(state.events.map(\.kind), [.projectionLost])
    }

    func testLowPriorityFloodDoesNotEvictPanicEvent() {
        var state = SupportRuntimeState()
        state.eventLimit = 2
        state.record(kind: .panicModeChanged, detail: "isOn=true", at: Date(timeIntervalSince1970: 100))

        for index in 0..<100 {
            state.record(
                kind: .systemVolumeSynced,
                detail: "deviceID=\(index),volume=0.5",
                at: Date(timeIntervalSince1970: TimeInterval(101 + index))
            )
        }

        XCTAssertTrue(state.events.contains { $0.kind == .panicModeChanged })
        XCTAssertLessThanOrEqual(state.events.count, state.eventLimit)
    }

    func testLowPriorityFloodDoesNotEvictProjectionLostEvent() {
        var state = SupportRuntimeState()
        state.eventLimit = 2
        state.record(kind: .projectionLost, detail: "externalDisplay=false", at: Date(timeIntervalSince1970: 100))

        for index in 0..<100 {
            state.record(
                kind: .systemVolumeSynced,
                detail: "deviceID=\(index),volume=0.5",
                at: Date(timeIntervalSince1970: TimeInterval(101 + index))
            )
        }

        XCTAssertTrue(state.events.contains { $0.kind == .projectionLost })
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
