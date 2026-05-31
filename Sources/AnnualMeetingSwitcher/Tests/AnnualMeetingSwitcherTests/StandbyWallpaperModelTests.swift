import AppKit
import XCTest
@testable import LiveSwitcher

@MainActor
final class StandbyWallpaperModelTests: XCTestCase {
    func testRejectsUndecodableWallpaperImageInsteadOfSavingBlankStandby() throws {
        let defaults = isolatedDefaults()
        let invalidURL = temporaryInvalidImageURL(named: "broken-standby.png")
        let viewModel = SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            userDefaults: defaults
        )

        XCTAssertFalse(viewModel.addWallpaper(url: invalidURL))

        XCTAssertTrue(viewModel.backgroundWallpapers.isEmpty)
        XCTAssertNil(viewModel.activeWallpaperURL)
        XCTAssertNil(viewModel.backgroundImage)
        XCTAssertNil(defaults.stringArray(forKey: "backgroundWallpapers_paths"))
        XCTAssertNil(defaults.string(forKey: "activeWallpaper_path"))
    }

    func testLoadDataDropsPersistedUndecodableWallpaperImageAndRepairsActiveSelection() throws {
        let defaults = isolatedDefaults()
        let invalidURL = temporaryInvalidImageURL(named: "persisted-broken-standby.png")
        let validURL = temporaryImageURL(named: "valid-standby.png")
        defaults.set([invalidURL.path, validURL.path], forKey: "backgroundWallpapers_paths")
        defaults.set(invalidURL.path, forKey: "activeWallpaper_path")

        let viewModel = SwitcherViewModel(
            loadPersistedData: true,
            enableSystemVolumeObserver: false,
            userDefaults: defaults
        )

        XCTAssertEqual(viewModel.backgroundWallpapers, [validURL])
        XCTAssertEqual(viewModel.activeWallpaperURL, validURL)
        XCTAssertNotNil(viewModel.backgroundImage)
        XCTAssertEqual(defaults.stringArray(forKey: "backgroundWallpapers_paths"), [validURL.path])
        XCTAssertEqual(defaults.string(forKey: "activeWallpaper_path"), validURL.path)
    }

    private func isolatedDefaults() -> UserDefaults {
        let suiteName = "StandbyWallpaperModelTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func temporaryImageURL(named fileName: String) -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LiveSwitcherStandbyWallpaperTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(fileName)
        let image = NSImage(size: NSSize(width: 8, height: 8))
        image.lockFocus()
        NSColor.systemBlue.setFill()
        NSRect(x: 0, y: 0, width: 8, height: 8).fill()
        image.unlockFocus()
        let tiffData = image.tiffRepresentation!
        let bitmap = NSBitmapImageRep(data: tiffData)!
        let pngData = bitmap.representation(using: .png, properties: [:])!
        try? pngData.write(to: url)
        return url
    }

    private func temporaryInvalidImageURL(named fileName: String) -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LiveSwitcherStandbyWallpaperTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(fileName)
        try? Data("not an image".utf8).write(to: url)
        return url
    }
}
