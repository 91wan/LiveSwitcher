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

    func testDocsStateAudioAndMediaAreAuthoritative() throws {
        let document = try runtimeOwnershipDocument()

        XCTAssertTrue(document.localizedStandardContains("Current authoritative runtime domains"))
        XCTAssertTrue(document.localizedStandardContains("Audio"))
        XCTAssertTrue(document.localizedStandardContains("Media playback"))
        XCTAssertTrue(document.localizedStandardContains("| Media playback | Runtime owner |"))
        XCTAssertFalse(document.localizedStandardContains("Runtime authoritative: no"))
    }

    func testDocsStateBGMProjectionPPTRemainMirrorOnly() throws {
        let document = try runtimeOwnershipDocument()

        XCTAssertTrue(document.localizedStandardContains("Program queue, BGM, Panic, PPT, Projection, and Automation are not runtime-owned"))
        XCTAssertTrue(document.localizedStandardContains("| BGM | ViewModel owner |"))
        XCTAssertTrue(document.localizedStandardContains("| PPT mode | ViewModel owner |"))
        XCTAssertTrue(document.localizedStandardContains("| Projection | ViewModel owner |"))
    }

    func testDocumentDoesNotClaimRuntimeAuthorityBeforeEffectsAreFullyWired() throws {
        let document = try runtimeOwnershipDocument()

        XCTAssertTrue(document.localizedStandardContains("A domain is not runtime-owned until its ports are wired and its legacy ViewModel mutation has been removed"))
        XCTAssertTrue(document.localizedStandardContains("Operator actions for mirror-only domains must not mutate real runtime domain state"))
        XCTAssertTrue(document.localizedStandardContains("No next domain may be migrated until the Audio and Media ownership tests pass"))
        XCTAssertTrue(document.localizedStandardContains("production effective audio output and media playback output remain runtime-owned"))
        XCTAssertTrue(document.localizedStandardContains("Audio routing context is stored inside `AudioRuntimeState`"))
        XCTAssertTrue(document.localizedStandardContains("`facadeAudioInputsChanged` updates audio routing context, not BGM/Panic mirror state"))
        XCTAssertTrue(document.localizedStandardContains("Effective audio output getters are pure Runtime state reads"))
        XCTAssertTrue(document.localizedStandardContains("BGM/Projection/PPT migration is blocked until its ports are wired and an ownership PR is approved"))
    }

    func testUnconnectedRuntimePortsAreDocumentedAsNotMigrated() throws {
        let document = try runtimeOwnershipDocument()

        [
            "`media` | wired",
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

        XCTAssertTrue(document.localizedStandardContains("Connected production ports: `media`, `audioRouting`, `imageAssets`, and `persistence`"))
        XCTAssertTrue(document.localizedStandardContains("ViewModel.recordSupportEvent"))
    }

    func testDocsStateFullRuntimeIsTestOnlyUntilMigration() throws {
        let document = try runtimeOwnershipDocument()

        XCTAssertTrue(document.localizedStandardContains("`.fullRuntime` remains test-only"))
        XCTAssertTrue(document.localizedStandardContains("production media ownership is expressed by `.mediaOwned`"))
        XCTAssertTrue(document.localizedStandardContains("BGM/Projection/PPT migration is blocked until its ports are wired and an ownership PR is approved"))
    }

    func testDocsRequireExplicitBridgeModeInTests() throws {
        let document = try runtimeOwnershipDocument()
        let environmentDefaultText = "`LiveRuntime" + "Environment()` must not imply production-unsafe full runtime"

        XCTAssertTrue(document.localizedStandardContains("Tests must use explicit bridge mode"))
        XCTAssertTrue(document.localizedStandardContains(environmentDefaultText))
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
