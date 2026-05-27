import XCTest

final class ObservableMigrationRFCTests: XCTestCase {
    func testRFCRecordsPreMigrationObservationBaseline() throws {
        let rfc = try observableMigrationRFC(root: repositoryRoot())

        XCTAssertTrue(rfc.contains("52 `@Published`"))
        XCTAssertTrue(rfc.contains("25 direct `SwitcherViewModel` observation declarations"))
        XCTAssertTrue(rfc.contains("7 preview or sample `.environmentObject(SwitcherViewModel())` injections"))
    }

    func testRFCDefinesTheRequiredSwiftUIProfilerScenarios() throws {
        let rfc = try observableMigrationRFC(root: repositoryRoot())

        XCTAssertTrue(rfc.contains("Instruments"))
        XCTAssertTrue(rfc.contains("SwiftUI Profiler"))
        XCTAssertTrue(rfc.contains("Drag Master fader for 1 second"))
        XCTAssertTrue(rfc.contains("Switch current program item"))
        XCTAssertTrue(rfc.contains("BGM playback for 10 seconds"))
        XCTAssertTrue(rfc.contains("Countdown reaches 0"))
    }

    func testRFCKeepsPhaseOneSeparateFromTheMigrationPR() throws {
        let rfc = try observableMigrationRFC(root: repositoryRoot())

        XCTAssertTrue(rfc.contains("Phase 1"))
        XCTAssertTrue(rfc.contains("does not migrate `SwitcherViewModel`"))
        XCTAssertTrue(rfc.contains("Phase 2"))
        XCTAssertTrue(rfc.contains("separate PR"))
        XCTAssertTrue(rfc.contains("@Observable final class SwitcherViewModel"))
    }

    func testRFCListsCandidateStoresThatShouldStopObservingTheWholeViewModel() throws {
        let rfc = try observableMigrationRFC(root: repositoryRoot())

        XCTAssertTrue(rfc.contains("Program runtime state"))
        XCTAssertTrue(rfc.contains("Audio runtime state"))
        XCTAssertTrue(rfc.contains("BGM library/playback state"))
        XCTAssertTrue(rfc.contains("Overlay live state"))
        XCTAssertTrue(rfc.contains("Preflight/support state"))
        XCTAssertTrue(rfc.contains("Wallpaper and corner-logo asset state"))
    }

    private func observableMigrationRFC(root: URL) throws -> String {
        let url = root.appendingPathComponent("docs/rfc/observable-migration.md")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), "Missing docs/rfc/observable-migration.md")
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func repositoryRoot() throws -> URL {
        var directory = URL(fileURLWithPath: #filePath)
        while directory.pathComponents.count > 1 {
            directory.deleteLastPathComponent()
            let marker = directory.appendingPathComponent("script/check_release_hygiene.sh")
            let sources = directory.appendingPathComponent("Sources/AnnualMeetingSwitcher")
            if FileManager.default.fileExists(atPath: marker.path),
               FileManager.default.fileExists(atPath: sources.path) {
                return directory
            }
        }
        throw XCTSkip("Could not locate LiveSwitcher repository root.")
    }
}
