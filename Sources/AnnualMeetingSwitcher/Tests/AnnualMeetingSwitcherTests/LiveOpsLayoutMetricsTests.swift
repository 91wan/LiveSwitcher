import XCTest
@testable import LiveSwitcher

final class LiveOpsLayoutMetricsTests: XCTestCase {
    func testLiveOpsHitTargetsStayOperatorSized() {
        XCTAssertGreaterThanOrEqual(LiveOpsLayoutMetrics.cardPadding, 10)
        XCTAssertGreaterThanOrEqual(LiveOpsLayoutMetrics.outputPrimaryButtonHeight, 42)
        XCTAssertGreaterThanOrEqual(LiveOpsLayoutMetrics.bgmTransportButtonSize, 32)
        XCTAssertGreaterThanOrEqual(LiveOpsLayoutMetrics.modeRowHeight, 34)
    }

    func testLiveOpsModeControlsUseSwitchToggles() throws {
        let source = try sourceText("Views/LiveOpsPanel.swift")

        XCTAssertTrue(source.contains("LiveOpsToggleStyle"))
        XCTAssertTrue(source.contains("Toggle(isOn:"))
        XCTAssertTrue(source.contains("accessibilityLabel: \"Speaker mode\""))
        XCTAssertTrue(source.contains("accessibilityLabel: \"PPT mode\""))
        XCTAssertTrue(source.contains(".accessibilityLabel(accessibilityLabel)"))
        XCTAssertFalse(source.contains("Text(isOn ? \"ON\" : \"OFF\")"))
    }

    func testLiveOpsBGMProgressOnlyRendersForCurrentTrack() throws {
        let source = try sourceText("Views/LiveOpsPanel.swift")

        XCTAssertTrue(source.contains("if viewModel.currentBGMItem != nil {\n                bgmProgressRow"))
        XCTAssertFalse(source.contains(".disabled(viewModel.currentBGMItem == nil)"))
    }

    func testLiveOpsOutputDisabledStyleDoesNotDimWholeButton() throws {
        let source = try sourceText("Views/LiveOpsPanel.swift")

        XCTAssertFalse(source.contains(".opacity(model.isEnabled ? 1 : 0.62)"))
        XCTAssertTrue(source.contains("outputActionForeground(model)"))
        XCTAssertTrue(source.contains("StudioTheme.Tone.muted.opacity(0.18)"))
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
