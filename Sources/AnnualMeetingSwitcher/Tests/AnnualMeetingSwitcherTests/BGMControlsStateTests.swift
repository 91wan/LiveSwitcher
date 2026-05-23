import XCTest
@testable import LiveSwitcher

final class BGMControlsStateTests: XCTestCase {
    func testEmptyLibraryDisablesTransportControls() {
        let state = BGMControlsState.make(items: [], currentItem: nil)

        XCTAssertFalse(state.canSeekToBeginning)
        XCTAssertFalse(state.canSkipPrevious)
        XCTAssertFalse(state.canPlay)
        XCTAssertFalse(state.canSkipNext)
    }

    func testSingleTrackWithoutCurrentCanStartPlaybackButCannotSeekOrSkip() {
        let track = BGMItem(title: "Opening", url: URL(fileURLWithPath: "/tmp/opening.mp3"), category: .warmUp)

        let state = BGMControlsState.make(items: [track], currentItem: nil)

        XCTAssertFalse(state.canSeekToBeginning)
        XCTAssertFalse(state.canSkipPrevious)
        XCTAssertTrue(state.canPlay)
        XCTAssertFalse(state.canSkipNext)
    }

    func testCurrentTrackEnablesSeekAndPlay() {
        let track = BGMItem(title: "Opening", url: URL(fileURLWithPath: "/tmp/opening.mp3"), category: .warmUp)

        let state = BGMControlsState.make(items: [track], currentItem: track)

        XCTAssertTrue(state.canSeekToBeginning)
        XCTAssertTrue(state.canPlay)
        XCTAssertFalse(state.canSkipPrevious)
        XCTAssertFalse(state.canSkipNext)
    }

    func testCurrentCategoryNeedsAtLeastTwoTracksToSkip() {
        let current = BGMItem(title: "Opening A", url: URL(fileURLWithPath: "/tmp/opening-a.mp3"), category: .warmUp)
        let sameCategory = BGMItem(title: "Opening B", url: URL(fileURLWithPath: "/tmp/opening-b.mp3"), category: .warmUp)
        let differentCategory = BGMItem(title: "Exit", url: URL(fileURLWithPath: "/tmp/exit.mp3"), category: .exit)

        let singleInCategory = BGMControlsState.make(items: [current, differentCategory], currentItem: current)
        let twoInCategory = BGMControlsState.make(items: [current, sameCategory, differentCategory], currentItem: current)

        XCTAssertFalse(singleInCategory.canSkipPrevious)
        XCTAssertFalse(singleInCategory.canSkipNext)
        XCTAssertTrue(twoInCategory.canSkipPrevious)
        XCTAssertTrue(twoInCategory.canSkipNext)
    }
}
