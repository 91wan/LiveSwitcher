import XCTest
@testable import LiveSwitcher

final class PreflightHeaderBadgeModelTests: XCTestCase {
    func testPassingPreflightDoesNotShowDefaultHeaderBadge() {
        let model = PreflightHeaderBadgeModel.make(summary: summary(.pass))

        XCTAssertEqual(model.text, "Preflight")
        XCTAssertEqual(model.kind, .ready)
        XCTAssertFalse(model.isVisible)
    }

    func testWarnAndFailPreflightRemainVisibleInHeader() {
        let warn = PreflightHeaderBadgeModel.make(summary: summary(.warn))
        let fail = PreflightHeaderBadgeModel.make(summary: summary(.fail))

        XCTAssertEqual(warn.kind, .warn)
        XCTAssertTrue(warn.isVisible)
        XCTAssertEqual(fail.kind, .fail)
        XCTAssertTrue(fail.isVisible)
    }

    private func summary(_ status: LivePreflightStatus) -> LivePreflightSummary {
        switch status {
        case .pass:
            return LivePreflightSummary(status: .pass, title: "Ready", message: "", passCount: 3, warnCount: 0, failCount: 0)
        case .warn:
            return LivePreflightSummary(status: .warn, title: "Needs review", message: "", passCount: 2, warnCount: 1, failCount: 0)
        case .fail:
            return LivePreflightSummary(status: .fail, title: "Not ready", message: "", passCount: 2, warnCount: 0, failCount: 1)
        }
    }
}
