import XCTest
@testable import LiveSwitcher

@MainActor
final class LivePreflightSummaryTests: XCTestCase {
    func testSummaryFailsWhenAnyCheckFails() {
        var snapshot = livePreflightReadySnapshot()
        snapshot.hasExternalDisplay = false
        snapshot.isBroadcasting = false

        let summary = LivePreflightSummary.make(from: LivePreflightCheck.build(from: snapshot))

        XCTAssertEqual(summary.status, .fail)
        XCTAssertEqual(summary.title, "未就绪")
        XCTAssertEqual(summary.failCount, 1)
        XCTAssertGreaterThan(summary.warnCount, 0)
    }

    func testSummaryWarnsWhenChecksHaveWarningsButNoFailures() {
        var snapshot = livePreflightReadySnapshot()
        snapshot.autoPlayNextVideoOnEnd = true

        let summary = LivePreflightSummary.make(from: LivePreflightCheck.build(from: snapshot))

        XCTAssertEqual(summary.status, .warn)
        XCTAssertEqual(summary.title, "需复核")
        XCTAssertEqual(summary.failCount, 0)
        XCTAssertGreaterThan(summary.warnCount, 0)
    }

    func testSummaryPassesWhenAllChecksPass() {
        let summary = LivePreflightSummary.make(from: LivePreflightCheck.build(from: livePreflightReadySnapshot()))

        XCTAssertEqual(summary.status, .pass)
        XCTAssertEqual(summary.title, "就绪")
        XCTAssertEqual(summary.failCount, 0)
        XCTAssertEqual(summary.warnCount, 0)
        XCTAssertGreaterThan(summary.passCount, 0)
    }

    func testAttentionChecksOnlyReturnsWarningsAndFailures() {
        var snapshot = livePreflightReadySnapshot()
        snapshot.hasExternalDisplay = false
        snapshot.autoPlayNextVideoOnEnd = true

        let checks = LivePreflightCheck.build(from: snapshot)
        let attentionChecks = LivePreflightCheck.attentionChecks(from: checks)

        XCTAssertFalse(attentionChecks.isEmpty)
        XCTAssertTrue(attentionChecks.allSatisfy { $0.status != .pass })
        XCTAssertTrue(attentionChecks.contains { $0.id == "display.external" && $0.status == .fail })
        XCTAssertTrue(attentionChecks.contains { $0.id == "playback.auto-next" && $0.status == .warn })
        XCTAssertFalse(attentionChecks.contains { $0.id == "audio.volumes" })
    }

    func testAttentionChecksEmptyWhenReadySnapshotHasNoWarningsOrFailures() {
        let checks = LivePreflightCheck.build(from: livePreflightReadySnapshot())
        let attentionChecks = LivePreflightCheck.attentionChecks(from: checks)
        let summary = LivePreflightSummary.make(from: checks)

        XCTAssertEqual(summary.status, .pass)
        XCTAssertTrue(attentionChecks.isEmpty)
    }

    func testSafetyCockpitOrdersFailWarnPassChecksForOperatorAttention() {
        var snapshot = livePreflightReadySnapshot()
        snapshot.hasExternalDisplay = false
        snapshot.isBroadcasting = false
        snapshot.autoPlayNextVideoOnEnd = true
        let checks = LivePreflightCheck.build(from: snapshot)

        let cockpit = LiveSafetyCockpit.make(
            snapshot: snapshot,
            checks: checks,
            events: []
        )

        XCTAssertEqual(cockpit.summary.status, .fail)
        XCTAssertEqual(cockpit.priorityChecks.first?.status, .fail)
        XCTAssertEqual(cockpit.priorityChecks.first?.id, "display.external")
        XCTAssertTrue(cockpit.priorityChecks.dropFirst().contains { $0.status == .warn })
        XCTAssertLessThan(
            cockpit.priorityChecks.firstIndex { $0.status == .warn } ?? Int.max,
            cockpit.priorityChecks.firstIndex { $0.status == .pass } ?? Int.max
        )
    }
}
