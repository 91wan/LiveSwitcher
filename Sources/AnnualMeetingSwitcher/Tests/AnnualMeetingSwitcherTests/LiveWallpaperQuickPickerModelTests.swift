import XCTest
@testable import LiveSwitcher

final class LiveWallpaperQuickPickerModelTests: XCTestCase {
    func testEmptyWallpaperLibraryUsesExplicitWarningStatus() {
        let model = LiveWallpaperQuickPickerModel.make(
            wallpapers: [],
            activeWallpaperURL: nil
        )

        XCTAssertTrue(model.isEmpty)
        XCTAssertEqual(model.statusText, "NO WALLPAPER")
        XCTAssertEqual(model.statusKind, .warn)
        XCTAssertEqual(model.displayTitle, "No standby wallpaper")
        XCTAssertTrue(model.items.isEmpty)
    }

    func testPickerMapsWallpaperItemsAndActiveState() {
        let first = URL(fileURLWithPath: "/tmp/Fallback A.png")
        let second = URL(fileURLWithPath: "/tmp/Sponsor Wall.jpg")

        let model = LiveWallpaperQuickPickerModel.make(
            wallpapers: [first, second],
            activeWallpaperURL: second
        )

        XCTAssertFalse(model.isEmpty)
        XCTAssertEqual(model.statusText, "2")
        XCTAssertEqual(model.statusKind, .ready)
        XCTAssertEqual(model.displayTitle, "Sponsor Wall.jpg")
        XCTAssertEqual(model.items.map(\.url), [first, second])
        XCTAssertEqual(model.items.map(\.title), ["Fallback A.png", "Sponsor Wall.jpg"])
        XCTAssertEqual(model.items.map(\.isActive), [false, true])
    }

    func testPickerFallsBackWhenNoWallpaperIsSelected() {
        let first = URL(fileURLWithPath: "/tmp/Fallback A.png")

        let model = LiveWallpaperQuickPickerModel.make(
            wallpapers: [first],
            activeWallpaperURL: nil
        )

        XCTAssertEqual(model.statusText, "1")
        XCTAssertEqual(model.statusKind, .ready)
        XCTAssertEqual(model.displayTitle, "No wallpaper selected")
        XCTAssertEqual(model.items.map(\.isActive), [false])
    }

    func testPickerIgnoresStaleActiveWallpaperOutsideLibrary() {
        let first = URL(fileURLWithPath: "/tmp/Fallback A.png")
        let stale = URL(fileURLWithPath: "/tmp/Missing.png")

        let model = LiveWallpaperQuickPickerModel.make(
            wallpapers: [first],
            activeWallpaperURL: stale
        )

        XCTAssertEqual(model.displayTitle, "No wallpaper selected")
        XCTAssertEqual(model.items.map(\.isActive), [false])
    }
}
