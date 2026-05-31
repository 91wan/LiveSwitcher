import XCTest
@testable import LiveSwitcher

final class ModeToggleLayoutTests: XCTestCase {
    func testLiveModesUseEqualWidthHorizontalCardsAndSpeakerBindingSideEffect() throws {
        let liveMode = try sourceText("Views/LiveModeView.swift")
        let toolbar = try sourceText("Views/MainToolbar.swift")

        XCTAssertTrue(toolbar.contains("ToolbarModeButton("))
        XCTAssertTrue(toolbar.contains(".frame(width: ToolbarLayoutMetrics.modeButtonMinWidth)"))
        XCTAssertTrue(toolbar.contains("viewModel.toggleSpeakerMode()"))
        XCTAssertTrue(toolbar.contains("viewModel.togglePPTMode(source: .toolbar)"))
        XCTAssertFalse(toolbar.contains("viewModel.isPageInterceptEnabled.toggle()"))
        XCTAssertFalse(toolbar.contains("Toggle(isOn"))
        XCTAssertFalse(liveMode.contains("modeToggleRow("))
        XCTAssertFalse(liveMode.contains("ModeToggleCard("))
        XCTAssertFalse(liveMode.contains("isOn: $viewModel.isSpeakerMode"))
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
