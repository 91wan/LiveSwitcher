import XCTest
@testable import LiveSwitcher

final class Round3PolishTests: XCTestCase {
    func testToolbarButtonsShareActionHeight() throws {
        XCTAssertEqual(ToolbarLayoutMetrics.actionHeight, 46)

        let source = try sourceText("Views/MainToolbar.swift")
        XCTAssertTrue(source.contains(".frame(height: ToolbarLayoutMetrics.actionHeight)"))
        XCTAssertFalse(source.contains(".frame(height: 38)"))
    }

    func testRunQueueUsesExplicitDragHandleAndBGMLibraryDoesNotRenderDragHandleDecorations() throws {
        let leftPanel = try sourceText("Views/LeftPanel.swift")
        let dragHandle = try sourceText("Views/ProgramQueue/ProgramQueueDragHandle.swift")
        let sourceRow = try sourceText("Views/ProgramQueue/SignalSourceRowHeader.swift")
        let bgmPanel = try sourceText("Views/BGMPlaylistPanel.swift")

        XCTAssertTrue(sourceRow.contains("ProgramQueueDragHandle"))
        XCTAssertTrue(dragHandle.contains("line.3.horizontal"))
        XCTAssertTrue(leftPanel.contains("拖拽左侧手柄调整顺序"))
        XCTAssertFalse(bgmPanel.contains("line.3.horizontal"))
        XCTAssertTrue(bgmPanel.contains(".accessibilityHint(\"拖拽调整顺序。\""))
    }

    func testOverlayComposerStatusSeparatesEmptyDraftReadyAndLive() {
        XCTAssertEqual(OverlayComposerStatus.text(isLive: true, hasDraftInput: false, disabledReason: "请输入姓名"), "上屏")
        XCTAssertEqual(OverlayComposerStatus.text(isLive: false, hasDraftInput: false, disabledReason: "请输入姓名"), "空")
        XCTAssertEqual(OverlayComposerStatus.text(isLive: false, hasDraftInput: true, disabledReason: "秒数需为 0-59"), "草稿")
        XCTAssertEqual(OverlayComposerStatus.text(isLive: false, hasDraftInput: true, disabledReason: nil), "就绪")
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
        try LiveSwitcherTests.sourceText(relativePath, filePath: #filePath)
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
