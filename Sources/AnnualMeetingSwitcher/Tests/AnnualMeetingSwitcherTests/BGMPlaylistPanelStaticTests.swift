import XCTest

final class BGMPlaylistPanelStaticTests: XCTestCase {
    func testBGMPlaylistPanelIsSplitIntoFocusedSetupSubviews() throws {
        XCTAssertLessThanOrEqual(try sourceLineCount("Views/BGMPlaylistPanel.swift"), 250)

        let expectedSubviewFiles = [
            "Views/BGM/BGMPlaylistHeader.swift",
            "Views/BGM/BGMTransportControls.swift",
            "Views/BGM/BGMProgressRow.swift",
            "Views/BGM/BGMCategoryPicker.swift",
            "Views/BGM/BGMTrackList.swift",
            "Views/BGM/BGMTrackRow.swift",
            "Views/BGM/BGMImportControls.swift",
            "Views/BGM/BGMPanelStatusRow.swift"
        ]

        for relativePath in expectedSubviewFiles {
            let url = try sourceRootURL().appendingPathComponent(relativePath)
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), relativePath)
            XCTAssertLessThanOrEqual(try sourceLineCount(relativePath), 250, relativePath)
        }
    }

    func testBGMPlaylistPanelUsesSharedControlsStateForStatusAndAvailability() throws {
        let source = try bgmPanelSurfaceText()

        XCTAssertTrue(source.contains("private var bgmControlsState"))
        XCTAssertTrue(source.contains("displayStatusText"))
        XCTAssertTrue(source.contains("displayStatusKind"))
        XCTAssertFalse(source.contains("StatusBadge(viewModel.isBGMPlaying ? \"Playing\" : \"Ready\""))
        XCTAssertFalse(source.contains(".disabled(viewModel.currentBGMItem == nil)"))
    }

    func testBGMRowsUseWaveformThumbnailView() throws {
        let source = try bgmPanelSurfaceText()

        XCTAssertTrue(source.contains("ProgramThumbnailView("))
        XCTAssertTrue(source.contains("sourceURL: bgm.url"))
        XCTAssertTrue(source.contains("kind: .media"))
        XCTAssertTrue(source.contains("isVideo: false"))
    }

    func testPausedCurrentBGMRowUsesCuedIconInsteadOfPauseIcon() throws {
        let source = try bgmPanelSurfaceText()

        XCTAssertTrue(source.contains("isPlaying ? \"waveform\" : \"checkmark\""))
        XCTAssertFalse(source.contains("isPlaying ? \"waveform\" : \"pause.fill\""))
    }

    func testBGMStatusRowUsesSharedControlsStateCopy() throws {
        let source = try bgmPanelSurfaceText()

        XCTAssertTrue(source.contains("BGMPanelStatusRow(controls: bgmControlsState)"))
        XCTAssertTrue(source.contains("statusRowText(for: controls)"))
        XCTAssertFalse(source.contains("viewModel.bgmItems.isEmpty ? \"引擎已停止\" : \"BGM 已就绪\""))
        XCTAssertTrue(source.contains("case \"播放中\":"))
        XCTAssertTrue(source.contains("return \"BGM 播放中\""))
    }

    func testBGMPlayButtonsUseSelectedCategoryDefaultInsteadOfFirstLibraryItem() throws {
        let librarySource = try bgmPanelSurfaceText()
        let liveSource = try sourceText("Views/LiveQuickRail+BGM.swift")

        XCTAssertTrue(librarySource.contains("BGMDefaultSelectionPolicy.defaultItem"))
        XCTAssertTrue(liveSource.contains("BGMDefaultSelectionPolicy.defaultItem"))
        XCTAssertTrue(librarySource.contains("let defaultPlaybackItem"))
        XCTAssertTrue(librarySource.contains(".disabled(!(controls.canPlay && defaultPlaybackItem != nil))"))
        XCTAssertTrue(liveSource.contains("selectedCategory: playlist.displayCategory"))
        XCTAssertFalse(librarySource.contains("else if let first = viewModel.bgmItems.first"))
        XCTAssertFalse(liveSource.contains("else if let first = viewModel.bgmItems.first"))
    }

    func testBGMPlaylistPanelUsesStudioTypeScaleInsteadOfRawFontLiterals() throws {
        let source = try bgmPanelSurfaceText()

        XCTAssertFalse(
            source.contains(".font(.system(size:"),
            "BGM library UI should use StudioTheme.TypeScale instead of raw font sizes."
        )
        XCTAssertTrue(source.contains("StudioTheme.TypeScale"))
    }

    private func bgmPanelSurfaceText() throws -> String {
        let files = [
            "Views/BGMPlaylistPanel.swift",
            "Views/BGM/BGMPlaylistHeader.swift",
            "Views/BGM/BGMTransportControls.swift",
            "Views/BGM/BGMProgressRow.swift",
            "Views/BGM/BGMCategoryPicker.swift",
            "Views/BGM/BGMTrackList.swift",
            "Views/BGM/BGMTrackRow.swift",
            "Views/BGM/BGMImportControls.swift",
            "Views/BGM/BGMPanelStatusRow.swift"
        ]

        return try files
            .compactMap { relativePath -> String? in
                let url = try sourceRootURL().appendingPathComponent(relativePath)
                guard FileManager.default.fileExists(atPath: url.path) else { return nil }
                return try String(contentsOf: url, encoding: .utf8)
            }
            .joined(separator: "\n")
    }

    private func sourceLineCount(_ relativePath: String) throws -> Int {
        let text = try String(contentsOf: sourceRootURL().appendingPathComponent(relativePath), encoding: .utf8)
        return text.split(separator: "\n", omittingEmptySubsequences: false).count
    }

    private func sourceURL(_ relativePath: String) throws -> URL {
        let candidate = try sourceRootURL().appendingPathComponent(relativePath)
        if FileManager.default.fileExists(atPath: candidate.path) {
            return candidate
        }
        throw XCTSkip("Could not locate \(relativePath) from test source path.")
    }

    private func sourceRootURL() throws -> URL {
        var directory = URL(fileURLWithPath: #filePath)
        while directory.pathComponents.count > 1 {
            directory.deleteLastPathComponent()
            let candidate = directory
                .appendingPathComponent("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher")
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        throw XCTSkip("Could not locate source root from test source path.")
    }

    private func sourceText(_ relativePath: String) throws -> String {
        try String(contentsOf: sourceURL(relativePath), encoding: .utf8)
    }
}
