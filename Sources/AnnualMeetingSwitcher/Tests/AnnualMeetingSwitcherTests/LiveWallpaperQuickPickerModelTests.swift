import XCTest
@testable import LiveSwitcher

final class LiveWallpaperQuickPickerModelTests: XCTestCase {
    func testEmptyWallpaperLibraryUsesExplicitWarningStatus() {
        let model = LiveWallpaperQuickPickerModel.make(
            wallpapers: [],
            activeWallpaperURL: nil
        )

        XCTAssertTrue(model.isEmpty)
        XCTAssertEqual(model.statusText, "无壁纸")
        XCTAssertEqual(model.statusKind, .warn)
        XCTAssertEqual(model.displayTitle, "没有待机壁纸")
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
        XCTAssertEqual(model.displayTitle, "未选择壁纸")
        XCTAssertEqual(model.items.map(\.isActive), [false])
    }

    func testPickerIgnoresStaleActiveWallpaperOutsideLibrary() {
        let first = URL(fileURLWithPath: "/tmp/Fallback A.png")
        let stale = URL(fileURLWithPath: "/tmp/Missing.png")

        let model = LiveWallpaperQuickPickerModel.make(
            wallpapers: [first],
            activeWallpaperURL: stale
        )

        XCTAssertEqual(model.displayTitle, "未选择壁纸")
        XCTAssertEqual(model.items.map(\.isActive), [false])
    }

    func testLiveWallpaperPickerModelCarriesSpecificSelectableWallpaperURLs() {
        let first = URL(fileURLWithPath: "/tmp/Fallback A.png")
        let second = URL(fileURLWithPath: "/tmp/Sponsor Wall.jpg")
        let third = URL(fileURLWithPath: "/tmp/Closing.png")

        let model = LiveWallpaperQuickPickerModel.make(
            wallpapers: [first, second, third],
            activeWallpaperURL: second
        )

        XCTAssertEqual(model.statusText, "3")
        XCTAssertEqual(model.displayTitle, "Sponsor Wall.jpg")
        XCTAssertEqual(model.items.map(\.id), [first, second, third])
        XCTAssertEqual(model.items.map(\.url), [first, second, third])
        XCTAssertEqual(model.items.map(\.title), ["Fallback A.png", "Sponsor Wall.jpg", "Closing.png"])
        XCTAssertEqual(model.items.map(\.isActive), [false, true, false])
    }
}
