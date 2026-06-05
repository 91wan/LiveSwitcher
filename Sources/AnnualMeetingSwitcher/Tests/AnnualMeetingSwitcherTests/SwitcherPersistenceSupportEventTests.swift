import XCTest
@testable import LiveSwitcher

@MainActor
final class SwitcherPersistenceSupportEventTests: XCTestCase {
    func testMissingProgramFileSupportEventUsesSameKindAndDetail() throws {
        let defaults = try makeDefaults()
        defaults.set(["/tmp/missing-\(UUID().uuidString).mp4"], forKey: "pushList_paths")

        let event = try XCTUnwrap(SwitcherPersistenceStore(userDefaults: defaults).load().supportEvents.first)

        XCTAssertEqual(event.kind, .programItemFileMissing)
        XCTAssertEqual(event.detail, "count=1")
    }

    func testMissingBGMFileSupportEventUsesSameKindAndDetail() throws {
        let defaults = try makeDefaults()
        defaults.set(["/tmp/missing-\(UUID().uuidString).mp3"], forKey: "bgmList_paths")

        let event = try XCTUnwrap(SwitcherPersistenceStore(userDefaults: defaults).load().supportEvents.first)

        XCTAssertEqual(event.kind, .bgmFileMissing)
        XCTAssertEqual(event.detail, "count=1")
    }

    func testDroppedWallpaperSupportEventUsesSameKindAndDetail() throws {
        let defaults = try makeDefaults()
        defaults.set(["/tmp/missing-\(UUID().uuidString).png"], forKey: "backgroundWallpapers_paths")

        let event = try XCTUnwrap(SwitcherPersistenceStore(userDefaults: defaults).load().supportEvents.first)

        XCTAssertEqual(event.kind, .wallpaperFileMissing)
        XCTAssertEqual(event.detail, "count=1")
    }

    func testPersistenceStoreDoesNotRecordSupportDirectly() throws {
        let source = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Models/SwitcherPersistenceStore.swift")

        XCTAssertFalse(source.contains("recordSupportEvent"))
        XCTAssertFalse(source.contains("dispatchRuntimeFacadeAction"))
    }

    func testViewModelLoadDataRecordsReturnedSupportEventsThroughRuntime() throws {
        let defaults = try makeDefaults()
        defaults.set(["/tmp/missing-\(UUID().uuidString).mp4"], forKey: "pushList_paths")

        let viewModel = SwitcherViewModel(loadPersistedData: true, enableSystemVolumeObserver: false, userDefaults: defaults)

        XCTAssertEqual(viewModel.supportEvents.first?.kind, .programItemFileMissing)
        XCTAssertEqual(viewModel.runtime.state.support.events.first?.kind, .programItemFileMissing)
        XCTAssertFalse(viewModel.runtime.actionLog.contains { $0.actionName == "supportEventRecorded" })
    }

    func testViewModelLoadDataSupportEventsAreRuntimeCoalesced() throws {
        let defaults = try makeDefaults()
        defaults.set(["/tmp/missing-\(UUID().uuidString).mp4"], forKey: "pushList_paths")

        let viewModel = SwitcherViewModel(loadPersistedData: true, enableSystemVolumeObserver: false, userDefaults: defaults)

        XCTAssertEqual(viewModel.runtime.state.support.coalescedCounts["program.file.missing|count=1"], 1)
        XCTAssertEqual(viewModel.supportEvents, viewModel.runtime.state.support.events)
    }

    private func makeDefaults() throws -> UserDefaults {
        let suiteName = "SwitcherPersistenceSupportEventTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
