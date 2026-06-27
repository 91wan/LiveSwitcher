import XCTest
@testable import LiveSwitcher

final class LiveBGMQuickPickerModelTests: XCTestCase {
    func testEmptyLibraryUsesNoSelectionCopy() {
        let model = LiveBGMQuickPickerModel.make(items: [], currentItem: nil)

        XCTAssertTrue(model.isLibraryEmpty)
        XCTAssertEqual(model.currentTitle, "未选择 BGM")
        XCTAssertTrue(model.nonEmptySections.isEmpty)
    }

    func testPickerGroupsTracksByCategory() {
        let warm = BGMItem(title: "Warm", url: URL(fileURLWithPath: "/tmp/warm.mp3"), category: .warmUp)
        let award = BGMItem(title: "Award", url: URL(fileURLWithPath: "/tmp/award.mp3"), category: .award)

        let model = LiveBGMQuickPickerModel.make(items: [warm, award], currentItem: award)

        XCTAssertFalse(model.isLibraryEmpty)
        XCTAssertEqual(model.currentTitle, "Award")
        XCTAssertEqual(model.nonEmptySections.map(\.category), [.warmUp, .award])
        XCTAssertEqual(model.nonEmptySections.map { $0.tracks.map(\.title) }, [["Warm"], ["Award"]])
    }

    func testPickerKeepsCategoryOrderAndFiltersEmptySections() {
        let exit = BGMItem(title: "Exit", url: URL(fileURLWithPath: "/tmp/exit.mp3"), category: .exit)
        let entrance = BGMItem(title: "Entrance", url: URL(fileURLWithPath: "/tmp/entrance.mp3"), category: .entrance)

        let model = LiveBGMQuickPickerModel.make(items: [exit, entrance], currentItem: nil)

        XCTAssertEqual(model.sections.map(\.category), BGMCategory.allCases)
        XCTAssertEqual(model.nonEmptySections.map(\.category), [.entrance, .exit])
    }

    func testLivePickerModelExposesAllCategorySectionsForLiveCategorySelection() {
        let warm = BGMItem(title: "Warm", url: URL(fileURLWithPath: "/tmp/warm.mp3"), category: .warmUp)
        let award = BGMItem(title: "Award", url: URL(fileURLWithPath: "/tmp/award.mp3"), category: .award)

        let model = LiveBGMQuickPickerModel.make(items: [warm, award], currentItem: warm)

        XCTAssertEqual(model.currentTitle, "Warm")
        XCTAssertEqual(model.sections.count, BGMCategory.allCases.count)
        XCTAssertEqual(model.sections.map(\.title), BGMCategory.allCases.map(\.rawValue))
        XCTAssertEqual(model.section(for: .warmUp)?.tracks.map(\.id), [warm.id])
        XCTAssertEqual(model.section(for: .award)?.tracks.map(\.id), [award.id])
        XCTAssertTrue(model.section(for: .exit)?.isEmpty ?? false)
    }
}
