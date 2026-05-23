import XCTest
@testable import LiveSwitcher

final class BGMCategorySelectionStateTests: XCTestCase {
    func testLiveDockAutoSyncsToCurrentTrackCategory() {
        let current = BGMItem(title: "Award", url: URL(fileURLWithPath: "/tmp/award.mp3"), category: .award)
        var state = BGMCategorySelectionState(selectedCategory: .warmUp)

        state.syncWithCurrentItem(current, allowsAutoSync: true)

        XCTAssertEqual(state.selectedCategory, .award)
    }

    func testManualCategorySelectionIsNotOverwrittenBySameCurrentTrackRefresh() {
        let current = BGMItem(title: "Award", url: URL(fileURLWithPath: "/tmp/award.mp3"), category: .award)
        var state = BGMCategorySelectionState(selectedCategory: .warmUp)

        state.syncWithCurrentItem(current, allowsAutoSync: true)
        state.selectCategory(.ambient)
        state.syncWithCurrentItem(current, allowsAutoSync: true)

        XCTAssertEqual(state.selectedCategory, .ambient)
    }

    func testNewCurrentTrackCanResyncAfterManualSelection() {
        let award = BGMItem(title: "Award", url: URL(fileURLWithPath: "/tmp/award.mp3"), category: .award)
        let exit = BGMItem(title: "Exit", url: URL(fileURLWithPath: "/tmp/exit.mp3"), category: .exit)
        var state = BGMCategorySelectionState(selectedCategory: .warmUp)

        state.syncWithCurrentItem(award, allowsAutoSync: true)
        state.selectCategory(.ambient)
        state.syncWithCurrentItem(exit, allowsAutoSync: true)

        XCTAssertEqual(state.selectedCategory, .exit)
    }

    func testFullLibraryDoesNotAutoSyncCategory() {
        let current = BGMItem(title: "Award", url: URL(fileURLWithPath: "/tmp/award.mp3"), category: .award)
        var state = BGMCategorySelectionState(selectedCategory: .warmUp)

        state.syncWithCurrentItem(current, allowsAutoSync: false)

        XCTAssertEqual(state.selectedCategory, .warmUp)
    }
}
