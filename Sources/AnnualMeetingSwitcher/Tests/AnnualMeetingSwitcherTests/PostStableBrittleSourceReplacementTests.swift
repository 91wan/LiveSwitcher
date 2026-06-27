import XCTest

final class PostStableBrittleSourceReplacementTests: XCTestCase {
    func testRetiredLiveSurfaceSourceStringAssertionsStayRetired() throws {
        let source = try sourceText("LiveModeLayoutTests.swift")
        let retiredNeedles = [
            "LiveBGMQuickPickerModel.make",
            "LiveBGMPlaylistModel.make",
            "选择 BGM 分类",
            "BGMCategory.allCases",
            "viewModel.toggleBGM(row.item)",
            "playlist.categoryButtonTitle",
            "LiveBGMChooserPopover",
            "全部曲目",
            "LiveWallpaperQuickPickerModel.make",
            "选择待机壁纸",
            "viewModel.setActiveWallpaper(url: item.url)",
            "ForEach(picker.items)"
        ]

        for needle in retiredNeedles {
            XCTAssertFalse(source.contains(needle), "\(needle) should be covered by model/behavior tests instead of LiveModeLayoutTests source strings")
        }
    }

    private func sourceText(_ relativePath: String) throws -> String {
        let url = try testSourceURL(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func testSourceURL(_ relativePath: String) throws -> URL {
        var directory = URL(fileURLWithPath: #filePath)
        while directory.pathComponents.count > 1 {
            directory.deleteLastPathComponent()
            let candidate = directory
                .appendingPathComponent("Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests")
                .appendingPathComponent(relativePath)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        throw XCTSkip("Could not locate \(relativePath) from test source path.")
    }
}
