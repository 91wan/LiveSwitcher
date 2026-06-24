import XCTest
@testable import LiveSwitcher

@MainActor
final class LiveBGMChooserModelTests: XCTestCase {
    func testThreeTracksShowInQuickListAndChooser() {
        let tracks = makeTracks(count: 3, category: .warmUp)

        let quick = LiveBGMPlaylistModel.make(
            items: tracks,
            currentItem: nil,
            selectedCategory: .warmUp,
            isPlaying: false
        )
        let chooser = LiveBGMChooserModel.make(
            items: tracks,
            currentItem: nil,
            phase: .idle,
            selectedCategory: nil,
            searchText: ""
        )

        XCTAssertEqual(quick.rows.count, 3)
        XCTAssertEqual(chooser.totalCount, 3)
        XCTAssertEqual(chooser.filteredCount, 3)
        XCTAssertEqual(chooser.rows.map(\.title), tracks.map(\.title))
    }

    func testTwelveTracksKeepQuickListAtFiveButChooserShowsAll() {
        let tracks = makeTracks(count: 12, category: .warmUp)

        let quick = LiveBGMPlaylistModel.make(
            items: tracks,
            currentItem: nil,
            selectedCategory: .warmUp,
            isPlaying: false
        )
        let chooser = LiveBGMChooserModel.make(
            items: tracks,
            currentItem: nil,
            phase: .idle,
            selectedCategory: nil,
            searchText: ""
        )

        XCTAssertEqual(quick.rows.count, 5)
        XCTAssertEqual(quick.remainingCountText, "+7 首")
        XCTAssertEqual(chooser.totalCount, 12)
        XCTAssertEqual(chooser.filteredCount, 12)
        XCTAssertEqual(chooser.rows.map(\.title), tracks.map(\.title))
    }

    func testChooserDoesNotTruncateOneHundredTracks() {
        let tracks = makeTracks(count: 100, category: .ambient)

        let chooser = LiveBGMChooserModel.make(
            items: tracks,
            currentItem: nil,
            phase: .idle,
            selectedCategory: nil,
            searchText: ""
        )

        XCTAssertEqual(chooser.totalCount, 100)
        XCTAssertEqual(chooser.filteredCount, 100)
        XCTAssertEqual(chooser.rows.count, 100)
        XCTAssertEqual(chooser.rows.first?.title, "Ambient 001")
        XCTAssertEqual(chooser.rows.last?.title, "Ambient 100")
    }

    func testCurrentTrackOutsideQuickRowsIsPinnedOnlyInQuickListAndMarkedInStableChooserOrder() {
        let tracks = makeTracks(count: 12, category: .award)
        let current = tracks[11]

        let quick = LiveBGMPlaylistModel.make(
            items: tracks,
            currentItem: current,
            selectedCategory: .award,
            isPlaying: true
        )
        let chooser = LiveBGMChooserModel.make(
            items: tracks,
            currentItem: current,
            phase: .playing,
            selectedCategory: nil,
            searchText: ""
        )

        XCTAssertEqual(quick.rows.first?.id, current.id)
        XCTAssertEqual(quick.rows.count, 5)
        XCTAssertEqual(chooser.rows.map(\.id), tracks.map(\.id))
        XCTAssertEqual(chooser.rows[11].id, current.id)
        XCTAssertTrue(chooser.rows[11].isCurrent)
        XCTAssertEqual(chooser.rows[11].stateText, "播放中")
    }

    func testAllAndSingleCategoryFiltersPreserveOriginalOrder() {
        let warm = BGMItem(title: "Warm A", url: URL(fileURLWithPath: "/tmp/warm-a.mp3"), category: .warmUp)
        let award = BGMItem(title: "Award A", url: URL(fileURLWithPath: "/tmp/award-a.mp3"), category: .award)
        let exit = BGMItem(title: "Exit A", url: URL(fileURLWithPath: "/tmp/exit-a.mp3"), category: .exit)

        let all = LiveBGMChooserModel.make(
            items: [warm, award, exit],
            currentItem: nil,
            phase: .idle,
            selectedCategory: nil,
            searchText: ""
        )
        let awardOnly = LiveBGMChooserModel.make(
            items: [warm, award, exit],
            currentItem: nil,
            phase: .idle,
            selectedCategory: .award,
            searchText: ""
        )

        XCTAssertEqual(all.rows.map(\.id), [warm.id, award.id, exit.id])
        XCTAssertEqual(awardOnly.rows.map(\.id), [award.id])
        XCTAssertEqual(awardOnly.filteredCount, 1)
    }

