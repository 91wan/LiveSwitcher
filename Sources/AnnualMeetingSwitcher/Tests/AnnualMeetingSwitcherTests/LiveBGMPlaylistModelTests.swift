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

        XCTAssertEqual(model.categoryButtonTitle, BGMCategory.warmUp.rawValue)
        XCTAssertEqual(model.displayCategory, .warmUp)
        XCTAssertEqual(model.categoryButtonTitle, BGMCategory.warmUp.rawValue)
        XCTAssertEqual(model.rows, [])
        XCTAssertEqual(model.emptyMessage, "暖场音乐 没有曲目")
    }

    func testSelectedCategoryRowsShowAtLeastFiveForLiveMiniPlaylist() {
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
        XCTAssertEqual(model.rows.map(\.title), ["Warm 1", "Warm 2", "Warm 3", "Warm 4", "Warm 5"])
        XCTAssertGreaterThanOrEqual(model.visibleRowLimit, 5)
        XCTAssertEqual(model.remainingCountText, "+1 首")
    }

    func testCurrentItemOutsideVisibleRowsIsPinnedVisible() {
        let tracks = (1...7).map {
            BGMItem(title: "Warm \($0)", url: URL(fileURLWithPath: "/tmp/warm-\($0).mp3"), category: .warmUp)
        }
        let current = tracks[6]

        let model = LiveBGMPlaylistModel.make(
            items: tracks,
            currentItem: current,
            selectedCategory: .warmUp,
            isPlaying: true
        )

        XCTAssertEqual(model.rows.first?.id, current.id)
        XCTAssertEqual(model.rows.count, 5)
        XCTAssertEqual(model.remainingCountText, "+2 首")
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
        XCTAssertEqual(model.categoryButtonTitle, BGMCategory.award.rawValue)
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

    func testLiveMiniPlaylistModelCarriesCategoryButtonRowsAndRemainingCount() {
        let tracks = (1...7).map {
            BGMItem(title: "Warm \($0)", url: URL(fileURLWithPath: "/tmp/warm-\($0).mp3"), category: .warmUp)
        }

        let model = LiveBGMPlaylistModel.make(
            items: tracks,
            currentItem: nil,
            selectedCategory: .warmUp,
            isPlaying: false
        )

        XCTAssertEqual(model.categoryButtonTitle, BGMCategory.warmUp.rawValue)
        XCTAssertEqual(model.rows.map(\.item.id), tracks.prefix(5).map(\.id))
        XCTAssertEqual(model.rows.map(\.accessibilityLabel), tracks.prefix(5).map { "\($0.title)，BGM 曲目，可播放" })
        XCTAssertEqual(model.remainingCount, 2)
        XCTAssertEqual(model.remainingCountText, "+2 首")
    }

    func testCurrentTrackStaysVisibleWithinCustomRowLimit() {
        let current = BGMItem(title: "Current", url: URL(fileURLWithPath: "/tmp/current.mp3"), category: .warmUp)
        let tracks = (0..<6).map { index in
            BGMItem(title: "Warm \(index)", url: URL(fileURLWithPath: "/tmp/warm-\(index).mp3"), category: .warmUp)
        } + [current]

        let model = LiveBGMPlaylistModel.make(
            items: tracks,
            currentItem: current,
            selectedCategory: .warmUp,
            isPlaying: true,
            visibleRowLimit: 5
        )

        XCTAssertEqual(model.rows.count, 5)
        XCTAssertEqual(model.rows.first?.item.id, current.id)
        XCTAssertEqual(model.rows.first?.systemImage, "pause.fill")
        XCTAssertEqual(model.remainingCount, 2)
        XCTAssertEqual(model.remainingCountText, "+2 首")
    }
}
