import XCTest
@testable import LiveSwitcher

final class HelpCopyModelTests: XCTestCase {
    func testHelpCopyDoesNotReferenceOldGreenLightSemantics() {
        let text = HelpCopyModel.allText

        XCTAssertFalse(text.contains("绿灯"))
        XCTAssertFalse(text.contains("绿色按钮"))
    }

    func testHelpCopyStatesLiveAndEmergencyBlackoutRedRiskSemantics() {
        let text = HelpCopyModel.allText

        XCTAssertTrue(text.contains("直播"))
        XCTAssertTrue(text.contains("红色"))
        XCTAssertTrue(text.contains("紧急切黑"))
        XCTAssertFalse(text.contains("老板键"))
    }

    func testHelpCopyMatchesCurrentRunDeskInformationArchitecture() {
        let text = HelpCopyModel.allText

        XCTAssertFalse(text.contains("左侧底部"))
        XCTAssertFalse(text.contains("投射：关/开"))
        XCTAssertFalse(text.contains("查看列表"))
        XCTAssertFalse(text.contains("Live Ops"))
        XCTAssertFalse(text.contains("Output"))
        XCTAssertFalse(text.contains("BGM Library"))
        XCTAssertFalse(text.contains("Overlay Composer"))
        XCTAssertTrue(text.contains("现场控制"))
        XCTAssertTrue(text.contains("输出卡片"))
        XCTAssertTrue(text.contains("BGM 库"))
        XCTAssertTrue(text.contains("叠层字幕页面"))
    }
}
