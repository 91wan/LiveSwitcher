import XCTest
@testable import LiveSwitcher

final class I18nPolicyTests: XCTestCase {
    func testPrimaryChromeUsesChineseInsteadOfBilingualHeaders() throws {
        let files = [
            "Views/AudioMixerView.swift",
            "Views/SettingsView.swift",
            "Models/LiveConsoleStatus.swift",
            "Views/SafetyCockpitView.swift",
            "Views/PreflightPopoverView.swift"
        ]
        let combined = try files.map(sourceText).joined(separator: "\n")

        XCTAssertFalse(combined.contains("Audio / 音频"))
        XCTAssertFalse(combined.contains("Overlays / 叠层"))
        XCTAssertFalse(combined.contains("Live Preflight / 现场检查"))
        XCTAssertFalse(combined.contains("Live Safety Cockpit / 现场安全台"))
        XCTAssertTrue(combined.contains("Text(\"音频\")"))
        XCTAssertTrue(combined.contains("Text(\"叠层字幕\")"))
    }

    func testRunAndLiveChromeUseChineseLabels() throws {
        let liveMode = try sourceText("Views/LiveModeView.swift")
        let tabs = try sourceText("Models/MainConsoleTab.swift")
        let app = try sourceText("App.swift")

        XCTAssertFalse(liveMode.contains("Text(\"Sources\")"))
        XCTAssertFalse(liveMode.contains("Label(\"Take Next\""))
        XCTAssertTrue(liveMode.contains("Text(\"信号源\")"))
        XCTAssertTrue(liveMode.contains("Label(\"下一项\""))
        XCTAssertFalse(liveMode.contains("视频播毕自动下一条"))
        XCTAssertTrue(try sourceText("Views/LeftPanel.swift").contains("自动续播下一项"))
        XCTAssertTrue(tabs.contains("LiveSwitcher · 导播台"))
        XCTAssertTrue(tabs.contains("return \"节目单\""))
        XCTAssertTrue(app.contains("Button(\"节目单\")"))
        XCTAssertFalse(app.contains("CommandMenu(\"Mode\")"))
        XCTAssertFalse(app.contains("CommandMenu(\"Setup\")"))
        XCTAssertFalse(app.contains("Paste Speakers from Clipboard"))
        XCTAssertTrue(app.contains("CommandMenu(\"模式\")"))
        XCTAssertTrue(app.contains("CommandMenu(\"准备页面\")"))
        XCTAssertTrue(app.contains("从剪贴板粘贴主持人"))
    }

    func testPanicAndPreflightCopyUseChineseOperatorTerms() throws {
        let panic = try sourceText("Models/PanicButtonModel.swift")
        let status = try sourceText("Models/LiveConsoleStatus.swift")

        XCTAssertFalse(panic.contains("Blackout"))
        XCTAssertFalse(panic.contains("Stage black"))
        XCTAssertTrue(panic.contains("紧急切黑"))
        XCTAssertTrue(status.contains("检查"))
        XCTAssertTrue(status.contains("警告"))

        let model = PreflightButtonModel.make(
            summary: LivePreflightSummary(status: .fail, title: "未就绪", message: "", passCount: 3, warnCount: 2, failCount: 1)
        )
        XCTAssertEqual(model.title, "检查")
        XCTAssertEqual(model.value, "1 故障 · 2 警告")
    }

    func testFadeToBlackOperatorCopyUsesChineseInsteadOfFTB() throws {
        let liveMode = try sourceText("Views/LiveModeView.swift")
        let output = try sourceText("Output/OutputWindowController.swift")

        XCTAssertFalse(liveMode.contains("\"FTB\""))
        XCTAssertFalse(liveMode.contains("从 FTB 恢复"))
        XCTAssertFalse(liveMode.contains("FTB 切黑"))
        XCTAssertFalse(output.contains("Fade to black active"))

        XCTAssertTrue(liveMode.contains("\"切黑\""))
        XCTAssertTrue(liveMode.contains("\"恢复\""))
        XCTAssertTrue(liveMode.contains("\"已切黑\""))
        XCTAssertTrue(liveMode.contains("\"淡出至黑场\""))
        XCTAssertTrue(liveMode.contains("\"从黑场恢复\""))
        XCTAssertTrue(liveMode.contains("\"恢复画面\""))
        XCTAssertTrue(output.contains("\"切黑已启用\""))
    }

