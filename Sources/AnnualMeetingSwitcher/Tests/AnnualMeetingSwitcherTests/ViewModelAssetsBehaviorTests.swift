import AppKit
import XCTest
@testable import LiveSwitcher

@MainActor
final class ViewModelAssetsBehaviorTests: XCTestCase {
    func testAddWallpaperRejectsNonRenderableImage() {
        let viewModel = makeViewModel()
        let invalidURL = temporaryInvalidImageURL()

        XCTAssertFalse(viewModel.addWallpaper(url: invalidURL))
        XCTAssertTrue(viewModel.backgroundWallpapers.isEmpty)
    }

    func testAddWallpaperDoesNotDuplicateExistingURL() {
        let viewModel = makeViewModel()
        let imageURL = temporaryImageURL()

        XCTAssertTrue(viewModel.addWallpaper(url: imageURL))
        XCTAssertTrue(viewModel.addWallpaper(url: imageURL))

        XCTAssertEqual(viewModel.backgroundWallpapers, [imageURL])
    }

    func testAddWallpaperSavesDataWhenImported() {
        let viewModel = makeViewModel()
        let imageURL = temporaryImageURL()
        var saveCount = 0
        viewModel.saveDataDidRun = { saveCount += 1 }

        XCTAssertTrue(viewModel.addWallpaper(url: imageURL))

        XCTAssertEqual(saveCount, 1)
    }

    func testRemoveWallpaperClearsActiveWallpaperWhenRemoved() {
        let viewModel = makeViewModel()
        let first = temporaryImageURL()
        let second = temporaryImageURL()
        viewModel.backgroundWallpapers = [first, second]
        viewModel.activeWallpaperURL = first

        viewModel.removeWallpaper(url: first)

        XCTAssertEqual(viewModel.backgroundWallpapers, [second])
        XCTAssertEqual(viewModel.activeWallpaperURL, second)
    }

    func testSetActiveWallpaperRequiresKnownWallpaper() {
        let viewModel = makeViewModel()
        let known = temporaryImageURL()
        let unknown = temporaryImageURL()
        viewModel.backgroundWallpapers = [known]

        viewModel.setActiveWallpaper(url: unknown)
        XCTAssertNil(viewModel.activeWallpaperURL)

        viewModel.setActiveWallpaper(url: known)
        XCTAssertEqual(viewModel.activeWallpaperURL, known)
    }

    func testSetCornerLogoRejectsNonRenderableImage() {
        let viewModel = makeViewModel()
        let invalidURL = temporaryInvalidImageURL()

        XCTAssertFalse(viewModel.setCornerLogo(url: invalidURL))
        XCTAssertNil(viewModel.cornerLogoURL)
    }

    func testRemoveCornerLogoClearsURLAndSavesData() {
        let viewModel = makeViewModel()
        viewModel.cornerLogoURL = temporaryImageURL()
        var saveCount = 0
        viewModel.saveDataDidRun = { saveCount += 1 }

        viewModel.removeCornerLogo()

        XCTAssertNil(viewModel.cornerLogoURL)
        XCTAssertEqual(saveCount, 1)
    }

    func testLoadBackgroundImageStillCancelsPreviousTask() {
        let source = try? repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+Assets.swift")

        XCTAssertTrue(source?.contains("cleanupBag.backgroundImageLoadTask?.cancel()") == true)
        XCTAssertTrue(source?.contains("cleanupBag.backgroundImageLoadTask = Task") == true)
    }

    func testLoadCornerLogoImageStillCancelsPreviousTask() {
        let source = try? repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+Assets.swift")

        XCTAssertTrue(source?.contains("cleanupBag.cornerLogoImageLoadTask?.cancel()") == true)
        XCTAssertTrue(source?.contains("cleanupBag.cornerLogoImageLoadTask = Task") == true)
    }

    private func makeViewModel() -> SwitcherViewModel {
        let suiteName = "ViewModelAssetsBehaviorTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            userDefaults: defaults
        )
    }

    private func temporaryInvalidImageURL() -> URL {
        let url = temporaryDirectory()
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("png")
        try? Data("not image".utf8).write(to: url)
        return url
    }

    private func temporaryImageURL() -> URL {
        let url = temporaryDirectory()
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("png")
        let image = NSImage(size: NSSize(width: 8, height: 8))
        image.lockFocus()
        NSColor.systemBlue.setFill()
        NSRect(x: 0, y: 0, width: 8, height: 8).fill()
        image.unlockFocus()
        guard let data = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: data),
              let png = bitmap.representation(using: .png, properties: [:]) else {
            XCTFail("Could not create image fixture")
            return url
        }
        try? png.write(to: url)
        return url
    }

    private func temporaryDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("LiveSwitcherAssetsBehaviorTests", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