    func testSearchMatchesChineseAndEnglishTitlesAndTrimsWhitespace() {
        let chinese = BGMItem(title: "开场鼓点", url: URL(fileURLWithPath: "/tmp/opening.mp3"), category: .entrance)
        let english = BGMItem(title: "Victory Loop", url: URL(fileURLWithPath: "/tmp/victory.mp3"), category: .award)
        let other = BGMItem(title: "Quiet Bed", url: URL(fileURLWithPath: "/tmp/quiet.mp3"), category: .ambient)

        let chineseResult = LiveBGMChooserModel.make(
            items: [chinese, english, other],
            currentItem: nil,
            phase: .idle,
            selectedCategory: nil,
            searchText: "  开场  "
        )
        let englishResult = LiveBGMChooserModel.make(
            items: [chinese, english, other],
            currentItem: nil,
            phase: .idle,
            selectedCategory: nil,
            searchText: "victory"
        )
        let whitespaceResult = LiveBGMChooserModel.make(
            items: [chinese, english, other],
            currentItem: nil,
            phase: .idle,
            selectedCategory: nil,
            searchText: "   "
        )

        XCTAssertEqual(chineseResult.rows.map(\.id), [chinese.id])
        XCTAssertEqual(englishResult.rows.map(\.id), [english.id])
        XCTAssertEqual(whitespaceResult.rows.map(\.id), [chinese.id, english.id, other.id])
    }

    func testCurrentPausedRowUsesResumeAffordanceAndAccessibleState() {
        let current = BGMItem(title: "Pause Me", url: URL(fileURLWithPath: "/tmp/pause.mp3"), category: .halftime)

        let chooser = LiveBGMChooserModel.make(
            items: [current],
            currentItem: current,
            phase: .paused,
            selectedCategory: nil,
            searchText: ""
        )

        XCTAssertEqual(chooser.rows.first?.systemImage, "play.fill")
        XCTAssertEqual(chooser.rows.first?.stateText, "已暂停")
        XCTAssertEqual(chooser.rows.first?.accessibilityLabel, "Pause Me，中场音乐，当前 BGM，已暂停")
    }

    func testEmptyAndNoResultStatesAreExplicit() {
        let empty = LiveBGMChooserModel.make(
            items: [],
            currentItem: nil,
            phase: .idle,
            selectedCategory: nil,
            searchText: ""
        )
        let track = BGMItem(title: "Only Track", url: URL(fileURLWithPath: "/tmp/only.mp3"), category: .warmUp)
        let noResult = LiveBGMChooserModel.make(
            items: [track],
            currentItem: nil,
            phase: .idle,
            selectedCategory: nil,
            searchText: "missing"
        )

        XCTAssertEqual(empty.emptyTitle, "曲库为空")
        XCTAssertEqual(empty.emptyMessage, "到准备页面添加 BGM 后，可在现场选择已有曲目。")
        XCTAssertEqual(noResult.emptyTitle, "没有匹配曲目")
        XCTAssertEqual(noResult.emptyMessage, "换一个关键词或分类。")
    }

    func testChooserSelectionUsesUnifiedBGMTransportForDifferentCurrentAndCurrentPauseResume() {
        let viewModel = makeViewModel()
        let first = BGMItem(title: "First", url: URL(fileURLWithPath: "/tmp/first.mp3"), category: .warmUp)
        let second = BGMItem(title: "Second", url: URL(fileURLWithPath: "/tmp/second.mp3"), category: .warmUp)
        viewModel.bgmItems = [first, second]

        viewModel.toggleBGM(first)
        viewModel.runtime.replaceStateForFacadeSync(viewModel.runtime.state, clearActionLog: true)

        viewModel.toggleBGM(second)

        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "operatorSelectedBGM" })
        XCTAssertFalse(viewModel.runtime.actionLog.contains { $0.actionName == "operatorStoppedBGM" })

        viewModel.runtime.replaceStateForFacadeSync(viewModel.runtime.state, clearActionLog: true)
        viewModel.toggleBGM(second)

        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "operatorToggledCurrentBGMPlayback" })
        XCTAssertFalse(viewModel.runtime.actionLog.contains { $0.actionName == "operatorStoppedBGM" })
        XCTAssertFalse(viewModel.runtime.actionLog.contains { $0.actionName == "operatorSelectedBGM" })

        viewModel.runtime.replaceStateForFacadeSync(viewModel.runtime.state, clearActionLog: true)
        viewModel.toggleBGM(second)

        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "operatorToggledCurrentBGMPlayback" })
        XCTAssertFalse(viewModel.runtime.actionLog.contains { $0.actionName == "operatorStoppedBGM" })
        XCTAssertFalse(viewModel.runtime.actionLog.contains { $0.actionName == "operatorSelectedBGM" })
    }

    private func makeTracks(count: Int, category: BGMCategory) -> [BGMItem] {
        let prefix = category == .ambient ? "Ambient" : "Track"
        return (1...count).map { index in
            BGMItem(
                title: "\(prefix) \(String(format: "%03d", index))",
                url: URL(fileURLWithPath: "/tmp/\(prefix.lowercased())-\(index).mp3"),
                category: category
            )
        }
    }

    private func makeViewModel() -> SwitcherViewModel {
        let suiteName = "LiveBGMChooserModelTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false, userDefaults: defaults)
        viewModel.liveAudioFadeDuration = 0
        return viewModel
    }
}
