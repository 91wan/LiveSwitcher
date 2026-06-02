import XCTest
@testable import LiveSwitcher

final class RuntimeOwnershipTests: XCTestCase {
    func testRuntimeOwnershipDocumentExistsAndDeclaresAllDomains() throws {
        let document = try runtimeOwnershipDocument()

        [
            "Program queue",
            "Media playback",
            "BGM",
            "Audio routing",
            "Panic",
            "PPT mode",
            "Projection",
            "Automation notice",
            "Persistence"
        ].forEach { domain in
            XCTAssertTrue(document.contains("| \(domain) |"), "Missing ownership row for \(domain)")
        }
    }

    func testOnlyAudioIsDeclaredRuntimeAuthoritative() throws {
        let document = try runtimeOwnershipDocument()

        XCTAssertTrue(document.localizedStandardContains("Current authoritative runtime domain: Audio only"))
        XCTAssertTrue(document.localizedStandardContains("Program, Media, BGM, Panic, PPT, Projection, and Automation are mirror-only"))
        XCTAssertFalse(document.localizedStandardContains("Runtime authoritative: no"))
    }

    func testDocumentDoesNotClaimRuntimeAuthorityBeforeEffectsAreFullyWired() throws {
        let document = try runtimeOwnershipDocument()

        XCTAssertTrue(document.localizedStandardContains("A domain is not runtime-owned until its ports are wired and its legacy ViewModel mutation has been removed"))
        XCTAssertTrue(document.localizedStandardContains("Operator actions for mirror-only domains must not mutate real runtime domain state"))
        XCTAssertTrue(document.localizedStandardContains("No next domain may be migrated until the Audio ownership tests pass"))
        XCTAssertTrue(document.localizedStandardContains("production effective audio output remains runtime-owned"))
    }

    func testUnconnectedRuntimePortsAreDocumentedAsNotMigrated() throws {
        let document = try runtimeOwnershipDocument()

        [
            "`media` | not migrated",
            "`bgm` | not migrated",
            "`projection` | not migrated",
            "`ppt` | recording only",
            "`automation` | not migrated",
            "`automationNotice` | recording only",
            "`bgmTimer` | not migrated",
            "`support` | runtime storage, ViewModel ingress"
        ].forEach { expected in
            XCTAssertTrue(document.contains(expected), "Missing effect wiring status: \(expected)")
        }

        XCTAssertTrue(document.localizedStandardContains("Connected production ports: `audioRouting`, `imageAssets`, and `persistence`"))
        XCTAssertTrue(document.localizedStandardContains("ViewModel.recordSupportEvent"))
    }

    private func runtimeOwnershipDocument() throws -> String {
        let url = try repositoryRoot()
            .appendingPathComponent("docs/architecture/runtime-ownership.md")
        return try String(contentsOf: url, encoding: .utf8)
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
