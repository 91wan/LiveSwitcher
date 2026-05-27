import XCTest

final class BGMPlaylistPanelStaticTests: XCTestCase {
    func testBGMPlaylistPanelUsesSharedControlsStateForStatusAndAvailability() throws {
        let source = try String(contentsOf: sourceURL("Views/BGMPlaylistPanel.swift"), encoding: .utf8)

        XCTAssertTrue(source.contains("private var bgmControlsState"))
        XCTAssertTrue(source.contains("displayStatusText"))
        XCTAssertTrue(source.contains("displayStatusKind"))
        XCTAssertFalse(source.contains("StatusBadge(viewModel.isBGMPlaying ? \"Playing\" : \"Ready\""))
        XCTAssertFalse(source.contains(".disabled(viewModel.currentBGMItem == nil)"))
    }

    func testBGMRowsUseWaveformThumbnailView() throws {
        let source = try String(contentsOf: sourceURL("Views/BGMPlaylistPanel.swift"), encoding: .utf8)

        XCTAssertTrue(source.contains("ProgramThumbnailView("))
        XCTAssertTrue(source.contains("sourceURL: bgm.url"))
        XCTAssertTrue(source.contains("kind: .media"))
        XCTAssertTrue(source.contains("isVideo: false"))
    }

    func testPausedCurrentBGMRowUsesCuedIconInsteadOfPauseIcon() throws {
        let source = try String(contentsOf: sourceURL("Views/BGMPlaylistPanel.swift"), encoding: .utf8)

        XCTAssertTrue(source.contains("isPlaying ? \"waveform\" : \"checkmark\""))
        XCTAssertFalse(source.contains("isPlaying ? \"waveform\" : \"pause.fill\""))
    }

    func testBGMStatusRowUsesSharedControlsStateCopy() throws {
        let source = try String(contentsOf: sourceURL("Views/BGMPlaylistPanel.swift"), encoding: .utf8)

        XCTAssertTrue(source.contains("let controls = bgmControlsState"))
        XCTAssertTrue(source.contains("statusRowText(for: controls)"))
        XCTAssertFalse(source.contains("viewModel.bgmItems.isEmpty ? \"引擎已停止\" : \"BGM 已就绪\""))
        XCTAssertTrue(source.contains("case \"播放中\":"))
        XCTAssertTrue(source.contains("return \"BGM 播放中\""))
    }

    func testBGMPlaylistPanelUsesStudioTypeScaleInsteadOfRawFontLiterals() throws {
        let source = try String(contentsOf: sourceURL("Views/BGMPlaylistPanel.swift"), encoding: .utf8)

        XCTAssertFalse(
            source.contains(".font(.system(size:"),
            "BGM library UI should use StudioTheme.TypeScale instead of raw font sizes."
        )
        XCTAssertTrue(source.contains("StudioTheme.TypeScale"))
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
