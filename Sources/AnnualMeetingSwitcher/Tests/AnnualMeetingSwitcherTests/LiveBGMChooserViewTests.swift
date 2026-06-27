import XCTest
@testable import LiveSwitcher

final class LiveBGMChooserViewTests: XCTestCase {
    func testLiveModeBGMCardExposesFullLibraryChooserEntryAndPopover() throws {
        let source = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/LiveModeView.swift")

        XCTAssertTrue(source.contains("@State var isBGMChooserPresented"))
        XCTAssertTrue(source.contains("全部曲目"))
        XCTAssertTrue(source.contains("LiveBGMChooserPopover"))
        XCTAssertTrue(source.contains(".popover(isPresented: $isBGMChooserPresented"))
        XCTAssertTrue(source.contains("isBGMChooserPresented = false"))
    }

    func testChooserPopoverHasSearchCategoryFilterScrollableRowsAndNoEditingControls() throws {
        let source = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/LiveBGMChooserPopover.swift")

        XCTAssertTrue(source.contains("LiveBGMChooserModel.make"))
        XCTAssertTrue(source.contains("TextField(\"搜索曲目\""))
        XCTAssertTrue(source.contains("Picker(\"分类\""))
        XCTAssertTrue(source.contains("Text(\"全部\")"))
        XCTAssertTrue(source.contains("BGMCategory.allCases"))
        XCTAssertTrue(source.contains("ScrollView"))
        XCTAssertTrue(source.contains("LazyVStack"))
        XCTAssertTrue(source.contains("viewModel.toggleBGM(row.item)"))
        XCTAssertTrue(source.contains("onSelect()"))
        XCTAssertTrue(source.contains("accessibilityLabel(row.accessibilityLabel)"))
        XCTAssertFalse(source.contains("importBGM"))
        XCTAssertFalse(source.contains("removeBGMItem"))
        XCTAssertFalse(source.contains("moveBGMItems"))
        XCTAssertFalse(source.contains("onMove"))
    }

    func testLiveModeLayoutTestsTrackChooserWithoutSetupNavigation() throws {
        let source = try repositorySource("Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/LiveModeLayoutTests.swift")

        XCTAssertTrue(source.contains("LiveBGMChooserPopover"))
        XCTAssertTrue(source.contains("全部曲目"))
        XCTAssertFalse(source.contains("Open BGM Library"))
    }
}
