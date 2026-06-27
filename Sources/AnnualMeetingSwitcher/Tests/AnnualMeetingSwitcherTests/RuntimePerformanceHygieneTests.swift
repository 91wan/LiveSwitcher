import XCTest
@testable import LiveSwitcher

final class RuntimePerformanceHygieneTests: XCTestCase {
    func testWallpaperAndLogoImagesAreLoadedThroughAsyncDataPath() throws {
        let source = try sourceText("ViewModel+Assets.swift")

        XCTAssertTrue(source.contains("backgroundImageLoadTask"))
        XCTAssertTrue(source.contains("cornerLogoImageLoadTask"))
        XCTAssertTrue(source.contains("nonisolated private static func imageData"))
        XCTAssertTrue(source.contains("Task.detached(priority: .utility)"))
        XCTAssertFalse(source.contains("backgroundImage = NSImage(contentsOf:"))
        XCTAssertFalse(source.contains("cornerLogoImage = NSImage(contentsOf:"))
    }

    func testBulkProgramAndBGMImportsUseBatchAppendAPIs() throws {
        let bgmControls = try sourceText("ViewModel+BGMControls.swift")
        let programQueue = try sourceText("ViewModel+ProgramQueue.swift")
        let leftPanel = try sourceText("Views/LeftPanel.swift")
        let bgmPanel = try bgmPlaylistSurfaceText(filePath: #filePath)

        XCTAssertTrue(programQueue.contains("func addProgramItems(_ items: [ProgramItem])"))
        XCTAssertTrue(bgmControls.contains("func addBGMItems(_ items: [BGMItem])"))
        XCTAssertTrue(leftPanel.contains("viewModel.addProgramItems(items)"))
        XCTAssertTrue(bgmPanel.contains("viewModel.addBGMItems(importedItems)"))
        XCTAssertFalse(leftPanel.contains("for url in panel.urls {\n                let item = ProgramItem"))
        XCTAssertFalse(bgmPanel.contains("viewModel.addBGMItem(bgm)"))
    }

    func testBGMRealtimeMeterIsNotPublishedOnWholeViewModel() throws {
        let source = try sourceText("ViewModel.swift")

        XCTAssertFalse(source.contains("@Published var bgmRealtimeLevelDB"))
        XCTAssertTrue(source.contains("var bgmRealtimeLevelDB: Float?"))
    }

    private func sourceText(_ relativePath: String) throws -> String {
        try String(contentsOf: sourceURL(relativePath), encoding: .utf8)
    }

    private func sourceURL(_ relativePath: String) throws -> URL {
        var directory = URL(fileURLWithPath: #filePath)
        while directory.pathComponents.count > 1 {
            directory.deleteLastPathComponent()
            let candidate = directory
                .appendingPathComponent("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher")
                .appendingPathComponent(relativePath)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        throw XCTSkip("Could not locate \(relativePath) from test source path.")
    }
}
