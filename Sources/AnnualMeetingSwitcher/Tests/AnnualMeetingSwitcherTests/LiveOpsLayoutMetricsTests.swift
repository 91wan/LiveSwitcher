import XCTest
@testable import LiveSwitcher

final class LiveOpsLayoutMetricsTests: XCTestCase {
    func testLiveOpsHitTargetsStayOperatorSized() {
        XCTAssertGreaterThanOrEqual(LiveOpsLayoutMetrics.cardPadding, 10)
        XCTAssertGreaterThanOrEqual(LiveOpsLayoutMetrics.outputPrimaryButtonHeight, 42)
        XCTAssertGreaterThanOrEqual(LiveOpsLayoutMetrics.secondaryButtonHeight, 32)
    }

    func testLiveOpsSwitchToLiveButtonUsesMinimumHitTarget() throws {
        let source = try sourceText("Views/LiveOpsPanel.swift")

        XCTAssertFalse(source.contains(".frame(height: 28)"))
        XCTAssertTrue(source.contains(".frame(height: LiveOpsLayoutMetrics.secondaryButtonHeight)"))
    }

    func testLiveOpsPanelNoLongerOwnsSetupModeToggles() throws {
        let source = try sourceText("Views/LiveOpsPanel.swift")

        XCTAssertFalse(source.contains("LiveOpsToggleStyle"))
        XCTAssertFalse(source.contains("Toggle(isOn:"))
        XCTAssertFalse(source.contains("accessibilityLabel: \"Speaker mode\""))
        XCTAssertFalse(source.contains("accessibilityLabel: \"PPT mode\""))
        XCTAssertFalse(source.contains("Text(isOn ? \"ON\" : \"OFF\")"))
    }

    func testLiveOpsPanelNoLongerOwnsBGMTransportOrProgress() throws {
        let source = try sourceText("Views/LiveOpsPanel.swift")

        XCTAssertFalse(source.contains("bgmProgressRow"))
        XCTAssertFalse(source.contains("bgmTransportButtonSize"))
        XCTAssertFalse(source.contains(".disabled(viewModel.currentBGMItem == nil)"))
    }

    func testLiveOpsOutputDisabledStyleDoesNotDimWholeButton() throws {
        let source = try sourceText("Views/LiveOpsPanel.swift")

        XCTAssertFalse(source.contains(".opacity(model.isEnabled ? 1 : 0.62)"))
        XCTAssertTrue(source.contains("outputActionForeground(model)"))
        XCTAssertTrue(source.contains("StudioTheme.Tone.muted.opacity(0.18)"))
    }

    func testSetupRailsShareChromeMetricsAndFooterStyle() throws {
        let leftPanel = try sourceText("Views/Setup/LeftPanel.swift")
        let programRailFooter = try sourceText("Views/Setup/ProgramRailFooter.swift")
        let liveOps = try sourceText("Views/LiveOpsPanel.swift")
        let chrome = try sourceText("Views/SetupSideRailChrome.swift")

        XCTAssertTrue(chrome.contains("struct SetupSideRailChrome"))
        XCTAssertTrue(chrome.contains("struct SetupSideRailFooter"))
        XCTAssertTrue(chrome.contains("enum SetupSideRailLayoutMetrics"))
        XCTAssertTrue(chrome.contains("static let cornerRadius: CGFloat = 28"))
        XCTAssertTrue(chrome.contains("static let padding: CGFloat = 16"))
        XCTAssertTrue(chrome.contains("static let width = StudioTheme.directorRailWidth"))
        XCTAssertTrue(chrome.contains(".studioCard(cornerRadius: SetupSideRailLayoutMetrics.cornerRadius)"))

        XCTAssertTrue(leftPanel.contains("SetupSideRailChrome"))
        XCTAssertTrue(liveOps.contains("SetupSideRailChrome"))
        XCTAssertTrue(leftPanel.contains("ProgramRailFooter"))
        XCTAssertTrue(programRailFooter.contains("SetupSideRailFooter"))
        XCTAssertTrue(liveOps.contains("SetupSideRailFooter"))
        XCTAssertFalse(leftPanel.contains(".studioCard(cornerRadius: 28)"))
    }

    func testLiveOpsRailKeepsFooterPinnedAndContentScrollable() throws {
        let liveOps = try sourceText("Views/LiveOpsPanel.swift")
        let monitor = try sourceText("Views/ProgramMonitor/ProgramMonitorView.swift")

        XCTAssertTrue(liveOps.contains("scrollsContent: true"))
        XCTAssertTrue(liveOps.contains("CornerLogoCard()"))
        XCTAssertTrue(liveOps.contains("runtimeFooter"))
        XCTAssertTrue(liveOps.contains("进入现场"))
        XCTAssertTrue(liveOps.contains("handleSafeBroadcastToggle"))
        XCTAssertFalse(monitor.contains("CornerLogoCard()"))
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
