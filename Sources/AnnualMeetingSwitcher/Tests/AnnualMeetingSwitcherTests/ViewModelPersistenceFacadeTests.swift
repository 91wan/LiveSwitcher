import XCTest
@testable import LiveSwitcher

@MainActor
final class ViewModelPersistenceFacadeTests: XCTestCase {
    func testSaveDataPersistsPreferencesAndQueuesForNextLaunch() throws {
        let suiteName = "ViewModelPersistenceFacadeTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let video = try makeTempFile(extension: "mp4")
        let bgm = try makeTempFile(extension: "mp3")
        let program = ProgramItem(title: "Opening", subtitle: "VIDEO", sourceURL: video)
        let bgmItem = BGMItem(title: "Walk-in", url: bgm, category: .entrance)
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false, userDefaults: defaults)
        var persistentState = SwitcherPersistentState()
        persistentState.programItems = [program]
        persistentState.bgmItems = [bgmItem]
        persistentState.audioStrategy = .bgmOnly
        persistentState.bgmPlayMode = .loopOne
        viewModel.applyPersistentState(persistentState)

        viewModel.saveData()

        let restored = SwitcherViewModel(loadPersistedData: true, enableSystemVolumeObserver: false, userDefaults: defaults)
        XCTAssertEqual(restored.programItems.map(\.title), ["Opening"])
        XCTAssertEqual(restored.programItems.map(\.sourceURL), [video])
        XCTAssertEqual(restored.bgmItems.map(\.title), ["Walk-in"])
        XCTAssertEqual(restored.bgmItems.map(\.url), [bgm])
        XCTAssertEqual(restored.bgmItems.map(\.category), [.entrance])
        XCTAssertEqual(restored.audioStrategy, .bgmOnly)
        XCTAssertEqual(restored.runtime.state.audio.strategy, .bgmOnly)
        XCTAssertEqual(restored.bgmPlayMode, .loopOne)
    }

    func testLoadPersistedDataStillRunsWhenRequested() throws {
        let suiteName = "ViewModelPersistenceFacadeTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defaults.set(AudioStrategy.bgmOnly.rawValue, forKey: "audioStrategy")

        let viewModel = SwitcherViewModel(
            loadPersistedData: true,
            enableSystemVolumeObserver: false,
            userDefaults: defaults
        )

        XCTAssertEqual(viewModel.audioStrategy, .bgmOnly)
    }

    func testFreshViewModelDefaultsAudioStrategyToFollowProgram() throws {
        let suiteName = "ViewModelPersistenceFacadeTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)

        let viewModel = SwitcherViewModel(
            loadPersistedData: true,
            enableSystemVolumeObserver: false,
            userDefaults: defaults
        )

        XCTAssertEqual(viewModel.audioStrategy, .followProgram)
        XCTAssertEqual(viewModel.runtime.state.audio.strategy, .followProgram)
    }

    func testLoadPersistedDataCanBeDisabledForTests() throws {
        let suiteName = "ViewModelPersistenceFacadeTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defaults.set(AudioStrategy.bgmOnly.rawValue, forKey: "audioStrategy")

        let viewModel = SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            userDefaults: defaults
        )

        XCTAssertEqual(viewModel.audioStrategy, .followProgram)
    }

    func testLoadDataIsIdempotentForProgramItems() throws {
        let suiteName = "ViewModelPersistenceFacadeTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let video = try makeTempFile(extension: "mp4")
        defaults.set([video.path], forKey: "pushList_paths")
        defaults.set(["Opening"], forKey: "pushList_titles")
        defaults.set(["VIDEO"], forKey: "pushList_subtitles")
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false, userDefaults: defaults)

        viewModel.loadData()
        viewModel.loadData()

        XCTAssertEqual(viewModel.programItems.count, 1)
        XCTAssertEqual(viewModel.programItems.first?.sourceURL, video)
    }

    func testLoadDataIsIdempotentForBGMItems() throws {
        let suiteName = "ViewModelPersistenceFacadeTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let bgm = try makeTempFile(extension: "mp3")
        defaults.set([bgm.path], forKey: "bgmList_paths")
        defaults.set(["Walk-in"], forKey: "bgmList_titles")
        defaults.set([BGMCategory.entrance.rawValue], forKey: "bgmList_categories")
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false, userDefaults: defaults)

        viewModel.loadData()
        viewModel.loadData()

        XCTAssertEqual(viewModel.bgmItems.count, 1)
        XCTAssertEqual(viewModel.bgmItems.first?.url, bgm)
    }

    func testApplyPersistentStateReplacesProgramItems() throws {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)
        let oldItem = ProgramItem(title: "Old", subtitle: "VIDEO", sourceURL: URL(fileURLWithPath: "/tmp/old.mp4"))
        let newItem = ProgramItem(title: "New", subtitle: "VIDEO", sourceURL: URL(fileURLWithPath: "/tmp/new.mp4"))
        viewModel.applyProgramQueueProjectionFromRuntime([oldItem])

        viewModel.applyPersistentState(SwitcherPersistentState(programItems: [newItem]))

        XCTAssertEqual(viewModel.programItems, [newItem])
    }

    func testApplyPersistentStateReplacesBGMItems() throws {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)
        let oldItem = BGMItem(title: "Old", url: URL(fileURLWithPath: "/tmp/old.mp3"), category: .warmUp)
        let newItem = BGMItem(title: "New", url: URL(fileURLWithPath: "/tmp/new.mp3"), category: .award)
        viewModel.bgmItems = [oldItem]

        viewModel.applyPersistentState(SwitcherPersistentState(bgmItems: [newItem]))

        XCTAssertEqual(viewModel.bgmItems, [newItem])
    }

    private func makeTempFile(extension pathExtension: String, contents: Data = Data()) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(pathExtension)
        try contents.write(to: url)
        return url
    }
}
