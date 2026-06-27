import XCTest

final class OverlayControlPanelStaticTests: XCTestCase {
    func testOverlayControlPanelIsSplitIntoFocusedSetupSubviews() throws {
        XCTAssertLessThanOrEqual(try sourceLineCount("Views/OverlayControlPanel.swift"), 250)

        let expectedSubviewFiles = [
            "Views/Overlays/OverlayComposerPicker.swift",
            "Views/Overlays/LowerThirdComposerCard.swift",
            "Views/Overlays/CountdownComposerCard.swift",
            "Views/Overlays/TickerComposerCard.swift",
            "Views/Overlays/OverlayPresetList.swift",
            "Views/Overlays/OverlayLivePreviewColumn.swift",
            "Views/Overlays/OverlayActiveStatusCard.swift"
        ]

        for relativePath in expectedSubviewFiles {
            let url = try sourceRootURL().appendingPathComponent(relativePath)
            if FileManager.default.fileExists(atPath: url.path) {
                XCTAssertLessThanOrEqual(try sourceLineCount(relativePath), 250, relativePath)
            } else {
                XCTFail(relativePath)
            }
        }
    }

    private func sourceLineCount(_ relativePath: String) throws -> Int {
        let text = try String(contentsOf: sourceRootURL().appendingPathComponent(relativePath), encoding: .utf8)
        return text.split(separator: "\n", omittingEmptySubsequences: false).count
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
}
