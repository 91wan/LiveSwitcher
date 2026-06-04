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

    func testDocsStateAudioMediaBGMAndProjectionAreAuthoritative() throws {
        let document = try runtimeOwnershipDocument()

        XCTAssertTrue(document.localizedStandardContains("Current authoritative runtime domains"))
        XCTAssertTrue(document.localizedStandardContains("Audio"))
        XCTAssertTrue(document.localizedStandardContains("Media playback"))
        XCTAssertTrue(document.localizedStandardContains("BGM playback and progress timer"))
        XCTAssertTrue(document.localizedStandardContains("Projection output"))
        XCTAssertTrue(document.localizedStandardContains("| Media playback | Runtime owner |"))
        XCTAssertTrue(document.localizedStandardContains("| BGM | Runtime owner |"))
        XCTAssertTrue(document.localizedStandardContains("| Projection | Runtime owner |"))
        XCTAssertFalse(document.localizedStandardContains("Runtime authoritative: no"))
    }

    func testDocsStatePPTAndOtherUnmigratedDomainsRemainMirrorOnly() throws {
        let document = try runtimeOwnershipDocument()

        XCTAssertTrue(document.localizedStandardContains("Program queue, Panic, PPT, and Automation are not runtime-owned"))
        XCTAssertTrue(document.localizedStandardContains("| PPT mode | ViewModel owner |"))
        XCTAssertFalse(document.localizedStandardContains("| Projection | ViewModel owner |"))
    }

    func testDocumentDoesNotClaimRuntimeAuthorityBeforeEffectsAreFullyWired() throws {
        let document = try runtimeOwnershipDocument()

        XCTAssertTrue(document.localizedStandardContains("A domain is not runtime-owned until its ports are wired and its legacy ViewModel mutation has been removed"))
        XCTAssertTrue(document.localizedStandardContains("Operator actions for mirror-only domains must not mutate real runtime domain state"))
        XCTAssertTrue(document.localizedStandardContains("No next domain may be migrated until the Audio, Media, BGM, and Projection"))
        XCTAssertTrue(document.localizedStandardContains("playback output plus projection start/stop output remain runtime-owned"))
        XCTAssertTrue(document.localizedStandardContains("Audio routing context is stored inside `AudioRuntimeState`"))
        XCTAssertTrue(document.localizedStandardContains("`facadeAudioInputsChanged` updates audio routing context, not BGM/Panic mirror state"))
        XCTAssertTrue(document.localizedStandardContains("Effective audio output getters are pure Runtime state reads"))
        XCTAssertTrue(document.localizedStandardContains("Automation, and Support production ingress migration remain blocked"))
        XCTAssertTrue(document.localizedStandardContains("Bridge modes are cumulative migration stages"))
        XCTAssertTrue(document.localizedStandardContains("`.bgmOwned` means Audio + Media + BGM, not Audio + BGM"))
        XCTAssertTrue(document.localizedStandardContains("means Audio + Media + BGM + Projection"))
    }

    func testUnconnectedRuntimePortsAreDocumentedAsNotMigrated() throws {
        let document = try runtimeOwnershipDocument()

        [
            "`media` | wired",
            "`bgm` | wired",
            "`bgmTimer` | wired",
            "`projection` | wired",
            "`ppt` | recording only",
            "`automation` | not migrated",
            "`automationNotice` | recording only",
            "`support` | runtime storage, ViewModel ingress"
        ].forEach { expected in
            XCTAssertTrue(document.contains(expected), "Missing effect wiring status: \(expected)")
        }

        XCTAssertTrue(document.localizedStandardContains("Connected production ports: `media`, `bgm`,"))
        XCTAssertTrue(document.localizedStandardContains("`projection`, `audioRouting`, `imageAssets`, and `persistence`"))
        XCTAssertTrue(document.localizedStandardContains("ViewModel.recordSupportEvent"))
    }

    func testDocsStateFullRuntimeIsTestOnlyUntilFutureMigrations() throws {
        let document = try runtimeOwnershipDocument()

        XCTAssertTrue(document.localizedStandardContains("`.fullRuntime` remains test-only"))
        XCTAssertTrue(document.localizedStandardContains("production Projection ownership is expressed by `.projectionOwned`"))
        XCTAssertTrue(document.localizedStandardContains("PPT, Program queue, Automation, and Support ingress migration remain"))
        XCTAssertTrue(document.localizedStandardContains("Support storage uses runtime state, but production ingress remains"))
        XCTAssertTrue(document.localizedStandardContains("until a dedicated Support migration PR"))
    }

    func testDocsRequireExplicitBridgeModeInTests() throws {
        let document = try runtimeOwnershipDocument()
        let environmentDefaultText = "`LiveRuntime" + "Environment()` must not imply production-unsafe full runtime"

        XCTAssertTrue(document.localizedStandardContains("Tests must use explicit bridge mode"))
        XCTAssertTrue(document.localizedStandardContains(environmentDefaultText))
    }

    func testDocsStateBridgeModeIsNeverInferredFromPorts() throws {
        let document = try runtimeOwnershipDocument()

        XCTAssertTrue(document.localizedStandardContains("Bridge mode is explicit and never inferred from ports"))
        XCTAssertTrue(document.localizedStandardContains("A custom `LiveRuntimeEffectRunner` must always be paired with an explicit `LiveRuntimeEnvironment`"))
    }

    func testDocsStatePortsDoNotImplyOwnership() throws {
        let document = try runtimeOwnershipDocument()

        XCTAssertTrue(document.localizedStandardContains("Ports describe executable capabilities"))
        XCTAssertTrue(document.localizedStandardContains("Bridge mode describes domain ownership"))
    }

    func testDocsStateProjectionMigratedButSupportIngressRemainsViewModelOwned() throws {
        let document = try runtimeOwnershipDocument()

        XCTAssertTrue(document.localizedStandardContains("Projection output is runtime-owned"))
        XCTAssertTrue(document.localizedStandardContains("Runtime owns projection start/stop decisions"))
        XCTAssertTrue(document.localizedStandardContains("The concrete output window"))
        XCTAssertTrue(document.localizedStandardContains("Projection start failure is distinct from display loss"))
        XCTAssertTrue(document.localizedStandardContains("`projectionStartFailed` records start failure semantics"))
        XCTAssertTrue(document.localizedStandardContains("`projectionExternalDisplayLost` is only for broadcasting loss"))
        XCTAssertTrue(document.localizedStandardContains("Raw output-window show/hide side effects are internal ProjectionPort"))
        XCTAssertTrue(document.localizedStandardContains("Support production ingress remains ViewModel-owned"))
        XCTAssertTrue(document.localizedStandardContains("PPT migration remains blocked until Projection hardening tests pass"))
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
