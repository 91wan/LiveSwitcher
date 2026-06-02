import XCTest
@testable import LiveSwitcher

final class LiveModeSimplicityTests: XCTestCase {
    func testLiveModeSimplicityRulesDocumentDefinesAllowedForbiddenAndReviewChecklist() throws {
        let document = try repositoryText("docs/architecture/live-mode-simplicity-rules.md")

        XCTAssertTrue(document.contains("Allowed live actions"))
        XCTAssertTrue(document.contains("Forbidden configuration surfaces"))
        XCTAssertTrue(document.contains("Review checklist"))
        XCTAssertTrue(document.contains("Switch source"))
        XCTAssertTrue(document.contains("Toggle main media playback"))
        XCTAssertTrue(document.contains("Toggle projection"))
        XCTAssertTrue(document.contains("Restart current media"))
        XCTAssertTrue(document.contains("Current authoritative runtime domain: Audio only"))
        XCTAssertTrue(document.contains("Mirror-only live domains"))
    }

    func testLiveModeViewDoesNotExposeForbiddenConfigurationSurfaces() throws {
        let source = try sourceText("Views/LiveModeView.swift")

        XCTAssertFalse(source.contains("fileImporter("))
        XCTAssertFalse(source.contains("addProgramItem("))
        XCTAssertFalse(source.contains("addBGM"))
        XCTAssertFalse(source.contains("autoPlayNextVideoOnEnd"))
        XCTAssertFalse(source.contains("autoAdvanceAtScheduledTime"))
    }

    func testLiveModeKeepsCoreOperatorActionsVisible() throws {
        let liveMode = try sourceText("Views/LiveModeView.swift")
        let toolbar = try sourceText("Views/MainToolbar.swift")
        let content = try sourceText("ContentView.swift")

        XCTAssertTrue(liveMode.contains("viewModel.switchToProgramAfterReadinessConfirmation(item)"))
        XCTAssertTrue(liveMode.contains("viewModel.switchToProgram(at: index)"))
        XCTAssertTrue(liveMode.contains("viewModel.restartCurrentMediaFromBeginning()"))
        XCTAssertTrue(liveMode.contains("viewModel.handleSafeBroadcastToggle()"))
        XCTAssertTrue(liveMode.contains("viewModel.toggleBGM(row.item)"))
        XCTAssertTrue(toolbar.contains("viewModel.toggleSpeakerMode()"))
        XCTAssertTrue(toolbar.contains("viewModel.togglePPTMode(source: pptModeToggleSource)"))
        XCTAssertTrue(content.contains("viewModel.togglePanicMode()"))
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

    private func repositoryText(_ relativePath: String) throws -> String {
        try String(contentsOf: repositoryRoot().appendingPathComponent(relativePath), encoding: .utf8)
    }

    private func repositoryRoot() throws -> URL {
        var directory = URL(fileURLWithPath: #filePath)
        while directory.pathComponents.count > 1 {
            directory.deleteLastPathComponent()
            let candidate = directory.appendingPathComponent("docs")
            if FileManager.default.fileExists(atPath: candidate.path) {
                return directory
            }
        }
        throw XCTSkip("Could not locate repository root from test source path.")
    }
}
