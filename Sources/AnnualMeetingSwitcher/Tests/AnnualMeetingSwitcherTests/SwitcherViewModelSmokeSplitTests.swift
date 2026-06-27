import XCTest

final class SwitcherViewModelSmokeSplitTests: XCTestCase {
    func testSwitcherViewModelSmokeFilesStayFocusedAndOffComplexityAllowlist() throws {
        let expectedFiles = [
            "SwitcherViewModelSmokeTestSupport.swift",
            "SwitcherViewModelBGMSmokeTests.swift",
            "SwitcherViewModelMediaSmokeTests.swift",
            "SwitcherViewModelOverlaySmokeTests.swift",
            "SwitcherViewModelProjectionSmokeTests.swift",
            "SwitcherViewModelPersistenceSmokeTests.swift",
            "SwitcherViewModelSupportSmokeTests.swift",
            "SwitcherViewModelPanicSmokeTests.swift",
            "SwitcherViewModelProgramControlSmokeTests.swift",
            "SwitcherViewModelProgramIndexSmokeTests.swift",
            "SwitcherViewModelProgramQueueSmokeTests.swift",
            "SwitcherViewModelDeckSmokeTests.swift",
            "SwitcherViewModelPlaybackEndedSmokeTests.swift"
        ]

        for relativePath in expectedFiles {
            XCTAssertTrue(try testFileExists(relativePath), "\(relativePath) should exist after the split.")
            let lineCount = try testText(relativePath).split(separator: "\n", omittingEmptySubsequences: false).count
            if relativePath == "SwitcherViewModelSmokeTestSupport.swift" {
                XCTAssertLessThan(lineCount, 250, "\(relativePath) should stay below the support budget.")
            } else {
                XCTAssertLessThan(lineCount, 500, "\(relativePath) should stay below the per-test-file budget.")
            }
        }

        let legacyFile = try testRoot().appendingPathComponent("SwitcherViewModelSmokeTests.swift")
        if FileManager.default.fileExists(atPath: legacyFile.path) {
            let lineCount = try String(contentsOf: legacyFile, encoding: .utf8)
                .split(separator: "\n", omittingEmptySubsequences: false)
                .count
            XCTAssertLessThan(lineCount, 250, "SwitcherViewModelSmokeTests.swift should be deleted or reduced to a shell.")
        }

        let allowlist = try String(
            contentsOf: repositoryRoot(filePath: #filePath).appendingPathComponent("docs/architecture/complexity-allowlist.tsv"),
            encoding: .utf8
        )
        XCTAssertFalse(allowlist.contains("Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/SwitcherViewModelSmokeTests.swift"))
    }

    private func testText(_ relativePath: String) throws -> String {
        try String(contentsOf: try testRoot().appendingPathComponent(relativePath), encoding: .utf8)
    }

    private func testFileExists(_ relativePath: String) throws -> Bool {
        FileManager.default.fileExists(atPath: try testRoot().appendingPathComponent(relativePath).path)
    }

    private func testRoot() throws -> URL {
        var directory = URL(fileURLWithPath: #filePath)
        while directory.pathComponents.count > 1 {
            directory.deleteLastPathComponent()
            let marker = directory.appendingPathComponent("TestSourceTextSupport.swift")
            if FileManager.default.fileExists(atPath: marker.path) {
                return directory
            }
        }
        throw XCTSkip("Could not locate AnnualMeetingSwitcher test root from test source path.")
    }
}
