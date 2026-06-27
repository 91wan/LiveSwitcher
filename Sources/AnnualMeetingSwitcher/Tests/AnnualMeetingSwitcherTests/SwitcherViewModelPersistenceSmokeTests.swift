import AppKit
import SwiftUI
import XCTest
@testable import LiveSwitcher

@MainActor
final class SwitcherViewModelPersistenceSmokeTests: SwitcherViewModelSmokeTestCase {
    func testAudioStrategyPersistsAcrossViewModelInstances() {
        let (suiteName, defaults) = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let writer = makeViewModel(userDefaults: defaults)
        writer.audioStrategy = .followSource

        let reader = makeViewModel(userDefaults: defaults, loadPersistedData: true)
        XCTAssertEqual(reader.audioStrategy, .followSource)
    }


    func testSpeakerModePersistsAcrossViewModelInstances() {
        let (suiteName, defaults) = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let writer = makeViewModel(userDefaults: defaults)
        writer.toggleSpeakerMode()

        let reader = makeViewModel(userDefaults: defaults, loadPersistedData: true)
        XCTAssertTrue(reader.isSpeakerMode)
    }


    func testAutoPlayNextVideoPreferencePersistsAcrossViewModelInstances() {
        let (suiteName, defaults) = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let defaultReader = makeViewModel(userDefaults: defaults, loadPersistedData: true)
        XCTAssertFalse(defaultReader.autoPlayNextVideoOnEnd)

        let writer = makeViewModel(userDefaults: defaults)
        writer.autoPlayNextVideoOnEnd = true

        let reader = makeViewModel(userDefaults: defaults, loadPersistedData: true)
        XCTAssertTrue(reader.autoPlayNextVideoOnEnd)
    }


    func testProgramPersistenceKeepsFileItemMetadataAlignedWhenActiveDeckItemsAreSkipped() throws {
        let (suiteName, defaults) = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let videoURL = try makeTempFileURL(ext: "mp4")
        let htmlURL = try makeTempFileURL(ext: "html")
        defer {
            try? FileManager.default.removeItem(at: videoURL)
            try? FileManager.default.removeItem(at: htmlURL)
        }

        let writer = makeViewModel(userDefaults: defaults)
        writer.addProgramItem(ProgramItem(title: "Opening Video", subtitle: "VIDEO", sourceURL: videoURL))
        writer.addProgramItem(ProgramItem(title: "Front Keynote", subtitle: "KEY (活动)", sourceURL: nil))
        writer.addProgramItem(ProgramItem(title: "Agenda HTML", subtitle: "HTML", sourceURL: htmlURL))

        let reader = makeViewModel(userDefaults: defaults, loadPersistedData: true)

        XCTAssertEqual(reader.programItems.count, 2)
        XCTAssertEqual(reader.programItems[0].title, "Opening Video")
        XCTAssertEqual(reader.programItems[0].subtitle, "VIDEO")
        XCTAssertEqual(reader.programItems[0].sourceURL, videoURL)
        XCTAssertEqual(reader.programItems[1].title, "Agenda HTML")
        XCTAssertEqual(reader.programItems[1].subtitle, "HTML")
        XCTAssertEqual(reader.programItems[1].sourceURL, htmlURL)
    }


    func testActiveWallpaperSelectionPersistsAcrossViewModelInstances() throws {
        let (suiteName, defaults) = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let firstURL = try makeWallpaperURL()
        let secondURL = try makeWallpaperURL()
        defer {
            try? FileManager.default.removeItem(at: firstURL)
            try? FileManager.default.removeItem(at: secondURL)
        }

        let writer = makeViewModel(userDefaults: defaults)
        writer.addWallpaper(url: firstURL)
        writer.addWallpaper(url: secondURL)
        writer.setActiveWallpaper(url: secondURL)

        let reader = makeViewModel(userDefaults: defaults, loadPersistedData: true)

        XCTAssertEqual(reader.backgroundWallpapers, [firstURL, secondURL])
        XCTAssertEqual(reader.activeWallpaperURL, secondURL)
        XCTAssertNotNil(reader.backgroundImage)
    }

}
