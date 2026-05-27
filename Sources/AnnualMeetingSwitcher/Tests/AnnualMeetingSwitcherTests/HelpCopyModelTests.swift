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
        XCTAssertTrue(text.contains("暂停当前媒体"))
        XCTAssertTrue(text.contains("暂停 BGM"))
        XCTAssertFalse(text.contains("老板键"))
    }

    func testHelpCopyMatchesCurrentRunDeskInformationArchitecture() {
        let text = HelpCopyModel.allText

        XCTAssertFalse(text.contains("左侧底部"))
        XCTAssertFalse(text.contains("投射：关/开"))
        XCTAssertFalse(text.contains("查看列表"))
        XCTAssertFalse(text.contains("只提供当前曲目"))
        XCTAssertFalse(text.contains("Live Ops"))
        XCTAssertFalse(text.contains("Output"))
        XCTAssertFalse(text.contains("BGM Library"))
        XCTAssertFalse(text.contains("Overlay Composer"))
        XCTAssertFalse(text.contains("模式卡片"))
        XCTAssertFalse(text.contains("右侧现场控制的模式"))
        XCTAssertTrue(text.contains("现场控制"))
        XCTAssertTrue(text.contains("顶部按钮"))
        XCTAssertTrue(text.contains("主持人"))
        XCTAssertTrue(text.contains("PPT"))
        XCTAssertTrue(text.contains("输出卡片"))
        XCTAssertTrue(text.contains("BGM 库"))
        XCTAssertTrue(text.contains("少量常用曲目"))
        XCTAssertTrue(text.contains("叠层字幕页面"))
    }
}
