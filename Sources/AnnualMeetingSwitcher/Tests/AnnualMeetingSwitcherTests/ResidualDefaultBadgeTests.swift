import XCTest

final class ResidualDefaultBadgeTests: XCTestCase {
    func testHelpHeaderDoesNotRenderDefaultHelpBadge() throws {
        let source = try sourceText("Views/HelpPopoverView.swift")

        XCTAssertFalse(source.contains("StatusBadge(\"Help\", kind: .idle)"))
    }

    func testAudioLibraryDoesNotRenderDefaultLibraryBadge() throws {
        let source = try sourceText("Views/AudioMixerView.swift")

        XCTAssertFalse(source.contains("StatusBadge(\"LIBRARY\", kind: .idle)"))
    }

    func testOverlayPanelDoesNotRenderOffStatesAsBadges() throws {
        let source = try sourceText("Views/OverlayControlPanel.swift")

        XCTAssertFalse(source.contains("StatusBadge(activeOverlayCount == 0 ? \"OFF\""))
        XCTAssertFalse(source.contains("StatusBadge(isLive ? \"LIVE\" : \"OFF\""))
    }

    func testBGMPlaylistHeaderUsesSharedBadgeVisibilityPolicy() throws {
        let source = try bgmPlaylistSurfaceText(filePath: #filePath)

        XCTAssertTrue(
            source.contains("StatusBadgeVisibilityPolicy.shouldShow"),
            "BGM playlist should use the shared status-by-exception badge policy."
        )
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
