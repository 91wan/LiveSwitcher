import XCTest
@testable import LiveSwitcher

final class OutputDisplayLossReporterTests: XCTestCase {
    func testSameDisconnectReportsOnlyOnceUntilSuccessfulShowResets() {
        var reporter = OutputDisplayLossReporter()

        XCTAssertTrue(reporter.shouldReportDisplayUnavailable())
        XCTAssertFalse(reporter.shouldReportDisplayUnavailable())

        reporter.resetAfterSuccessfulShow()

        XCTAssertTrue(reporter.shouldReportDisplayUnavailable())
    }

    func testHiddenCorrectionDoesNotReportAfterWindowWasAlreadyHidden() {
        var reporter = OutputDisplayLossReporter()

        XCTAssertFalse(reporter.shouldReportDisplayUnavailable(windowIsVisible: false))

        XCTAssertTrue(reporter.shouldReportDisplayUnavailable(windowIsVisible: true))
        XCTAssertFalse(reporter.shouldReportDisplayUnavailable(windowIsVisible: true))
    }
}
