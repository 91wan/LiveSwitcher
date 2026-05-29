import XCTest
@testable import LiveSwitcher

final class BGMControlsStateTests: XCTestCase {
    func testEmptyLibraryDisablesTransportControls() {
        let state = BGMControlsState.make(items: [], currentItem: nil)

        XCTAssertFalse(state.canSeekToBeginning)
        XCTAssertFalse(state.canSkipPrevious)
        XCTAssertFalse(state.canPlay)
        XCTAssertFalse(state.canSkipNext)
        XCTAssertEqual(state.displayStatusText, "空")
        XCTAssertEqual(state.displayStatusKind, .warn)
        XCTAssertEqual(state.playDisabledReason, "请先添加 BGM。")
        XCTAssertEqual(state.skipDisabledReason, "请先添加 BGM。")
    }

    func testSingleTrackWithoutCurrentCanStartPlaybackButCannotSeekOrSkip() {
        let track = BGMItem(title: "Opening", url: URL(fileURLWithPath: "/tmp/opening.mp3"), category: .warmUp)

        let state = BGMControlsState.make(items: [track], currentItem: nil)

        XCTAssertFalse(state.canSeekToBeginning)
        XCTAssertFalse(state.canSkipPrevious)
        XCTAssertTrue(state.canPlay)
        XCTAssertFalse(state.canSkipNext)
        XCTAssertEqual(state.displayStatusText, "待选")
        XCTAssertEqual(state.displayStatusKind, .idle)
    }

    func testMultipleTracksWithoutCurrentExplainsSelectionRequiredBeforeSkipping() {
        let opening = BGMItem(title: "Opening", url: URL(fileURLWithPath: "/tmp/opening.mp3"), category: .warmUp)
        let intro = BGMItem(title: "Intro", url: URL(fileURLWithPath: "/tmp/intro.mp3"), category: .warmUp)

        let state = BGMControlsState.make(items: [opening, intro], currentItem: nil)

        XCTAssertFalse(state.canSkipPrevious)
        XCTAssertFalse(state.canSkipNext)
        XCTAssertEqual(state.skipDisabledReason, "请先选择或播放一首 BGM。")
    }

    func testCurrentTrackEnablesSeekAndPlay() {
        let track = BGMItem(title: "Opening", url: URL(fileURLWithPath: "/tmp/opening.mp3"), category: .warmUp)

        let state = BGMControlsState.make(items: [track], currentItem: track)

        XCTAssertTrue(state.canSeekToBeginning)
        XCTAssertTrue(state.canPlay)
        XCTAssertFalse(state.canSkipPrevious)
        XCTAssertFalse(state.canSkipNext)
        XCTAssertEqual(state.displayStatusText, "已选")
        XCTAssertEqual(state.displayStatusKind, .idle)
    }

    func testPlayingTrackDisplaysPlayingStatus() {
        let track = BGMItem(title: "Opening", url: URL(fileURLWithPath: "/tmp/opening.mp3"), category: .warmUp)

        let state = BGMControlsState.make(items: [track], currentItem: track, isPlaying: true)

        XCTAssertEqual(state.displayStatusText, "播放中")
        XCTAssertEqual(state.displayStatusKind, .ready)
    }

    func testCurrentCategoryNeedsAtLeastTwoTracksToSkip() {
        let current = BGMItem(title: "Opening A", url: URL(fileURLWithPath: "/tmp/opening-a.mp3"), category: .warmUp)
        let sameCategory = BGMItem(title: "Opening B", url: URL(fileURLWithPath: "/tmp/opening-b.mp3"), category: .warmUp)
        let differentCategory = BGMItem(title: "Exit", url: URL(fileURLWithPath: "/tmp/exit.mp3"), category: .exit)

        let singleInCategory = BGMControlsState.make(items: [current, differentCategory], currentItem: current)
        let twoInCategory = BGMControlsState.make(items: [current, sameCategory, differentCategory], currentItem: current)

        XCTAssertFalse(singleInCategory.canSkipPrevious)
        XCTAssertFalse(singleInCategory.canSkipNext)
        XCTAssertEqual(singleInCategory.skipDisabledReason, "当前分类至少需要两首曲目。")
        XCTAssertTrue(twoInCategory.canSkipPrevious)
        XCTAssertTrue(twoInCategory.canSkipNext)
        XCTAssertNil(twoInCategory.skipDisabledReason)
    }

    func testDefaultPlaybackSelectionPrefersCurrentThenSelectedCategory() {
        let warmUp = BGMItem(title: "Warm Up", url: URL(fileURLWithPath: "/tmp/warm-up.mp3"), category: .warmUp)
        let awardA = BGMItem(title: "Award A", url: URL(fileURLWithPath: "/tmp/award-a.mp3"), category: .award)
        let awardB = BGMItem(title: "Award B", url: URL(fileURLWithPath: "/tmp/award-b.mp3"), category: .award)
        let exit = BGMItem(title: "Exit", url: URL(fileURLWithPath: "/tmp/exit.mp3"), category: .exit)

        XCTAssertEqual(
            BGMDefaultSelectionPolicy.defaultItem(
                items: [warmUp, awardA, awardB, exit],
                currentItem: nil,
                selectedCategory: .award
            )?.id,
            awardA.id
        )
        XCTAssertEqual(
            BGMDefaultSelectionPolicy.defaultItem(
                items: [warmUp, awardA, awardB, exit],
                currentItem: exit,
                selectedCategory: .award
            )?.id,
            exit.id
        )
    }

    func testDefaultPlaybackSelectionFallsBackToFirstLibraryItemWhenCategoryIsEmpty() {
        let warmUp = BGMItem(title: "Warm Up", url: URL(fileURLWithPath: "/tmp/warm-up.mp3"), category: .warmUp)

        XCTAssertEqual(
            BGMDefaultSelectionPolicy.defaultItem(
                items: [warmUp],
                currentItem: nil,
                selectedCategory: .exit
            )?.id,
            warmUp.id
        )
        XCTAssertNil(
            BGMDefaultSelectionPolicy.defaultItem(
                items: [],
                currentItem: nil,
                selectedCategory: .exit
            )
        )
    }
}
