import XCTest
@testable import LiveSwitcher

final class Round3PolishTests: XCTestCase {
    func testToolbarButtonsShareActionHeight() throws {
        XCTAssertEqual(ToolbarLayoutMetrics.actionHeight, 46)

        let source = try sourceText("Views/MainToolbar.swift")
        XCTAssertTrue(source.contains(".frame(height: ToolbarLayoutMetrics.actionHeight)"))
        XCTAssertFalse(source.contains(".frame(height: 38)"))
    }

    func testRunQueueAndBGMLibraryDoNotRenderDragHandleDecorations() throws {
        let leftPanel = try sourceText("Views/LeftPanel.swift")
        let bgmPanel = try sourceText("Views/BGMPlaylistPanel.swift")

        XCTAssertFalse(leftPanel.contains("line.3.horizontal"))
        XCTAssertFalse(bgmPanel.contains("line.3.horizontal"))
        XCTAssertTrue(leftPanel.contains(".accessibilityHint(\"Drag to reorder.\""))
        XCTAssertTrue(bgmPanel.contains(".accessibilityHint(\"Drag to reorder.\""))
    }

    func testOverlayComposerStatusSeparatesEmptyDraftReadyAndLive() {
        XCTAssertEqual(OverlayComposerStatus.text(isLive: true, hasDraftInput: false, disabledReason: "请输入姓名"), "LIVE")
        XCTAssertEqual(OverlayComposerStatus.text(isLive: false, hasDraftInput: false, disabledReason: "请输入姓名"), "EMPTY")
        XCTAssertEqual(OverlayComposerStatus.text(isLive: false, hasDraftInput: true, disabledReason: "秒数需为 0-59"), "DRAFT")
        XCTAssertEqual(OverlayComposerStatus.text(isLive: false, hasDraftInput: true, disabledReason: nil), "READY")
    }

    func testHostSystemSummaryOmitsBuildNumber() {
        XCTAssertEqual(
            HostSystemSummary.shortVersionString(for: OperatingSystemVersion(majorVersion: 26, minorVersion: 5, patchVersion: 0)),
            "macOS 26.5"
        )
        XCTAssertEqual(
            HostSystemSummary.shortVersionString(for: OperatingSystemVersion(majorVersion: 14, minorVersion: 4, patchVersion: 1)),
            "macOS 14.4.1"
        )

        let liveOps = try? sourceText("Views/LiveOpsPanel.swift")
        XCTAssertTrue(liveOps?.contains("HostSystemSummary.shortVersionString") == true)
        XCTAssertFalse(liveOps?.contains("operatingSystemVersionString") == true)
    }

    func testAutoNextSwitchUsesWarningTint() throws {
        let source = try sourceText("Views/LeftPanel.swift")
        XCTAssertTrue(source.contains(".toggleStyle(.switch)"))
        XCTAssertTrue(source.contains(".tint(StudioTheme.Tone.warn)"))
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
