import XCTest
@testable import LiveSwitcher

@MainActor
final class ViewModelPersistenceFacadeTests: XCTestCase {
    func testSaveDataIsThinWrapperAroundPersistenceStore() throws {
        let source = try viewModelSource()
        let body = try XCTUnwrap(source.extractedRuntimeFunctionBody(named: "saveData"))

        XCTAssertTrue(body.contains("persistenceStore.save("))
        XCTAssertTrue(body.contains("makePersistentStateSnapshot()"))
        XCTAssertTrue(body.contains("saveDataDidRun?()"))
        XCTAssertLessThanOrEqual(body.split(separator: "\n").count, 5)
    }

    func testLoadDataIsThinWrapperAroundPersistenceStore() throws {
        let source = try viewModelSource()
        let body = try XCTUnwrap(source.extractedRuntimeFunctionBody(named: "loadData"))

        XCTAssertTrue(body.contains("persistenceStore.load()"))
        XCTAssertTrue(body.contains("applyPersistentState("))
        XCTAssertTrue(body.contains("recordSupportEvent("))
        XCTAssertLessThanOrEqual(body.split(separator: "\n").count, 8)
    }

    func testViewModelSaveDataDoesNotDirectlySetUserDefaultsKeys() throws {
        let body = try XCTUnwrap(try viewModelSource().extractedRuntimeFunctionBody(named: "saveData"))

        XCTAssertFalse(body.contains("userDefaults.set("))
        XCTAssertFalse(body.contains("userDefaults.removeObject"))
        XCTAssertFalse(body.contains("JSONEncoder()"))
        XCTAssertFalse(body.contains("ProgramQueueStore.encodedSchedule"))
    }

    func testViewModelLoadDataDoesNotDirectlyReadUserDefaultsKeys() throws {
        let body = try XCTUnwrap(try viewModelSource().extractedRuntimeFunctionBody(named: "loadData"))

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
        let body = try XCTUnwrap(try viewModelSource().extractedRuntimeFunctionBody(named: "loadData"))

        XCTAssertFalse(body.contains("BGMItem(title:"))
        XCTAssertFalse(body.contains("bgmItems.append"))
    }

    func testViewModelDoesNotDirectlyRestoreProgramItemsFromUserDefaults() throws {
        let body = try XCTUnwrap(try viewModelSource().extractedRuntimeFunctionBody(named: "loadData"))

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

    private func viewModelSource() throws -> String {
        try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel.swift")
    }
}
