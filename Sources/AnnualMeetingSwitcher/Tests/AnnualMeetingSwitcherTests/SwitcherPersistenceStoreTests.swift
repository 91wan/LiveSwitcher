import XCTest
@testable import LiveSwitcher

final class SwitcherPersistenceStoreTests: XCTestCase {
    func testPersistenceKeyNamesAreUnchanged() throws {
        let source = try persistenceKeysSource()
        let expectedKeys = [
            "pushList_paths",
            "pushList_titles",
            "pushList_subtitles",
            "pushList_scheduled_starts",
            "pushList_scheduled_durations",
            "bgmList_paths",
            "bgmList_categories",
            "bgmList_titles",
            "backgroundWallpapers_paths",
            "activeWallpaper_path",
            "cornerLogo_path",
            "cornerLogo_position",
            "audioStrategy",
            "speakerMode",
            "bgmPlayMode",
            "autoPlayNextVideoOnEnd",
            "autoAdvanceAtScheduledTime",
            "showAgendaTimeline",
            "consoleMode",
            "themeOverride",
            "overlay.presets.lowerThird.json",
            "overlay.presets.countdown.json",
            "overlay.presets.ticker.json"
        ]

        for key in expectedKeys {
            XCTAssertTrue(source.contains("= \"\(key)\""), "Missing legacy key \(key)")
        }
    }

    func testViewModelDoesNotDeclareUDKeys() throws {
        let source = try viewModelSource()

        XCTAssertFalse(source.contains("enum UDKeys"))
    }

    func testSwitcherPersistenceKeysContainsAllLegacyKeys() throws {
        let source = try persistenceKeysSource()
        let expectedNames = [
            "pushList",
            "pushListTitles",
            "pushListSubtitles",
            "pushListScheduledStarts",
            "pushListScheduledDurations",
            "bgmList",
            "bgmListCategories",
            "bgmListTitles",
            "wallpapers",
            "activeWallpaper",
            "cornerLogo",
            "cornerLogoPosition",
            "audioStrategy",
            "speakerMode",
            "bgmPlayMode",
            "autoPlayNextVideoOnEnd",
            "autoAdvanceAtScheduledTime",
            "showAgendaTimeline",
            "consoleMode",
            "themeOverride",
            "lowerThirdPresets",
            "countdownPresets",
            "tickerPresets"
        ]

        for name in expectedNames {
            XCTAssertTrue(source.contains("static let \(name)"), "Missing key name \(name)")
        }
    }

    func testViewModelDoesNotOwnPersistenceKeys() throws {
        let source = try viewModelSource()

        XCTAssertFalse(source.contains("UDKeys."))
        XCTAssertFalse(source.contains("pushList_paths"))
        XCTAssertFalse(source.contains("overlay.presets.lowerThird.json"))
    }

    func testSwitcherPersistenceStoreDoesNotImportSwiftUIOrAppKitUI() throws {
        let source = try persistenceStoreSource()

        XCTAssertFalse(source.contains("import SwiftUI"))
        XCTAssertFalse(source.contains("import AppKit"))
    }

    func testSwitcherPersistenceStoreDoesNotReferenceSwitcherViewModel() throws {
        let source = try persistenceStoreSource()

        XCTAssertFalse(source.contains("SwitcherViewModel"))
    }

    func testSwitcherPersistenceStoreDoesNotReferenceLiveRuntimeStore() throws {
        let source = try persistenceStoreSource()

        XCTAssertFalse(source.contains("LiveRuntimeStore"))
    }

    private func viewModelSource() throws -> String {
        try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel.swift")
    }

    private func persistenceKeysSource() throws -> String {
        try XCTUnwrap(optionalRepositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Models/SwitcherPersistenceKeys.swift"))
    }

    private func persistenceStoreSource() throws -> String {
        try XCTUnwrap(optionalRepositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Models/SwitcherPersistenceStore.swift"))
    }
}
