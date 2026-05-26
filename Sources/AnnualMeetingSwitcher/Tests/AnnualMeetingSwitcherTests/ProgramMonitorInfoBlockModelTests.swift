import XCTest
@testable import LiveSwitcher

final class ProgramMonitorInfoBlockModelTests: XCTestCase {
    func testNextNilDoesNotDisplayNextBadge() {
        let model = ProgramMonitorInfoBlockModel.next(item: nil)

        XCTAssertEqual(model.value, "无")
        XCTAssertEqual(model.badgeText, "空")
        XCTAssertEqual(model.status, .idle)
        XCTAssertEqual(model.accessibilityLabel, "下一项: 无, 队列为空, 空")
    }

    func testNextExistsDisplaysNextBadge() {
        let item = ProgramItem(title: "Awards", subtitle: "MP4")
        let model = ProgramMonitorInfoBlockModel.next(item: item)

        XCTAssertEqual(model.value, "Awards")
        XCTAssertEqual(model.badgeText, "下一项")
        XCTAssertEqual(model.status, .ready)
        XCTAssertEqual(model.accessibilityLabel, "下一项: Awards, MP4, 下一项")
    }

    func testCurrentNilDisplaysEmpty() {
        let model = ProgramMonitorInfoBlockModel.current(
            item: nil,
            isBroadcasting: false,
            isPlaying: false,
            isHTMLLoaded: false
        )

        XCTAssertEqual(model.value, "无节目")
        XCTAssertEqual(model.badgeText, "空")
        XCTAssertEqual(model.status, .idle)
        XCTAssertEqual(model.accessibilityLabel, "当前: 无节目, 待机, 空")
    }

    func testCurrentPreviewAndOnAirStates() {
        let item = ProgramItem(title: "Opening", subtitle: "MP4")

        let preview = ProgramMonitorInfoBlockModel.current(
            item: item,
            isBroadcasting: false,
            isPlaying: false,
            isHTMLLoaded: false
        )
        let onAir = ProgramMonitorInfoBlockModel.current(
            item: item,
            isBroadcasting: true,
            isPlaying: false,
            isHTMLLoaded: false
        )

        XCTAssertEqual(preview.badgeText, "预览")
        XCTAssertEqual(preview.status, .idle)
        XCTAssertEqual(preview.accessibilityLabel, "当前: Opening, MP4, 预览")
        XCTAssertEqual(onAir.badgeText, "直播")
        XCTAssertEqual(onAir.status, .live)
        XCTAssertEqual(onAir.accessibilityLabel, "当前: Opening, MP4, 直播")
    }

    func testMonitorStandbyIsIdleNotWarning() {
        let standby = ProgramMonitorStateModel.make(isBroadcasting: false, currentItem: nil)
        let preview = ProgramMonitorStateModel.make(
            isBroadcasting: false,
            currentItem: ProgramItem(title: "Opening", subtitle: "MP4")
        )
        let onAir = ProgramMonitorStateModel.make(
            isBroadcasting: true,
            currentItem: ProgramItem(title: "Opening", subtitle: "MP4")
        )

        XCTAssertEqual(standby.label, "待机")
        XCTAssertEqual(standby.kind, .idle)
        XCTAssertEqual(preview.label, "预览")
        XCTAssertEqual(preview.kind, .idle)
        XCTAssertEqual(onAir.label, "直播")
        XCTAssertEqual(onAir.kind, .live)
    }

    func testMonitorChromeLayoutDowngradesBeforeInlineStatusWraps() {
        XCTAssertEqual(ProgramMonitorChromeLayoutModel.make(width: 700).variant, .full)
        XCTAssertEqual(ProgramMonitorChromeLayoutModel.make(width: 375).variant, .compact)
        XCTAssertEqual(ProgramMonitorChromeLayoutModel.make(width: 280).variant, .stateOnly)
    }
}
