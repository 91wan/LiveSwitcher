import AppKit
import SwiftUI
import XCTest
@testable import LiveSwitcher

@MainActor
final class SwitcherViewModelSupportSmokeTests: SwitcherViewModelSmokeTestCase {
    func testWallpaperImportRejectsNonImageFiles() throws {
        let viewModel = makeViewModel()
        let wallpaperURL = try makeWallpaperURL()
        let textURL = try makeTempFileURL(ext: "txt")
        defer {
            try? FileManager.default.removeItem(at: wallpaperURL)
            try? FileManager.default.removeItem(at: textURL)
        }

        viewModel.addWallpaper(url: wallpaperURL)
        viewModel.addWallpaper(url: textURL)

        XCTAssertEqual(viewModel.backgroundWallpapers, [wallpaperURL])
        XCTAssertNil(viewModel.activeWallpaperURL)
    }


    func testWallpaperDropSupportDecodesPlainStringPathAsFileURL() {
        let path = "/tmp/my image.png"

        let decodedURL = WallpaperDropSupport.decodeFileURL(from: path)

        XCTAssertEqual(decodedURL, URL(fileURLWithPath: path))
        XCTAssertTrue(decodedURL?.isFileURL == true)
    }

}
