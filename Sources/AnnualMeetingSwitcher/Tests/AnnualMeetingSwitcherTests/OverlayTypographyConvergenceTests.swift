import XCTest

final class OverlayTypographyConvergenceTests: XCTestCase {
    func testOverlayControlPanelUsesStudioTypeScaleInsteadOfRawSystemFontLiterals() throws {
        let source = try overlayControlSurfaceText(filePath: #filePath)

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
        let source = try String(contentsOf: sourceURL(relativePath), encoding: .utf8)

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
}
