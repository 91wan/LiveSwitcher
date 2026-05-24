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
