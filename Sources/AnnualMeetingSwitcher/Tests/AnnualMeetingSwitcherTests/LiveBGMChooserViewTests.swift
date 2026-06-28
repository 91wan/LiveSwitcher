import XCTest
@testable import LiveSwitcher

@MainActor
final class LiveBGMChooserViewTests: XCTestCase {
    func testChooserModelFiltersByCategorySearchAndKeepsLibraryCounts() {
        let warm = BGMItem(title: "开场鼓点", url: fileURL("warm.mp3"), category: .warmUp)
        let award = BGMItem(title: "Award Victory", url: fileURL("award.mp3"), category: .award)
        let exit = BGMItem(title: "Exit Walkout", url: fileURL("exit.mp3"), category: .exit)

        let awardSearch = LiveBGMChooserModel.make(
            items: [warm, award, exit],
            currentItem: nil,
            phase: .idle,
            selectedCategory: .award,
            searchText: " victory "
        )
        let emptySearch = LiveBGMChooserModel.make(
            items: [warm, award, exit],
            currentItem: nil,
            phase: .idle,
            selectedCategory: .warmUp,
            searchText: "missing"
        )

        XCTAssertEqual(awardSearch.totalCount, 3)
        XCTAssertEqual(awardSearch.filteredCount, 1)
        XCTAssertEqual(awardSearch.rows.map(\.id), [award.id])
        XCTAssertEqual(awardSearch.rows.first?.categoryTitle, BGMCategory.award.rawValue)
        XCTAssertEqual(emptySearch.totalCount, 3)
        XCTAssertEqual(emptySearch.filteredCount, 0)
        XCTAssertEqual(emptySearch.emptyTitle, "没有匹配曲目")
    }

    func testChooserRowsExposeCurrentSelectionPlaybackStateAndAccessibilityCopy() {
        let current = BGMItem(title: "Pause Me", url: fileURL("pause.mp3"), category: .halftime)
        let other = BGMItem(title: "Ready Track", url: fileURL("ready.mp3"), category: .ambient)

        let paused = LiveBGMChooserModel.make(
            items: [current, other],
            currentItem: current,
            phase: .paused,
            selectedCategory: nil,
            searchText: ""
        )
        let selected = LiveBGMChooserModel.make(
            items: [current],
            currentItem: current,
            phase: .selected,
            selectedCategory: nil,
            searchText: ""
        )

        XCTAssertEqual(paused.rows[0].systemImage, "play.fill")
        XCTAssertEqual(paused.rows[0].stateText, "已暂停")
        XCTAssertEqual(paused.rows[0].accessibilityLabel, "Pause Me，中场音乐，当前 BGM，已暂停")
        XCTAssertEqual(paused.rows[1].systemImage, "music.note")
        XCTAssertEqual(paused.rows[1].stateText, "可播放")
        XCTAssertEqual(selected.rows[0].systemImage, "checkmark")
        XCTAssertEqual(selected.rows[0].stateText, "已选")
    }

    func testCategorySelectionTracksCurrentBGMUntilOperatorManuallyChoosesCategory() {
        let warm = BGMItem(title: "Warm", url: fileURL("warm.mp3"), category: .warmUp)
        let award = BGMItem(title: "Award", url: fileURL("award.mp3"), category: .award)
        var state = BGMCategorySelectionState(selectedCategory: .ambient)

        state.syncWithCurrentItem(warm, allowsAutoSync: true)
        XCTAssertEqual(state.selectedCategory, .warmUp)

        state.selectCategory(.exit)
        state.syncWithCurrentItem(warm, allowsAutoSync: true)
        XCTAssertEqual(state.selectedCategory, .exit)

        state.syncWithCurrentItem(award, allowsAutoSync: true)
        XCTAssertEqual(state.selectedCategory, .award)
    }

    func testChooserSelectionUsesUnifiedBGMTransportSemantics() {
        let viewModel = makeViewModel()
        let first = BGMItem(title: "First", url: fileURL("first.mp3"), category: .warmUp)
        let second = BGMItem(title: "Second", url: fileURL("second.mp3"), category: .warmUp)
        viewModel.bgmItems = [first, second]

        viewModel.toggleBGM(first)
        viewModel.runtime.replaceStateForFacadeSync(viewModel.runtime.state, clearActionLog: true)
        viewModel.toggleBGM(second)

        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "operatorSelectedBGM" })
        XCTAssertFalse(viewModel.runtime.actionLog.contains { $0.actionName == "operatorStoppedBGM" })

        viewModel.runtime.replaceStateForFacadeSync(viewModel.runtime.state, clearActionLog: true)
        viewModel.toggleBGM(second)

        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "operatorToggledCurrentBGMPlayback" })
        XCTAssertFalse(viewModel.runtime.actionLog.contains { $0.actionName == "operatorSelectedBGM" })
    }

    private func makeViewModel() -> SwitcherViewModel {
        let defaults = isolatedDefaults()
        let viewModel = SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            userDefaults: defaults
        )
        viewModel.liveAudioFadeDuration = 0
        return viewModel
    }

    private func isolatedDefaults() -> UserDefaults {
        let suiteName = "LiveBGMChooserViewTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func fileURL(_ name: String) -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(name)
    }
}
