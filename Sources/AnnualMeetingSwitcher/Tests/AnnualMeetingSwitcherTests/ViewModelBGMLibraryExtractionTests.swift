import XCTest
@testable import LiveSwitcher

@MainActor
final class ViewModelBGMLibraryExtractionTests: XCTestCase {
    func testBGMLibraryMethodsAreNotDeclaredInMainViewModel() throws {
        let source = try viewModelSource()

        for snippet in [
            "func addBGMItem(",
            "func addBGMItems(",
            "func removeBGMItem(",
            "func moveBGMItems(",
            "func toggleBGM(",
            "func recordBGMPlaybackState("
        ] {
            XCTAssertFalse(source.contains(snippet), snippet)
        }
    }

    func testBGMLibraryMethodsLiveInBGMControlsExtension() throws {
        let source = try bgmControlsExtensionSource()

        XCTAssertTrue(source.contains("extension SwitcherViewModel"))
        for snippet in [
            "func addBGMItem(",
            "func addBGMItems(",
            "func removeBGMItem(",
            "func moveBGMItems(",
            "func seekBGMToBeginning(",
            "func seekBGM(toProgress",
            "func toggleBGM(",
            "func recordBGMPlaybackState("
        ] {
            XCTAssertTrue(source.contains(snippet), snippet)
        }
    }

    func testAddBGMItemStillUsesDuplicatePolicy() {
        let viewModel = makeViewModel()
        let item = bgmItem()

        XCTAssertTrue(viewModel.addBGMItem(item))
        XCTAssertFalse(viewModel.addBGMItem(BGMItem(title: "Duplicate", url: item.url)))
        XCTAssertEqual(viewModel.bgmItems.map(\.url), [item.url])
        XCTAssertTrue(viewModel.supportEvents.contains { $0.kind == .bgmImportSkippedDuplicate })
    }

    func testRemoveCurrentBGMStillStopsRuntimeBGM() {
        let viewModel = makeViewModel()
        let item = bgmItem()
        viewModel.bgmItems = [item]
        viewModel.toggleBGM(item)
        viewModel.runtime.replaceStateForFacadeSync(viewModel.runtime.state, clearActionLog: true)

        viewModel.removeBGMItem(item)

        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "operatorStoppedBGM" })
        XCTAssertFalse(viewModel.isBGMPlaying)
    }

    func testMoveBGMItemsStillSavesData() throws {
        let suiteName = "ViewModelBGMLibraryExtractionTests.move.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let viewModel = makeViewModel(userDefaults: defaults)
        let first = bgmItem(title: "First")
        let second = bgmItem(title: "Second")
        viewModel.bgmItems = [first, second]

        viewModel.moveBGMItems(from: IndexSet(integer: 0), to: 2)

        XCTAssertEqual(viewModel.bgmItems.map(\.id), [second.id, first.id])
        XCTAssertEqual(defaults.stringArray(forKey: "bgmList_titles"), ["Second", "First"])
    }

    func testToggleBGMStillDispatchesRuntimeAction() {
        let viewModel = makeViewModel()
        let item = bgmItem()
        viewModel.bgmItems = [item]

        viewModel.toggleBGM(item)

        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "operatorSelectedBGM" })
        XCTAssertEqual(viewModel.currentBGMItem?.id, item.id)
    }

    func testToggleBGMDuringPanicStillCuesAndUpdatesSnapshot() {
        let viewModel = makeViewModel()
        let item = bgmItem()
        viewModel.bgmItems = [item]
        viewModel.togglePanicMode()
        viewModel.runtime.replaceStateForFacadeSync(viewModel.runtime.state, clearActionLog: true)

        viewModel.toggleBGM(item)

        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "operatorSelectedBGM" })
        XCTAssertEqual(viewModel.currentBGMItem?.id, item.id)
        XCTAssertFalse(viewModel.isBGMPlaying)
    }

    func testBGMPlaybackSupportEventStillRecorded() {
        let viewModel = makeViewModel()

        viewModel.recordBGMPlaybackState(isPlaying: true, reason: "test")

        XCTAssertTrue(viewModel.supportEvents.contains {
            $0.kind == .bgmPlaybackChanged && $0.detail == "isPlaying=true,reason=test"
        })
    }

    private func makeViewModel(userDefaults: UserDefaults? = nil) -> SwitcherViewModel {
        let defaults = userDefaults ?? {
            let suiteName = "ViewModelBGMLibraryExtractionTests.\(UUID().uuidString)"
            let defaults = UserDefaults(suiteName: suiteName)!
            defaults.removePersistentDomain(forName: suiteName)
            return defaults
        }()
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false, userDefaults: defaults)
        viewModel.liveAudioFadeDuration = 0
        return viewModel
    }

    private func bgmItem(title: String = "Walk-in") -> BGMItem {
        BGMItem(title: title, url: URL(fileURLWithPath: "/tmp/\(UUID().uuidString).mp3"))
    }

    private func viewModelSource() throws -> String {
        try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel.swift")
    }

    private func bgmControlsExtensionSource() throws -> String {
        try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+BGMControls.swift")
    }
}
