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
            "Support",
            "Automation command execution",
            "Presentation query lifecycle",
            "Persistence"
        ].forEach { domain in
            XCTAssertTrue(document.contains("| \(domain) |"), "Missing ownership row for \(domain)")
        }
    }

    func testDocsStateAudioMediaBGMProjectionAndPPTAreAuthoritative() throws {
        let document = try runtimeOwnershipDocument()

        XCTAssertTrue(document.localizedStandardContains("Current authoritative runtime domains"))
        XCTAssertTrue(document.localizedStandardContains("Audio"))
        XCTAssertTrue(document.localizedStandardContains("Media playback"))
        XCTAssertTrue(document.localizedStandardContains("BGM playback and progress timer"))
        XCTAssertTrue(document.localizedStandardContains("Projection output"))
        XCTAssertTrue(document.localizedStandardContains("PPT EventTap lifecycle"))
        XCTAssertTrue(document.localizedStandardContains("Support event storage and ingress"))
        XCTAssertTrue(document.localizedStandardContains("Automation command execution"))
        XCTAssertTrue(document.localizedStandardContains("Presentation query lifecycle"))
        XCTAssertTrue(document.localizedStandardContains("| Media playback | Runtime owner |"))
        XCTAssertTrue(document.localizedStandardContains("| BGM | Runtime owner |"))
        XCTAssertTrue(document.localizedStandardContains("| Projection | Runtime owner |"))
        XCTAssertTrue(document.localizedStandardContains("| PPT mode | Runtime owner |"))
        XCTAssertTrue(document.localizedStandardContains("| Support | Runtime owner |"))
        XCTAssertTrue(document.localizedStandardContains("| Presentation query lifecycle | Runtime owner |"))
        XCTAssertFalse(document.localizedStandardContains("Runtime authoritative: no"))
    }

    func testDocsStatePPTLifecycleMigratedButKeyForwardingStaysViewModelOwned() throws {
        let document = try runtimeOwnershipDocument()

        XCTAssertTrue(document.localizedStandardContains("PPT key forwarding"))
        XCTAssertTrue(document.localizedStandardContains("WPS fallback branching"))
        XCTAssertTrue(document.localizedStandardContains("PPT EventTap lifecycle is runtime-owned"))
        XCTAssertTrue(document.localizedStandardContains("permission alert UI"))
        XCTAssertFalse(document.localizedStandardContains("| Projection | ViewModel owner |"))
    }

    func testDocumentDoesNotClaimRuntimeAuthorityBeforeEffectsAreFullyWired() throws {
        let document = try runtimeOwnershipDocument()
        let normalizedDocument = normalizedWhitespace(document)

        XCTAssertTrue(document.localizedStandardContains("A domain is not runtime-owned until its ports are wired and its legacy ViewModel mutation has been removed"))
        XCTAssertTrue(document.localizedStandardContains("Operator actions for mirror-only domains must not mutate real runtime domain state"))
        XCTAssertTrue(normalizedDocument.localizedStandardContains("No next domain may be migrated until the Audio, Media, BGM, Projection, PPT"))
        XCTAssertTrue(normalizedDocument.localizedStandardContains("projection start/stop output plus PPT EventTap lifecycle plus automation notice lifecycle"))
        XCTAssertTrue(document.localizedStandardContains("Audio routing context is stored inside `AudioRuntimeState`"))
        XCTAssertTrue(document.localizedStandardContains("`facadeAudioInputsChanged` updates audio routing context, not BGM/Panic mirror state"))
        XCTAssertTrue(document.localizedStandardContains("Effective audio output getters are pure Runtime state reads"))
        XCTAssertTrue(normalizedDocument.localizedStandardContains("Result-returning automation queries and key-forwarding migration remain blocked"))
        XCTAssertTrue(document.localizedStandardContains("Bridge modes are cumulative migration stages"))
        XCTAssertTrue(document.localizedStandardContains("`.bgmOwned` means Audio + Media + BGM, not Audio + BGM"))
        XCTAssertTrue(document.localizedStandardContains("means Audio + Media + BGM + Projection"))
        XCTAssertTrue(document.localizedStandardContains("`.pptOwned` means Audio + Media + BGM"))
        XCTAssertTrue(document.localizedStandardContains("`.automationNoticeOwned` means Audio +"))
        XCTAssertTrue(document.localizedStandardContains("`.supportOwned` means Audio +"))
    }

    func testUnconnectedRuntimePortsAreDocumentedAsNotMigrated() throws {
        let document = try runtimeOwnershipDocument()
        let normalizedDocument = normalizedWhitespace(document)

        [
            "`media` | wired",
            "`bgm` | wired",
            "`bgmTimer` | wired",
            "`projection` | wired",
            "`ppt` | wired",
            "`automationNotice` | wired",
            "`support` | wired",
            "`automation` | wired",
        ].forEach { expected in
            XCTAssertTrue(document.contains(expected), "Missing effect wiring status: \(expected)")
        }

        XCTAssertTrue(normalizedDocument.localizedStandardContains("Connected production ports: `media`, `bgm`,"))
        XCTAssertTrue(normalizedDocument.localizedStandardContains("`projection`, `ppt`, `automationNotice`, `support`, `automation`, `presentationQuery`,"))
        XCTAssertTrue(document.localizedStandardContains("ViewModel.recordSupportEvent"))
    }

    func testDocsStateFullRuntimeIsTestOnlyUntilFutureMigrations() throws {
        let document = try runtimeOwnershipDocument()
        let normalizedDocument = normalizedWhitespace(document)

        XCTAssertTrue(document.localizedStandardContains("`.fullRuntime` remains test-only"))
        XCTAssertTrue(normalizedDocument.localizedStandardContains("production current-program selection ownership is expressed by `.programSelectionOwned`"))
        XCTAssertTrue(normalizedDocument.localizedStandardContains("Program activation/switching side effects, broader automation query ownership, and key-forwarding Automation migration remain blocked"))
        XCTAssertTrue(document.localizedStandardContains("Support storage, production ingress, and facade projection use Runtime state"))
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

    func testDocsStateProjectionMigratedAndSupportIngressIsRuntimeOwned() throws {
        let document = try runtimeOwnershipDocument()
        let normalizedDocument = normalizedWhitespace(document)

        XCTAssertTrue(document.localizedStandardContains("Projection output is runtime-owned"))
        XCTAssertTrue(document.localizedStandardContains("Runtime owns projection start/stop decisions"))
        XCTAssertTrue(document.localizedStandardContains("The concrete output window"))
        XCTAssertTrue(document.localizedStandardContains("Projection start failure is distinct from display loss"))
        XCTAssertTrue(document.localizedStandardContains("`projectionStartFailed` records start failure semantics"))
        XCTAssertTrue(document.localizedStandardContains("`projectionExternalDisplayLost` is only for broadcasting loss"))
        XCTAssertTrue(document.localizedStandardContains("Raw output-window show/hide side effects are internal ProjectionPort"))
        XCTAssertTrue(document.localizedStandardContains("Support production ingress is runtime-owned"))
        XCTAssertTrue(normalizedDocument.localizedStandardContains("Result-returning automation queries and key-forwarding migration remain blocked"))
    }

    func testDocsStatePPTEventTapLifecycleMigratedButSupportGenerationRemainsViewModelOwned() throws {
        let document = try runtimeOwnershipDocument()

        XCTAssertTrue(document.localizedStandardContains("PPT EventTap lifecycle is runtime-owned"))
        XCTAssertTrue(document.localizedStandardContains("Runtime owns `state.ppt.isRequested`"))
        XCTAssertTrue(document.localizedStandardContains("`isPageInterceptEnabled` is a projection"))
        XCTAssertTrue(document.localizedStandardContains("PPT key forwarding"))
        XCTAssertTrue(document.localizedStandardContains("WPS fallback branching"))
        XCTAssertTrue(document.localizedStandardContains("PPT support event generation remain"))
        XCTAssertTrue(document.localizedStandardContains("must not write support storage directly"))
    }

    func testDocsStateBGMFadeOutUsesRuntimeLiveFadeDuration() throws {
        let document = try runtimeOwnershipDocument()
        let normalizedDocument = normalizedWhitespace(document)

        XCTAssertTrue(document.localizedStandardContains("Runtime owns BGM fade-in and fade-out behavior"))
        XCTAssertTrue(normalizedDocument.localizedStandardContains("Manual BGM stop uses `LiveRuntimeEnvironment.liveAudioFadeDuration`"))
        XCTAssertTrue(normalizedDocument.localizedStandardContains("BGM fallback cleanup does not require the current track to be nil"))
        XCTAssertTrue(document.localizedStandardContains("Runtime may keep a current BGM item selected while stopped"))
    }

    func testDocsStateAutomationNoticeMigratedAndCommandExecutionBoundaryIsNarrow() throws {
        let document = try runtimeOwnershipDocument()
        let normalizedDocument = normalizedWhitespace(document)

        XCTAssertTrue(document.localizedStandardContains("Automation notice lifecycle is runtime-owned"))
        XCTAssertTrue(document.localizedStandardContains("Runtime owns `state.automation.notice`"))
        XCTAssertTrue(document.localizedStandardContains("`state.automation.suppressionUntilByAction`"))
        XCTAssertTrue(document.localizedStandardContains("Production uses `AutomationNoticePort` effects"))
        XCTAssertTrue(document.localizedStandardContains("Automation notice expiry tasks are ID-bound"))
        XCTAssertTrue(normalizedDocument.localizedStandardContains("Showing a replacement notice, dismissing the current notice, manually expiring it, clearing Runtime notice state"))
        XCTAssertTrue(normalizedDocument.localizedStandardContains("stale expiry callbacks cannot clear a newer notice"))
        XCTAssertTrue(normalizedDocument.localizedStandardContains("`automationNoticeRequested` and `automationNoticeExpired` are internal lifecycle actions"))
        XCTAssertTrue(normalizedDocument.localizedStandardContains("`automationFailed` remains the meaningful system event"))
        XCTAssertTrue(document.localizedStandardContains("Automation command execution is runtime-owned only for fire-and-forget"))
        XCTAssertTrue(document.localizedStandardContains("ViewModel still owns AppleScript source construction"))
        XCTAssertTrue(document.localizedStandardContains("Keynote/WPS result-returning AppleScript queries"))
        XCTAssertTrue(document.localizedStandardContains("LiveRuntimeEffectExecutionContext"))
        XCTAssertTrue(document.localizedStandardContains("Future callback-capable Runtime ports must use"))
        XCTAssertTrue(document.localizedStandardContains("`PresentationQueryService` remains ViewModel-owned"))
        XCTAssertTrue(normalizedDocument.localizedStandardContains("Future callback-capable Runtime ports must use `LiveRuntimeEffectExecutionContext.dispatch`"))
        XCTAssertTrue(document.localizedStandardContains("WPS fallback branching"))
        XCTAssertTrue(normalizedDocument.localizedStandardContains("support event generation call sites, and telemetry remain ViewModel-owned"))
        XCTAssertTrue(normalizedDocument.localizedStandardContains("must not write Support storage in `.automationNoticeOwned`, `.supportOwned`, `.automationCommandOwned`, `.presentationQueryOwned`, `.programQueueOwned`, or `.programSelectionOwned`"))
    }

    func testDocsStateExtractedViewModelOwnedFacadesBeforeQueryMigration() throws {
        let document = try runtimeOwnershipDocument()
        let normalizedDocument = normalizedWhitespace(document)

        XCTAssertTrue(normalizedDocument.localizedStandardContains("Program queue storage/mutation is runtime-owned"))
        XCTAssertTrue(document.localizedStandardContains("`ViewModel+ProgramQueue.swift`"))
        XCTAssertTrue(document.localizedStandardContains("`ViewModel+PresentationAutomation.swift`"))
        XCTAssertTrue(document.localizedStandardContains("`ViewModel+AutomationFailure.swift`"))
        XCTAssertTrue(document.localizedStandardContains("`ViewModel+ProjectionOutput.swift`"))
        XCTAssertTrue(document.localizedStandardContains("`ViewModel+PPTEventTap.swift`"))
        XCTAssertTrue(document.localizedStandardContains("`ViewModel+SupportFacade.swift`"))
        XCTAssertTrue(normalizedDocument.localizedStandardContains("Presentation automation source construction"))
        XCTAssertTrue(normalizedDocument.localizedStandardContains("Automation failure support handling and the concrete automation notice facade"))
        XCTAssertTrue(normalizedDocument.localizedStandardContains("Projection output/window/support side effects live in `ViewModel+ProjectionOutput.swift`"))
        XCTAssertTrue(normalizedDocument.localizedStandardContains("PPT EventTap lifecycle, key forwarding, WPS key forwarding, and automation permission modal alerts live in `ViewModel+PPTEventTap.swift`"))
        XCTAssertTrue(normalizedDocument.localizedStandardContains("The thin Support ingress facade `recordSupportEvent(...)` lives in `ViewModel+SupportFacade.swift`"))
        XCTAssertTrue(normalizedDocument.localizedStandardContains("Broader result-returning automation queries remain blocked from this boundary"))
        XCTAssertTrue(normalizedDocument.localizedStandardContains("Projection/PPT/Support facade extraction tests"))
    }

    func testDocsStateProjectionPPTEncapsulationGatesBlockQueryMigration() throws {
        let document = try runtimeOwnershipDocument()
        let normalizedDocument = normalizedWhitespace(document)

        XCTAssertTrue(normalizedDocument.localizedStandardContains("Projection output controller storage, external-display availability mutation"))
        XCTAssertTrue(normalizedDocument.localizedStandardContains("PPT EventTap raw handles, pending PPT toggle source, WPS application monitoring"))
        XCTAssertTrue(normalizedDocument.localizedStandardContains("BGM transition generation, active BGM timer generation, and last audio-routing transition storage"))
        XCTAssertTrue(normalizedDocument.localizedStandardContains("encapsulated behind narrow ViewModel accessors"))
        XCTAssertTrue(normalizedDocument.localizedStandardContains("Result-returning query migration must also wait for the Projection/PPT encapsulation gates"))
    }

    func testDocsStateMediaAndAssetFacadesExtractedBeforeQueryMigration() throws {
        let document = try runtimeOwnershipDocument()
        let normalizedDocument = normalizedWhitespace(document)

        XCTAssertTrue(normalizedDocument.localizedStandardContains("Media playback callback setup, playback-ended handling, and the HTML presentation facade live in `ViewModel+MediaPlayback.swift`"))
        XCTAssertTrue(normalizedDocument.localizedStandardContains("wallpaper and corner-logo asset library facade lives in `ViewModel+Assets.swift`"))
        XCTAssertTrue(normalizedDocument.localizedStandardContains("must not own audio routing method bodies or concrete BGM player lifecycle method bodies, media callback/HTML presentation method bodies, or wallpaper/corner-logo library method bodies"))
        XCTAssertTrue(normalizedDocument.localizedStandardContains("media/assets extraction tests"))
    }

    func testDocsStateSupportIngressMigratedButGenerationStaysViewModelOwned() throws {
        let document = try runtimeOwnershipDocument()
        let normalizedDocument = normalizedWhitespace(document)

        XCTAssertTrue(document.localizedStandardContains("Support storage and production ingress are runtime-owned"))
        XCTAssertTrue(document.localizedStandardContains("Production uses `.programSelectionOwned` and wires"))
        XCTAssertTrue(document.localizedStandardContains("`ViewModel+SupportFacade.swift` owns `recordSupportEvent(...)`"))
        XCTAssertTrue(normalizedDocument.localizedStandardContains("dispatch `.supportEventRecorded`"))
        XCTAssertTrue(document.localizedStandardContains("sync `supportEvents` from Runtime"))
        XCTAssertTrue(normalizedDocument.localizedStandardContains("returns the exact accepted event stored in `state.support.events`"))
        XCTAssertTrue(normalizedDocument.localizedStandardContains("emits `.recordSupportEvent` only for that accepted event"))
        XCTAssertTrue(normalizedDocument.localizedStandardContains("`.supportEventRecorded` is support ingress, not operator intent"))
        XCTAssertTrue(normalizedDocument.localizedStandardContains("suppressed from the operator-facing Runtime action log"))
        XCTAssertTrue(normalizedDocument.localizedStandardContains("must not append support events directly, perform local redaction/coalescing/trimming"))
        XCTAssertTrue(normalizedDocument.localizedStandardContains("Support event generation call sites and telemetry remain ViewModel-owned"))
    }

    private func runtimeOwnershipDocument() throws -> String {
        let url = try repositoryRoot()
            .appendingPathComponent("docs/architecture/runtime-ownership.md")
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func normalizedWhitespace(_ text: String) -> String {
        text.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
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
