import XCTest
@testable import LiveSwitcher

final class ModeToggleLayoutTests: XCTestCase {
    func testLiveModesUseEqualWidthHorizontalCardsAndSpeakerBindingSideEffect() throws {
        let source = try sourceText("Views/LiveModeView.swift")

        XCTAssertTrue(source.contains("ModeToggleCard("))
        XCTAssertTrue(source.contains(".frame(maxWidth: .infinity)"))
        XCTAssertFalse(source.contains("modeToggleRow("))
        XCTAssertFalse(source.contains("isOn: $viewModel.isSpeakerMode"))
        XCTAssertTrue(source.contains("speakerModeBinding"))
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
