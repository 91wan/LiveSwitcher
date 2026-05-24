import XCTest
@testable import LiveSwitcher

final class LiveWallpaperQuickStatusModelTests: XCTestCase {
    func testEmptyWallpaperLibraryUsesExplicitWarningStatus() {
        let model = LiveWallpaperQuickStatusModel.make(
            wallpaperCount: 0,
            activeWallpaperTitle: nil
        )

        XCTAssertEqual(model.statusText, "NO WALLPAPER")
        XCTAssertEqual(model.statusKind, .warn)
        XCTAssertEqual(model.displayTitle, "No standby wallpaper")
        XCTAssertFalse(model.canCycle)
    }

    func testReadyWallpaperLibraryDoesNotExposeBareCountAsWarning() {
        let model = LiveWallpaperQuickStatusModel.make(
            wallpaperCount: 2,
            activeWallpaperTitle: "Fallback.png"
        )

        XCTAssertEqual(model.statusText, "2")
        XCTAssertEqual(model.statusKind, .ready)
        XCTAssertEqual(model.displayTitle, "Fallback.png")
        XCTAssertTrue(model.canCycle)
    }

    func testSingleWallpaperCanDisplayButNotCycle() {
        let model = LiveWallpaperQuickStatusModel.make(
            wallpaperCount: 1,
            activeWallpaperTitle: "Fallback.png"
        )

        XCTAssertEqual(model.statusKind, .ready)
        XCTAssertEqual(model.displayTitle, "Fallback.png")
        XCTAssertFalse(model.canCycle)
    }
}
