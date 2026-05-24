import XCTest
@testable import LiveSwitcher

final class AudioTransitionControlModelTests: XCTestCase {
    func testTransitionCardTextDescribesProgramTransitionNotBGMFade() {
        let model = ProgramTransitionControlModel(crossfadeDuration: 1.2)

        XCTAssertEqual(model.title, "Program transition")
        XCTAssertFalse(model.title.localizedCaseInsensitiveContains("BGM fade"))
        XCTAssertFalse(model.subtitle.localizedCaseInsensitiveContains("BGM fade"))
        XCTAssertTrue(model.subtitle.contains("节目画面"))
        XCTAssertEqual(model.statusText, "1.2s")
    }

    func testTransitionControlUsesNeutralConfigurationTone() {
        let model = ProgramTransitionControlModel(crossfadeDuration: 1.2)

        XCTAssertEqual(model.statusKind, .idle)
        XCTAssertEqual(model.controlTone, .configuration)
        XCTAssertEqual(model.controlTone.semanticToken, "action.primary")
    }

    func testTransitionViewsDoNotHardcodeWarningTone() throws {
        let monitor = try sourceText("Views/ProgramMonitorView.swift")
        let mixer = try sourceText("Views/AudioMixerView.swift")

        XCTAssertFalse(monitor.contains(".tint(StudioTheme.Tone.warn)"))
        XCTAssertFalse(monitor.contains(".foregroundStyle(StudioTheme.Tone.warn)"))
        XCTAssertTrue(monitor.contains(".tint(model.controlTone.sliderTint)"))
        XCTAssertTrue(monitor.contains(".foregroundStyle(model.controlTone.valueTint)"))
        XCTAssertTrue(mixer.contains("status: (model.statusText, model.statusKind)"))
        XCTAssertTrue(mixer.contains(".tint(model.controlTone.sliderTint)"))
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
