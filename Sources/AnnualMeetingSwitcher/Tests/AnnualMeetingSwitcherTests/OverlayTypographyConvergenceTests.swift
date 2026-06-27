import XCTest

final class OverlayTypographyConvergenceTests: XCTestCase {
    func testOverlayControlPanelUsesStudioTypeScaleInsteadOfRawSystemFontLiterals() throws {
        let source = try [
            "Views/OverlayControlPanel.swift",
            "Views/Overlays/OverlayComposerPicker.swift",
            "Views/Overlays/OverlayComposerControls.swift",
            "Views/Overlays/LowerThirdComposerCard.swift",
            "Views/Overlays/CountdownComposerCard.swift",
            "Views/Overlays/TickerComposerCard.swift",
            "Views/Overlays/OverlayPresetList.swift",
            "Views/Overlays/OverlayLivePreviewColumn.swift",
            "Views/Overlays/OverlayActiveStatusCard.swift"
        ].map(sourceText).joined(separator: "\n")

        XCTAssertFalse(
            source.contains(".font(.system(size:"),
            "Overlay control UI should use StudioTheme.TypeScale instead of raw font sizes."
        )
        XCTAssertTrue(
            source.contains("StudioTheme.TypeScale"),
            "Overlay control UI should reference the shared type scale."
        )
    }

    func testOverlayLivePreviewCanvasUsesStudioTypeScaleInsteadOfRawSystemFontLiterals() throws {
        try assertOverlayFileUsesTypeScale(relativePath: "Views/OverlayLivePreviewCanvas.swift")
    }

    private func assertOverlayFileUsesTypeScale(relativePath: String) throws {
        let source = try sourceText(relativePath)

        XCTAssertFalse(
            source.contains(".font(.system(size:"),
            "\(relativePath) should use StudioTheme.TypeScale instead of raw font sizes."
        )
        XCTAssertTrue(
            source.contains("StudioTheme.TypeScale"),
            "\(relativePath) should reference the shared type scale."
        )
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

    private func sourceText(_ relativePath: String) throws -> String {
        try String(contentsOf: sourceURL(relativePath), encoding: .utf8)
    }
}
