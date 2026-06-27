import XCTest
@testable import LiveSwitcher

final class BGMPanelStatusCopyTests: XCTestCase {
    func testPanelStatusCopyMapsControlStateToOperatorLanguage() {
        let track = BGMItem(title: "Opening", url: URL(fileURLWithPath: "/tmp/opening.mp3"))
        let cases: [(controls: BGMControlsState, expected: String)] = [
            (.make(items: [], currentItem: nil), "请添加 BGM"),
            (.make(items: [track], currentItem: nil), "请选择 BGM"),
            (.make(items: [track], currentItem: track), "BGM 已选中"),
            (.make(items: [track], currentItem: track, isPlaying: true), "BGM 播放中"),
            (.make(items: [track], currentItem: track, phase: .paused), "已暂停")
        ]

        for item in cases {
            XCTAssertEqual(BGMPanelStatusCopy.text(for: item.controls), item.expected)
        }
    }
}
