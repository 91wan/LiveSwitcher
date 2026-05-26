import XCTest
@testable import LiveSwitcher

final class ProgramQueueRowModelTests: XCTestCase {
    func testMediaCurrentRowShowsTransportAndProgressControls() {
        let item = ProgramItem(title: "Opening", subtitle: "VIDEO", sourceURL: URL(fileURLWithPath: "/tmp/opening.mp4"))
        let model = ProgramQueueRowModel(
            item: item,
            queuePosition: 1,
            queueRole: .current,
            isBroadcasting: true,
            isPlaying: true
        )

        XCTAssertEqual(model.controlStyle, .media)
        XCTAssertTrue(model.showsProgressSlider)
        XCTAssertEqual(model.queueBadgeText, "直播")
        XCTAssertEqual(model.stateBadgeText, "直播")
        XCTAssertEqual(model.controlRailLabel, "直播主控")
    }

    func testHTMLCurrentRowDoesNotShowMediaProgressOrPlayPauseSemantics() {
        let item = ProgramItem(title: "HTML", subtitle: "HTML", sourceURL: URL(fileURLWithPath: "/tmp/index.html"))
        let model = ProgramQueueRowModel(
            item: item,
            queuePosition: 1,
            queueRole: .current,
            isBroadcasting: false,
            isPlaying: false
        )

        XCTAssertEqual(model.controlStyle, .html)
        XCTAssertFalse(model.showsProgressSlider)
        XCTAssertFalse(model.primaryAccessibilityLabel.localizedCaseInsensitiveContains("play"))
        XCTAssertFalse(model.primaryAccessibilityLabel.localizedCaseInsensitiveContains("pause"))
    }

    func testPresentationRowsUseStopPresentationSemantics() {
        let items = [
            ProgramItem(title: "PPTX", subtitle: "PPTX", sourceURL: URL(fileURLWithPath: "/tmp/deck.pptx")),
            ProgramItem(title: "Keynote", subtitle: "KEY", sourceURL: URL(fileURLWithPath: "/tmp/deck.key")),
            ProgramItem(title: "Active Deck", subtitle: "KEY (活动)", sourceURL: nil)
        ]

        for item in items {
            let model = ProgramQueueRowModel(
                item: item,
                queuePosition: 1,
                queueRole: .current,
                isBroadcasting: true,
                isPlaying: false
            )
            XCTAssertEqual(model.controlStyle, .presentation)
            XCTAssertFalse(model.showsProgressSlider)
            XCTAssertEqual(model.primaryAccessibilityLabel, "停止当前演示")
        }
    }

    func testCurrentBadgeDoesNotSayLiveWhenNotBroadcasting() {
        let item = ProgramItem(title: "Opening", subtitle: "MP4", sourceURL: URL(fileURLWithPath: "/tmp/opening.mp4"))
        let model = ProgramQueueRowModel(
            item: item,
            queuePosition: 1,
            queueRole: .current,
            isBroadcasting: false,
            isPlaying: false
        )

        XCTAssertEqual(model.queueBadgeText, "预览")
        XCTAssertEqual(model.stateBadgeText, "预览")
        XCTAssertFalse(model.queueBadgeText.contains("直播"))
        XCTAssertFalse(model.queueBadgeText.contains("直播"))
    }

    func testNextAndQueuedBadgesAreUnambiguous() {
        let item = ProgramItem(title: "Opening", subtitle: "MP4", sourceURL: URL(fileURLWithPath: "/tmp/opening.mp4"))

        XCTAssertEqual(ProgramQueueRowModel(item: item, queuePosition: 2, queueRole: .next, isBroadcasting: false, isPlaying: false).queueBadgeText, "下一项")
        XCTAssertEqual(ProgramQueueRowModel(item: item, queuePosition: 3, queueRole: .queued, isBroadcasting: false, isPlaying: false).queueBadgeText, "3")
    }
}
