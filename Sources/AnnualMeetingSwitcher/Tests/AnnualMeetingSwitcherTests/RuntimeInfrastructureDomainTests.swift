import XCTest
@testable import LiveSwitcher

final class RuntimeInfrastructureDomainTests: XCTestCase {
    func testLiveRuntimeDomainIncludesImageAssets() {
        XCTAssertTrue(LiveRuntimeDomain.allCases.contains(.imageAssets))
    }

    func testLiveRuntimeDomainIncludesPersistence() {
        XCTAssertTrue(LiveRuntimeDomain.allCases.contains(.persistence))
    }

    func testRecordingOnlyDoesNotOwnInfrastructureDomains() {
        XCTAssertFalse(LiveRuntimeBridgeMode.recordingOnly.owns(.imageAssets))
        XCTAssertFalse(LiveRuntimeBridgeMode.recordingOnly.owns(.persistence))
    }

    func testAudioOwnedOwnsInfrastructureDomains() {
        XCTAssertTrue(LiveRuntimeBridgeMode.audioOwned.owns(.imageAssets))
        XCTAssertTrue(LiveRuntimeBridgeMode.audioOwned.owns(.persistence))
    }

    func testAutomationCommandOwnedOwnsInfrastructureDomains() {
        XCTAssertTrue(LiveRuntimeBridgeMode.automationCommandOwned.owns(.imageAssets))
        XCTAssertTrue(LiveRuntimeBridgeMode.automationCommandOwned.owns(.persistence))
    }

    func testFullRuntimeOwnsInfrastructureDomains() {
        XCTAssertTrue(LiveRuntimeBridgeMode.fullRuntime.owns(.imageAssets))
        XCTAssertTrue(LiveRuntimeBridgeMode.fullRuntime.owns(.persistence))
    }

    func testInfrastructureDomainsDoNotReplaceAutomationQueryDomain() {
        XCTAssertFalse(LiveRuntimeDomain.allCases.contains { $0.rawValue == "automationQuery" })
    }

    func testLoadBackgroundImageRequiresImageAssetsDomain() {
        XCTAssertEqual(
            LiveRuntimeEffect.loadBackgroundImage(URL(fileURLWithPath: "/tmp/background.png")).requiredBridgeDomain,
            .imageAssets
        )
    }

    func testLoadCornerLogoImageRequiresImageAssetsDomain() {
        XCTAssertEqual(
            LiveRuntimeEffect.loadCornerLogoImage(URL(fileURLWithPath: "/tmp/logo.png")).requiredBridgeDomain,
            .imageAssets
        )
    }

    func testSavePersistentStateRequiresPersistenceDomain() {
        XCTAssertEqual(LiveRuntimeEffect.savePersistentState.requiredBridgeDomain, .persistence)
    }

    func testSaveConsoleModeRequiresPersistenceDomain() {
        XCTAssertEqual(LiveRuntimeEffect.saveConsoleMode(.live).requiredBridgeDomain, .persistence)
    }

    func testSaveThemeOverrideRequiresPersistenceDomain() {
        XCTAssertEqual(LiveRuntimeEffect.saveThemeOverride(.dark).requiredBridgeDomain, .persistence)
    }

    func testSaveAudioStrategyRequiresPersistenceDomain() {
        XCTAssertEqual(LiveRuntimeEffect.saveAudioStrategy(.mixed).requiredBridgeDomain, .persistence)
    }

    func testSaveSpeakerModeRequiresPersistenceDomain() {
        XCTAssertEqual(LiveRuntimeEffect.saveSpeakerMode(true).requiredBridgeDomain, .persistence)
    }

    func testSaveBGMPlayModeRequiresPersistenceDomain() {
        XCTAssertEqual(LiveRuntimeEffect.saveBGMPlayMode(.loopOne).requiredBridgeDomain, .persistence)
    }

    func testSaveAutoPlayNextVideoOnEndRequiresPersistenceDomain() {
        XCTAssertEqual(LiveRuntimeEffect.saveAutoPlayNextVideoOnEnd(true).requiredBridgeDomain, .persistence)
    }

    func testSaveAutoAdvanceAtScheduledTimeRequiresPersistenceDomain() {
        XCTAssertEqual(LiveRuntimeEffect.saveAutoAdvanceAtScheduledTime(true).requiredBridgeDomain, .persistence)
    }

    func testSaveShowAgendaTimelineRequiresPersistenceDomain() {
        XCTAssertEqual(LiveRuntimeEffect.saveShowAgendaTimeline(true).requiredBridgeDomain, .persistence)
    }

    func testSaveCornerLogoPositionRequiresPersistenceDomain() {
        XCTAssertEqual(LiveRuntimeEffect.saveCornerLogoPosition(.bottomLeft).requiredBridgeDomain, .persistence)
    }

    func testApplyAudioRoutingStillRequiresAudioDomain() {
        XCTAssertEqual(LiveRuntimeEffect.applyAudioRouting(reason: .speakerChanged).requiredBridgeDomain, .audio)
    }

    func testBGMPlaybackEffectsStillRequireBGMDomain() {
        let item = BGMItem(title: "BGM", url: URL(fileURLWithPath: "/tmp/bgm.mp3"))

        XCTAssertEqual(LiveRuntimeEffect.prepareBGM(item, generation: 1).requiredBridgeDomain, .bgm)
        XCTAssertEqual(LiveRuntimeEffect.setBGMPlayMode(.loopOne, generation: 1).requiredBridgeDomain, .bgm)
    }

    func testRunAppleScriptStillRequiresAutomationCommandDomain() {
        XCTAssertEqual(
            LiveRuntimeEffect.runAppleScript(script: "tell app", action: "keynote.next-slide").requiredBridgeDomain,
            .automationCommand
        )
    }
}
