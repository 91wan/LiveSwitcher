import XCTest
@testable import LiveSwitcher

final class LiveBGMPlaylistModelTests: XCTestCase {
    func testEmptyLibraryShowsEmptyStateAndCategorySwitcherTitle() {
        let model = LiveBGMPlaylistModel.make(
            items: [],
            currentItem: nil,
            selectedCategory: .warmUp,
            isPlaying: false
        )

        XCTAssertEqual(model.categoryButtonTitle, "切换分类")
        XCTAssertEqual(model.displayCategory, .warmUp)
        XCTAssertEqual(model.rows, [])
        XCTAssertEqual(model.emptyMessage, "暖场音乐 没有曲目")
    }

    func testSelectedCategoryRowsAreLimitedForLiveMiniPlaylist() {
        let tracks = (1...6).map {
            BGMItem(title: "Warm \($0)", url: URL(fileURLWithPath: "/tmp/warm-\($0).mp3"), category: .warmUp)
        }
        let award = BGMItem(title: "Award", url: URL(fileURLWithPath: "/tmp/award.mp3"), category: .award)

        let model = LiveBGMPlaylistModel.make(
            items: tracks + [award],
            currentItem: nil,
            selectedCategory: .warmUp,
            isPlaying: false
        )

        XCTAssertEqual(model.displayCategory, .warmUp)
        XCTAssertEqual(model.rows.map(\.title), ["Warm 1", "Warm 2", "Warm 3"])
        XCTAssertEqual(model.visibleRowLimit, 3)
        XCTAssertEqual(model.remainingCountText, "+3 首")
    }

    func testFallsBackToFirstNonEmptyCategoryWhenSelectedCategoryHasNoTracks() {
        let award = BGMItem(title: "Award", url: URL(fileURLWithPath: "/tmp/award.mp3"), category: .award)

        let model = LiveBGMPlaylistModel.make(
            items: [award],
            currentItem: nil,
            selectedCategory: .warmUp,
            isPlaying: false
        )

        XCTAssertEqual(model.displayCategory, .award)
        XCTAssertEqual(model.rows.map(\.title), ["Award"])
    }

    func testCurrentItemCanSyncDisplayCategoryAndPlayingRowState() {
        let warm = BGMItem(title: "Warm", url: URL(fileURLWithPath: "/tmp/warm.mp3"), category: .warmUp)
        let award = BGMItem(title: "Award", url: URL(fileURLWithPath: "/tmp/award.mp3"), category: .award)

        let model = LiveBGMPlaylistModel.make(
            items: [warm, award],
            currentItem: award,
            selectedCategory: .award,
            isPlaying: true
        )

        XCTAssertEqual(model.displayCategory, .award)
        XCTAssertEqual(model.rows.count, 1)
        XCTAssertEqual(model.rows.first?.title, "Award")
        XCTAssertTrue(model.rows.first?.isCurrent ?? false)
        XCTAssertEqual(model.rows.first?.systemImage, "pause.fill")
        XCTAssertEqual(model.rows.first?.accessibilityLabel, "Award，当前 BGM，播放中")
    }

    func testCurrentItemPausedUsesCuedRowState() {
        let award = BGMItem(title: "Award", url: URL(fileURLWithPath: "/tmp/award.mp3"), category: .award)

        let model = LiveBGMPlaylistModel.make(
            items: [award],
            currentItem: award,
            selectedCategory: .award,
            isPlaying: false
        )

        XCTAssertEqual(model.rows.first?.systemImage, "checkmark")
        XCTAssertEqual(model.rows.first?.accessibilityLabel, "Award，当前 BGM，已选")
    }
}
