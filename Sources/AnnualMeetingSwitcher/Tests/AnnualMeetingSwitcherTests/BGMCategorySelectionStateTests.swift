import XCTest
@testable import LiveSwitcher

final class BGMCategorySelectionStateTests: XCTestCase {
    func testLiveDockAutoSyncsToCurrentTrackCategory() {
        let current = BGMItem(title: "Award", url: URL(fileURLWithPath: "/tmp/award.mp3"), category: .award)
        var state = BGMCategorySelectionState(selectedCategory: .warmUp)

        state.syncWithCurrentItem(current, allowsAutoSync: true)

        XCTAssertEqual(state.selectedCategory, .award)
    }

    func testManualCategorySelectionIsNotOverwrittenByUnrelatedRefresh() {
        let current = BGMItem(title: "Award", url: URL(fileURLWithPath: "/tmp/award.mp3"), category: .award)
        var state = BGMCategorySelectionState(selectedCategory: .warmUp)

        state.selectCategory(.ambient)
        state.syncWithCurrentItem(current, allowsAutoSync: true)

        XCTAssertEqual(state.selectedCategory, .ambient)
    }

    func testFullLibraryDoesNotAutoSyncCategory() {
        let current = BGMItem(title: "Award", url: URL(fileURLWithPath: "/tmp/award.mp3"), category: .award)
        var state = BGMCategorySelectionState(selectedCategory: .warmUp)

        state.syncWithCurrentItem(current, allowsAutoSync: false)

        XCTAssertEqual(state.selectedCategory, .warmUp)
    }
}
