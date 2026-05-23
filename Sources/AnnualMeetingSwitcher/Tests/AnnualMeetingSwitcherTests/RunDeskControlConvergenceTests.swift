import XCTest
@testable import LiveSwitcher

final class RunDeskControlConvergenceTests: XCTestCase {
    func testProgramMonitorUtilitiesAreVisibleWithoutDisclosure() throws {
        let source = try sourceText("Views/ProgramMonitorView.swift")

        XCTAssertFalse(source.contains("DisclosureGroup"))
        XCTAssertFalse(source.contains("utilitiesDisclosure"))
        XCTAssertTrue(source.contains("monitorUtilitiesStack"))
        XCTAssertTrue(source.contains("transitionControlCard"))
        XCTAssertTrue(source.contains("wallpaperTrayCard"))
    }

    func testLiveOpsMergesModesIntoAudioCard() throws {
        let source = try sourceText("Views/LiveOpsPanel.swift")

        XCTAssertFalse(source.contains("modesCard"))
        XCTAssertFalse(source.contains("opsCard(title: \"Modes\""))
        XCTAssertTrue(source.contains("audioModesRow"))
        XCTAssertTrue(source.contains("modeToggleRow("))
    }

    func testLeftPanelUsesVisibleAddSourceGridAndNonFocusableRefresh() throws {
        let source = try sourceText("Views/LeftPanel.swift")

        XCTAssertFalse(source.contains("Menu {"))
        XCTAssertEqual(source.components(separatedBy: "addSourceButton(title:").count - 1, 4)
        XCTAssertTrue(source.contains(".focusable(false)"))
    }

    func testAutoNextIdleStateIsNeutralAndActiveStateWarns() {
        let idle = AutoNextVideoControlModel.make(isEnabled: false, hasCurrentProgram: false)
        let armedWithoutProgram = AutoNextVideoControlModel.make(isEnabled: true, hasCurrentProgram: false)
        let active = AutoNextVideoControlModel.make(isEnabled: true, hasCurrentProgram: true)

        XCTAssertEqual(idle.statusKind, .idle)
        XCTAssertEqual(idle.systemImage, "play.rectangle.on.rectangle")
        XCTAssertEqual(armedWithoutProgram.statusKind, .idle)
        XCTAssertEqual(active.statusKind, .warn)
        XCTAssertEqual(active.systemImage, "exclamationmark.triangle.fill")
    }

    func testBGMIdleStatusDoesNotLookLikeASelectableBadge() {
        let track = BGMItem(title: "Opening", url: URL(fileURLWithPath: "/tmp/opening.mp3"), category: .warmUp)
        let state = BGMControlsState.make(items: [track], currentItem: nil)

        XCTAssertEqual(state.displayStatusText, "IDLE")
        XCTAssertEqual(state.displayStatusKind, .idle)
    }

    func testDirectorRailsUseNarrowerRunDeskWidth() {
        XCTAssertEqual(StudioTheme.directorRailWidth, 320)
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
