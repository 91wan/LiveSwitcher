import XCTest
@testable import LiveSwitcher

final class ModeToggleLayoutTests: XCTestCase {
    func testLiveModesUseEqualWidthHorizontalCardsAndSpeakerBindingSideEffect() throws {
        let liveMode = try sourceText("Views/LiveModeView.swift")
        let toolbar = try sourceText("Views/MainToolbar.swift")

        XCTAssertTrue(toolbar.contains("ToolbarModeButton("))
        XCTAssertTrue(toolbar.contains(".frame(width: ToolbarLayoutMetrics.modeButtonMinWidth)"))
        XCTAssertTrue(toolbar.contains("viewModel.toggleSpeakerMode()"))
        XCTAssertTrue(toolbar.contains("viewModel.togglePPTMode(source: pptModeToggleSource)"))
        XCTAssertFalse(toolbar.contains("viewModel.isPageInterceptEnabled.toggle()"))
        XCTAssertFalse(toolbar.contains("Toggle(isOn"))
        XCTAssertFalse(liveMode.contains("modeToggleRow("))
        XCTAssertFalse(liveMode.contains("ModeToggleCard("))
        XCTAssertFalse(liveMode.contains("isOn: $viewModel.isSpeakerMode"))
    }

    func testToolbarModeButtonVisibleCardIsInsideButtonLabelHitTarget() throws {
        let toolbar = try sourceText("Views/MainToolbar.swift")
        let labelBody = try toolbarModeButtonLabelBody(in: toolbar)

        XCTAssertTrue(labelBody.contains(".frame(width: ToolbarLayoutMetrics.modeButtonMinWidth)"))
        XCTAssertTrue(labelBody.contains(".frame(height: ToolbarLayoutMetrics.actionHeight)"))
        XCTAssertTrue(labelBody.contains(".contentShape(Rectangle())"))
        XCTAssertTrue(labelBody.contains(".background("))
        XCTAssertTrue(labelBody.contains(".overlay("))
        XCTAssertTrue(labelBody.contains(".shadow("))
        XCTAssertFalse(toolbar.contains(".onTapGesture"))
        XCTAssertEqual(toolbar.components(separatedBy: "viewModel.toggleSpeakerMode()").count - 1, 1)
        XCTAssertEqual(toolbar.components(separatedBy: "viewModel.togglePPTMode(source: pptModeToggleSource)").count - 1, 1)
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

    private func toolbarModeButtonLabelBody(in source: String) throws -> String {
        guard let buttonStart = source.range(of: "Button(action: action) {"),
              let styleStart = source.range(of: "\n        .buttonStyle(.plain)", range: buttonStart.upperBound..<source.endIndex) else {
            throw XCTSkip("Could not locate ToolbarModeButton label body.")
        }
        return String(source[buttonStart.upperBound..<styleStart.lowerBound])
    }
}
