import XCTest
@testable import LiveSwitcher

final class PreflightPopoverLayoutModelTests: XCTestCase {
    func testPreflightLayoutKeepsRiskReviewBeforeFooterActions() {
        let model = PreflightPopoverLayoutModel.make()

        XCTAssertEqual(model.sections, [.header, .summary, .filter, .checks, .footerActions])
    }

    func testHeaderDoesNotContainReportOrCockpitActions() {
        let model = PreflightPopoverLayoutModel.make()

        XCTAssertTrue(model.headerActions.isEmpty)
        XCTAssertFalse(model.headerActions.contains(.openCockpit))
        XCTAssertFalse(model.headerActions.contains(.copyReport))
        XCTAssertFalse(model.headerActions.contains(.copySupport))
        XCTAssertFalse(model.headerActions.contains(.saveSupport))
    }

    func testFooterContainsPreflightUtilityActions() {
        let model = PreflightPopoverLayoutModel.make()

        XCTAssertEqual(model.footerActions, [.openCockpit, .copyReport, .copySupport, .saveSupport])
    }
}
