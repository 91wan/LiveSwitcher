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

    func testMixedOwnershipDomainsAreMarkedBridgeInProgress() throws {
        let document = try runtimeOwnershipDocument()

        [
            "Media playback",
            "Audio routing",
            "Panic",
            "Automation notice",
            "Persistence"
        ].forEach { domain in
            XCTAssertTrue(
                document.contains("| \(domain) |") && document.contains("bridge in progress"),
                "\(domain) must be explicitly marked bridge in progress."
            )
        }
    }

    func testDocumentDoesNotClaimRuntimeAuthorityBeforeEffectsAreFullyWired() throws {
        let document = try runtimeOwnershipDocument()

        XCTAssertFalse(document.localizedStandardContains("Runtime authoritative: yes"))
        XCTAssertTrue(document.localizedStandardContains("Runtime authoritative: no"))
        XCTAssertTrue(document.localizedStandardContains("Runtime action log only"))
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
            "`support` | not migrated"
        ].forEach { expected in
            XCTAssertTrue(document.contains(expected), "Missing effect wiring status: \(expected)")
        }

        XCTAssertTrue(document.localizedStandardContains("media restart effect is not executed by runtime yet"))
        XCTAssertTrue(document.localizedStandardContains("ViewModel still executes media restart"))
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
