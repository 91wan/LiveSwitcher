import XCTest
@testable import LiveSwitcher

final class HelpCopyModelTests: XCTestCase {
    func testHelpCopyDoesNotReferenceOldGreenLightSemantics() {
        let text = HelpCopyModel.allText

        XCTAssertFalse(text.contains("绿灯"))
        XCTAssertFalse(text.contains("绿色按钮"))
    }

    func testHelpCopyStatesLiveAndBlackoutRedRiskSemantics() {
        let text = HelpCopyModel.allText

        XCTAssertTrue(text.localizedCaseInsensitiveContains("ON AIR"))
        XCTAssertTrue(text.contains("红色"))
        XCTAssertTrue(text.localizedCaseInsensitiveContains("Blackout"))
        XCTAssertFalse(text.contains("老板键"))
    }

    func testHelpCopyMatchesCurrentRunDeskInformationArchitecture() {
        let text = HelpCopyModel.allText

        XCTAssertFalse(text.contains("左侧底部"))
        XCTAssertFalse(text.contains("投射：关/开"))
        XCTAssertFalse(text.contains("查看列表"))
        XCTAssertTrue(text.contains("Live Ops"))
        XCTAssertTrue(text.contains("Output"))
        XCTAssertTrue(text.contains("BGM Library"))
        XCTAssertTrue(text.contains("Overlay Composer"))
    }
}
