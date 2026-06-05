import XCTest
@testable import LiveSwitcher

@MainActor
final class ViewModelPersistenceFacadeTests: XCTestCase {
    func testSaveDataIsNotDeclaredInMainViewModel() throws {
        let source = try viewModelSource()

        XCTAssertFalse(source.contains("func saveData("))
    }

    func testLoadDataIsNotDeclaredInMainViewModel() throws {
        let source = try viewModelSource()

        XCTAssertFalse(source.contains("func loadData("))
    }

    func testPersistentStateSnapshotIsNotDeclaredInMainViewModel() throws {
        let source = try viewModelSource()

        XCTAssertFalse(source.contains("func makePersistentStateSnapshot("))
        XCTAssertFalse(source.contains("func applyPersistentState("))
    }

    func testRuntimePersistenceMethodsAreNotDeclaredInMainViewModel() throws {
        let source = try viewModelSource()

        XCTAssertFalse(source.contains("func persistConsoleModeFromRuntime("))
        XCTAssertFalse(source.contains("func persistThemeOverrideFromRuntime("))
        XCTAssertFalse(source.contains("func persistAudioStrategyFromRuntime("))
        XCTAssertFalse(source.contains("func persistSpeakerModeFromRuntime("))
        XCTAssertFalse(source.contains("func persistBGMPlayModeFromRuntime("))
        XCTAssertFalse(source.contains("func persistAutoPlayNextVideoOnEndFromRuntime("))
        XCTAssertFalse(source.contains("func persistAutoAdvanceAtScheduledTimeFromRuntime("))
        XCTAssertFalse(source.contains("func persistShowAgendaTimelineFromRuntime("))
        XCTAssertFalse(source.contains("func persistCornerLogoPositionFromRuntime("))
    }

    func testPersistenceFacadeLivesInViewModelPersistenceExtension() throws {
        let source = try persistenceExtensionSource()

        XCTAssertTrue(source.contains("extension SwitcherViewModel"))
        XCTAssertTrue(source.contains("func saveData("))
        XCTAssertTrue(source.contains("func loadData("))
        XCTAssertTrue(source.contains("func makePersistentStateSnapshot("))
        XCTAssertTrue(source.contains("func applyPersistentState("))
        XCTAssertTrue(source.contains("func persistAudioStrategyFromRuntime("))
    }

    func testSaveDataStillCallsPersistenceStoreSave() throws {
        let body = try XCTUnwrap(try persistenceExtensionSource().extractedRuntimeFunctionBody(named: "saveData"))

        XCTAssertTrue(body.contains("persistenceStore.save("))
        XCTAssertTrue(body.contains("makePersistentStateSnapshot()"))
        XCTAssertTrue(body.contains("saveDataDidRun?()"))
        XCTAssertLessThanOrEqual(body.split(separator: "\n").count, 5)
    }

    func testLoadDataStillCallsPersistenceStoreLoadAndApplyRepairs() throws {
        let body = try XCTUnwrap(try persistenceExtensionSource().extractedRuntimeFunctionBody(named: "loadData"))

        XCTAssertTrue(body.contains("persistenceStore.load()"))
        XCTAssertTrue(body.contains("applyPersistentState("))
        XCTAssertTrue(body.contains("persistenceStore.applyRepairs("))
        XCTAssertTrue(body.contains("recordSupportEvent("))
        XCTAssertLessThanOrEqual(body.split(separator: "\n").count, 9)
    }

    func testViewModelSaveDataDoesNotDirectlySetUserDefaultsKeys() throws {
        let body = try XCTUnwrap(try persistenceExtensionSource().extractedRuntimeFunctionBody(named: "saveData"))

        XCTAssertFalse(body.contains("userDefaults.set("))
        XCTAssertFalse(body.contains("userDefaults.removeObject"))
        XCTAssertFalse(body.contains("JSONEncoder()"))
        XCTAssertFalse(body.contains("ProgramQueueStore.encodedSchedule"))
    }

    func testViewModelLoadDataDoesNotDirectlyReadUserDefaultsKeys() throws {
        let body = try XCTUnwrap(try persistenceExtensionSource().extractedRuntimeFunctionBody(named: "loadData"))

        XCTAssertFalse(body.contains("userDefaults.stringArray("))
        XCTAssertFalse(body.contains("userDefaults.string("))
        XCTAssertFalse(body.contains("userDefaults.data("))
        XCTAssertFalse(body.contains("JSONDecoder()"))
        XCTAssertFalse(body.contains("ProgramQueueStore.restoredProgramItems"))
    }

    func testViewModelDoesNotDeclareUDKeys() throws {
        XCTAssertFalse(try viewModelSource().contains("enum UDKeys"))
    }

    func testViewModelDoesNotDirectlyEncodeOverlayPresets() throws {
        let source = try viewModelSource()

        XCTAssertFalse(source.contains("JSONEncoder().encode(lowerThirdPresets)"))
        XCTAssertFalse(source.contains("JSONEncoder().encode(countdownPresets)"))
        XCTAssertFalse(source.contains("JSONEncoder().encode(tickerPresets)"))
    }

    func testViewModelDoesNotDirectlyDecodeOverlayPresets() throws {
        let source = try viewModelSource()

        XCTAssertFalse(source.contains("JSONDecoder().decode([LowerThirdPreset].self"))
        XCTAssertFalse(source.contains("JSONDecoder().decode([CountdownPreset].self"))
        XCTAssertFalse(source.contains("JSONDecoder().decode([TickerPreset].self"))
    }

    func testViewModelDoesNotDirectlyRestoreBGMItemsFromUserDefaults() throws {
        let body = try XCTUnwrap(try persistenceExtensionSource().extractedRuntimeFunctionBody(named: "loadData"))

        XCTAssertFalse(body.contains("BGMItem(title:"))
        XCTAssertFalse(body.contains("bgmItems.append"))
    }

    func testViewModelDoesNotDirectlyRestoreProgramItemsFromUserDefaults() throws {
        let body = try XCTUnwrap(try persistenceExtensionSource().extractedRuntimeFunctionBody(named: "loadData"))

        XCTAssertFalse(body.contains("ProgramQueueStore.restoredProgramItems"))
        XCTAssertFalse(body.contains("programItems.append"))
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

        XCTAssertEqual(viewModel.audioStrategy, .mixed)
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
        viewModel.programItems = [oldItem]

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

    private func viewModelSource() throws -> String {
        try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel.swift")
    }

    private func persistenceExtensionSource() throws -> String {
        try XCTUnwrap(optionalRepositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+Persistence.swift"))
    }

    private func makeTempFile(extension pathExtension: String, contents: Data = Data()) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(pathExtension)
        try contents.write(to: url)
        return url
    }
}