    func testVisibleConsoleChromeDoesNotRegressToRoundSevenEnglishLabels() throws {
        let files = [
            "Views/LiveOpsPanel.swift",
            "Views/OverlayControlPanel.swift",
            "Views/AudioMixerView.swift",
            "Views/LeftPanel.swift",
            "Views/RunQueueView.swift",
            "Views/CornerLogoCard.swift",
            "Models/HelpCopyModel.swift",
            "Models/LivePreflight.swift",
            "Models/ProgramTransitionControlModel.swift",
            "Models/OverlayLivePreviewModel.swift",
            "Models/LiveBGMQuickPickerModel.swift",
            "Resources/en.lproj/Localizable.strings"
        ]
        let combined = try files.map(sourceText).joined(separator: "\n")
        let staleLabels = [
            "Live Ops",
            "Setup output",
            "BGM Library",
            "Overlay Composer",
            "Live Preview",
            "Active Stack",
            "Send Live",
            "Switch to Live",
            "Audio summary",
            "Program transition",
            "Run queue footer",
            "Corner Logo",
            "Import logo",
            "PPT Mode",
            "No live overlays",
            "No BGM selected",
            "Follow Program",
            "Follow Source",
            "BGM Only",
            "Mixed"
        ]

        for label in staleLabels {
            XCTAssertFalse(combined.contains(label), "Visible console chrome should not contain stale English label: \(label)")
        }

        XCTAssertTrue(combined.contains("现场控制"))
        XCTAssertTrue(combined.contains("叠层编辑"))
        XCTAssertTrue(combined.contains("BGM 库"))
        XCTAssertTrue(combined.contains("节目转场"))
        XCTAssertTrue(combined.contains("角标"))
    }

    func testI18nPolicyDocumentExistsAndPreservesAllowedTerms() throws {
        let policy = try repoText("docs/style/i18n-policy.md")

        XCTAssertTrue(policy.contains("中文为主"))
        XCTAssertTrue(policy.contains("BGM"))
        XCTAssertTrue(policy.contains("PPT"))
        XCTAssertTrue(policy.contains("HTML"))
        XCTAssertTrue(policy.contains("dB"))
        XCTAssertFalse(policy.contains("- FTB"))
        XCTAssertFalse(policy.contains("`FTB`"))
    }

    private func sourceText(_ relativePath: String) throws -> String {
        try String(contentsOf: sourceURL(relativePath), encoding: .utf8)
    }

    private func sourceURL(_ relativePath: String) throws -> URL {
        try repositoryRoot()
            .appendingPathComponent("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher")
            .appendingPathComponent(relativePath)
    }

    private func repoText(_ relativePath: String) throws -> String {
        try String(contentsOf: repositoryRoot().appendingPathComponent(relativePath), encoding: .utf8)
    }

    private func repositoryRoot() throws -> URL {
        var directory = URL(fileURLWithPath: #filePath)
        while directory.pathComponents.count > 1 {
            directory.deleteLastPathComponent()
            if FileManager.default.fileExists(atPath: directory.appendingPathComponent("Package.swift").path),
               FileManager.default.fileExists(atPath: directory.appendingPathComponent("Sources/AnnualMeetingSwitcher").path),
               FileManager.default.fileExists(atPath: directory.appendingPathComponent("docs").path) {
                return directory
            }
        }
        throw XCTSkip("Could not locate repository root.")
    }
}
