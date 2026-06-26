import XCTest
@testable import LiveSwitcher

final class RuntimeEffectDomainPolicyTests: XCTestCase {
    func testApplyAudioRoutingRequiresAudioDomain() {
        XCTAssertEqual(LiveRuntimeEffect.applyAudioRouting(reason: .strategyChanged).requiredBridgeDomain, .audio)
    }

    func testImageAssetEffectsRequireImageAssetsDomain() {
        let url = URL(fileURLWithPath: "/tmp/runtime-background.png")

        XCTAssertEqual(LiveRuntimeEffect.loadBackgroundImage(url).requiredBridgeDomain, .imageAssets)
        XCTAssertEqual(LiveRuntimeEffect.loadCornerLogoImage(url).requiredBridgeDomain, .imageAssets)
    }

    func testPersistenceEffectsRequirePersistenceDomain() {
        [
            LiveRuntimeEffect.saveConsoleMode(.live),
            .saveThemeOverride(.dark),
            .saveCompanyDisplayName("示例科技"),
            .saveAudioStrategy(.followSource),
            .saveSpeakerMode(true),
            .saveAutoPlayNextVideoOnEnd(true),
            .saveAgendaTimeReminderEnabled(true),
            .saveShowAgendaTimeline(true),
            .saveCornerLogoVisible(true),
            .saveCornerLogoPosition(.bottomLeft),
            .savePersistentState
        ].forEach { effect in
            XCTAssertEqual(effect.requiredBridgeDomain, .persistence, "\(effect)")
        }
    }

    func testSaveBGMPlayModeRequiresPersistenceDomain() {
        XCTAssertEqual(LiveRuntimeEffect.saveBGMPlayMode(.sequential).requiredBridgeDomain, .persistence)
    }

    func testMediaEffectsRequireMediaDomain() {
        let url = URL(fileURLWithPath: "/tmp/runtime-media.mp4")

        [
            LiveRuntimeEffect.loadMedia(url, generation: 1),
            .playMedia(generation: 1),
            .pauseMedia(generation: 1),
            .restartMedia(generation: 1),
            .seekMediaToStart(generation: 1),
            .seekMediaToEnd(generation: 1),
            .stopMedia(generation: 1),
            .setMediaVolume(0.5, fade: 0.1, generation: 1)
        ].forEach { effect in
            XCTAssertEqual(effect.requiredBridgeDomain, .media, "\(effect)")
        }
    }

    func testBGMPlaybackEffectsRequireBGMDomain() {
        let item = BGMItem(title: "Walk In", url: URL(fileURLWithPath: "/tmp/walk-in.mp3"))

        [
            LiveRuntimeEffect.prepareBGM(item, generation: 2),
            .playBGM(generation: 2),
            .pauseBGM(generation: 2),
            .stopBGM(fade: 0.5, generation: 2),
            .setBGMVolume(0.6, fade: 0.1, generation: 2),
            .seekBGMToBeginning(generation: 2),
            .seekBGMToProgress(0.4, generation: 2),
            .setBGMPlayMode(.loopOne, generation: 2),
            .startBGMTimer(generation: 2),
            .stopBGMTimer(generation: 2)
        ].forEach { effect in
            XCTAssertEqual(effect.requiredBridgeDomain, .bgm, "\(effect)")
        }
    }

    func testProjectionEffectsRequireProjectionDomain() {
        [
            LiveRuntimeEffect.startProjection,
            .stopProjection,
            .showOutputWindow,
            .hideOutputWindow
        ].forEach { effect in
            XCTAssertEqual(effect.requiredBridgeDomain, .projection, "\(effect)")
        }
    }

    func testPPTEffectsRequirePPTDomain() {
        XCTAssertEqual(LiveRuntimeEffect.startPPTEventTap.requiredBridgeDomain, .ppt)
        XCTAssertEqual(LiveRuntimeEffect.stopPPTEventTap(reason: .operatorDisabled).requiredBridgeDomain, .ppt)
    }

    func testRunAppleScriptRequiresAutomationCommandDomain() {
        XCTAssertEqual(
            LiveRuntimeEffect.runAppleScript(script: "tell app", action: "keynote.next-slide").requiredBridgeDomain,
            .automationCommand
        )
    }

    func testAutomationNoticeEffectsRequireAutomationNoticeDomain() {
        let notice = AutomationRuntimeNoticePolicy.make(action: "keynote.next-slide")

        XCTAssertEqual(LiveRuntimeEffect.showAutomationNotice(notice).requiredBridgeDomain, .automationNotice)
        XCTAssertEqual(LiveRuntimeEffect.expireAutomationNotice(notice.id, at: Date()).requiredBridgeDomain, .automationNotice)
    }

    func testRecordSupportEventRequiresSupportDomain() {
        let event = LiveSupportEvent(
            timestamp: Date(timeIntervalSince1970: 1),
            kind: .projectionStarted,
            detail: "source=runtime-policy"
        )

        XCTAssertEqual(LiveRuntimeEffect.recordSupportEvent(event).requiredBridgeDomain, .support)
    }

    func testRunAppleScriptRedactsScriptForRecording() {
        let effect = LiveRuntimeEffect.runAppleScript(
            script: "tell application \"Keynote\" to open POSIX file \"/Users/operator/private.key\"",
            action: "keynote.open"
        )

        XCTAssertEqual(effect.redactedForRecording, .runAppleScript(script: "<redacted>", action: "keynote.open"))
    }

    func testSaveCompanyDisplayNameRedactsNameForRecording() {
        let effect = LiveRuntimeEffect.saveCompanyDisplayName("机密客户甲有限公司")

        XCTAssertEqual(effect.redactedForRecording, .saveCompanyDisplayName("<redacted>"))
    }

    func testNonAutomationEffectsRecordAsThemselves() {
        XCTAssertEqual(LiveRuntimeEffect.playMedia(generation: 4).redactedForRecording, .playMedia(generation: 4))
        XCTAssertEqual(LiveRuntimeEffect.savePersistentState.redactedForRecording, .savePersistentState)
    }
}
