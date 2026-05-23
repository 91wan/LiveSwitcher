import XCTest
@testable import LiveSwitcher

final class HelpCopyModelTests: XCTestCase {
    func testHelpCopyDoesNotReferenceOldGreenLightSemantics() {
        let text = HelpCopyModel.allText

        XCTAssertFalse(text.contains("绿灯"))
        XCTAssertFalse(text.contains("绿色按钮"))
    }

    func testHelpCopyStatesLiveAndPanicRedRiskSemantics() {
        let text = HelpCopyModel.allText

        XCTAssertTrue(text.localizedCaseInsensitiveContains("ON AIR"))
        XCTAssertTrue(text.contains("红色"))
        XCTAssertTrue(text.localizedCaseInsensitiveContains("Panic"))
    }
}
