import XCTest
@testable import LiveSwitcher

final class PPTModeCommandTests: XCTestCase {
    func testPPTModeToggleModelFlipsTheCurrentState() {
        XCTAssertTrue(PPTModeToggleModel.nextState(isEnabled: false))
        XCTAssertFalse(PPTModeToggleModel.nextState(isEnabled: true))
    }

    func testAppCommandUsesViewModelToggleHelper() throws {
        let app = try sourceText("App.swift")

        XCTAssertTrue(app.contains("viewModel.togglePPTMode(source: .command)"))
        XCTAssertFalse(app.contains("viewModel.isPageInterceptEnabled.toggle()"))
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
