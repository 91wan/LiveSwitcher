import XCTest
@testable import LiveSwitcher

final class LiveRuntimeEffectRunnerTests: XCTestCase {
    func testLiveRunnerInvokesInjectedPortsForRuntimeEffects() {
        let media = MediaPortSpy()
        let bgm = BGMPortSpy()
        let projection = ProjectionPortSpy()
        let ppt = PPTEventTapPortSpy()
        let automation = AutomationPortSpy()
        let bgmTimer = BGMTimerPortSpy()
        let automationNotice = AutomationNoticePortSpy()
        let audioRouting = AudioRoutingPortSpy()
        let persistence = PersistencePortSpy()
        let support = SupportEventPortSpy()
        let runner = LiveRuntimeEffectRunner(
            recordsOnly: false,
            media: media,
            bgm: bgm,
            projection: projection,
            ppt: ppt,
            automation: automation,
            bgmTimer: bgmTimer,
            automationNotice: automationNotice,
            audioRouting: audioRouting,
            persistence: persistence,
            support: support
        )
        let bgmItem = BGMItem(title: "Walk In", url: URL(fileURLWithPath: "/tmp/walk-in.mp3"))
        let notice = AutomationRuntimeNoticePolicy.make(
            action: "keynote.next-slide",
            createdAt: Date(timeIntervalSince1970: 1_790_000_100)
        )
        let noticeExpiresAt = Date(timeIntervalSince1970: 1_790_000_130)
        let event = LiveSupportEvent(
            timestamp: Date(timeIntervalSince1970: 1_790_000_000),
            kind: .panicModeChanged,
            detail: "isOn=true"
        )
        var state = LiveRuntimeState()
        state.panic.isActive = true

        runner.run(
            [
                .loadMedia(URL(fileURLWithPath: "/tmp/video.mp4"), generation: 7),
                .playMedia(generation: 7),
                .pauseMedia(generation: 7),
                .restartMedia(generation: 7),
                .stopMedia(generation: 7),
                .setMediaVolume(0.4, fade: 0.2, generation: 7),
                .prepareBGM(bgmItem, generation: 3),
                .playBGM(generation: 3),
                .pauseBGM(generation: 3),
                .stopBGM(fade: 0.5, generation: 3),
                .setBGMVolume(0.6, fade: 0.25, generation: 3),
                .startBGMTimer(generation: 3),
                .stopBGMTimer(generation: 3),
                .startProjection,
                .showOutputWindow,
                .stopProjection,
                .hideOutputWindow,
                .startPPTEventTap,
                .stopPPTEventTap(reason: .failed),
                .runAppleScript(script: "tell app", action: "keynote.next-slide"),
                .showAutomationNotice(notice),
                .expireAutomationNotice(notice.id, at: noticeExpiresAt),
                .applyAudioRouting(reason: .panicChanged),
                .saveAudioStrategy(.followSource),
                .saveSpeakerMode(true),
                .savePersistentState,
                .recordSupportEvent(event)
            ],
            currentState: { state },
            dispatch: { _ in XCTFail("Effect runner should not dispatch for these synchronous effects") }
        )

        XCTAssertEqual(media.calls, [
            "load:7:/tmp/video.mp4",
            "play:7",
            "pause:7",
            "restart:7",
            "stop:7",
            "volume:7:0.4:0.2"
        ])
        XCTAssertEqual(bgm.calls, [
            "prepare:3:Walk In",
            "play:3",
            "pause:3",
            "stop:3:0.5",
            "volume:3:0.6:0.25"
        ])
        XCTAssertEqual(projection.calls, ["start", "show", "stop", "hide"])
        XCTAssertEqual(ppt.calls, ["start", "stop:failed"])
        XCTAssertEqual(automation.calls, ["run:keynote.next-slide:tell app"])
        XCTAssertEqual(bgmTimer.calls, ["start:3", "stop:3"])
        XCTAssertEqual(automationNotice.calls, [
            "show:keynote.next-slide",
            "expire:\(notice.id.uuidString):\(noticeExpiresAt.timeIntervalSince1970)"
        ])
        XCTAssertEqual(audioRouting.reasons, [.panicChanged])
        XCTAssertEqual(audioRouting.panicStates, [true])
        XCTAssertEqual(persistence.savedAudioStrategies, [.followSource])
        XCTAssertEqual(persistence.savedSpeakerModes, [true])
        XCTAssertEqual(persistence.saveCount, 1)
        XCTAssertEqual(support.events, [event])
        XCTAssertEqual(runner.recordedEffects.count, 27)
    }

    func testRecordingRunnerDoesNotInvokeInjectedPorts() {
        let media = MediaPortSpy()
        let runner = LiveRuntimeEffectRunner(recordsOnly: true, media: media)

        runner.run(
            [.playMedia(generation: 1)],
            currentState: { LiveRuntimeState() },
            dispatch: { _ in XCTFail("Recording runner should not dispatch") }
        )

        XCTAssertEqual(media.calls, [])
        XCTAssertEqual(runner.recordedEffects, [.playMedia(generation: 1)])
    }
}

private final class MediaPortSpy: MediaPlaybackPort {
    private(set) var calls: [String] = []

    func load(url: URL, generation: Int) {
        calls.append("load:\(generation):\(url.path)")
    }

    func play(generation: Int) {
        calls.append("play:\(generation)")
    }

    func pause(generation: Int) {
        calls.append("pause:\(generation)")
    }

    func restart(generation: Int) {
        calls.append("restart:\(generation)")
    }

    func stop(generation: Int) {
        calls.append("stop:\(generation)")
    }

    func setVolume(_ volume: Float, fade: TimeInterval, generation: Int) {
        calls.append("volume:\(generation):\(volume):\(fade)")
    }
}

private final class BGMPortSpy: BGMPlaybackPort {
    private(set) var calls: [String] = []

    func prepare(item: BGMItem, generation: Int) {
        calls.append("prepare:\(generation):\(item.title)")
    }

    func play(generation: Int) {
        calls.append("play:\(generation)")
    }

    func pause(generation: Int) {
        calls.append("pause:\(generation)")
    }

    func stop(fade: TimeInterval, generation: Int) {
        calls.append("stop:\(generation):\(fade)")
    }

    func setVolume(_ volume: Float, fade: TimeInterval, generation: Int) {
        calls.append("volume:\(generation):\(volume):\(fade)")
    }
}

private final class ProjectionPortSpy: ProjectionPort {
    var hasExternalDisplay = true
    private(set) var calls: [String] = []

    func start() {
        calls.append("start")
    }

    func stop() {
        calls.append("stop")
    }

    func show() {
        calls.append("show")
    }

    func hide() {
        calls.append("hide")
    }
}

private final class PPTEventTapPortSpy: PPTEventTapPort {
    private(set) var calls: [String] = []

    func start() {
        calls.append("start")
    }

    func stop(reason: PPTStopReason) {
        calls.append("stop:\(reason.rawValue)")
    }
}

private final class AutomationPortSpy: AutomationPort {
    private(set) var calls: [String] = []

    func run(script: String, action: String) {
        calls.append("run:\(action):\(script)")
    }
}

private final class BGMTimerPortSpy: BGMTimerPort {
    private(set) var calls: [String] = []

    func start(generation: Int) {
        calls.append("start:\(generation)")
    }

    func stop(generation: Int) {
        calls.append("stop:\(generation)")
    }
}

private final class AutomationNoticePortSpy: AutomationNoticePort {
    private(set) var calls: [String] = []

    func show(_ notice: AutomationRuntimeNotice) {
        calls.append("show:\(notice.action)")
    }

    func expire(id: UUID, at date: Date) {
        calls.append("expire:\(id.uuidString):\(date.timeIntervalSince1970)")
    }
}

private final class AudioRoutingPortSpy: AudioRoutingPort {
    private(set) var reasons: [AudioRoutingRuntimeChangeReason] = []
    private(set) var panicStates: [Bool] = []

    func apply(reason: AudioRoutingRuntimeChangeReason, state: LiveRuntimeState) {
        reasons.append(reason)
        panicStates.append(state.panic.isActive)
    }
}

private final class PersistencePortSpy: PersistencePort {
    private(set) var saveCount = 0
    private(set) var savedAudioStrategies: [AudioStrategy] = []
    private(set) var savedSpeakerModes: [Bool] = []

    func save() {
        saveCount += 1
    }

    func saveAudioStrategy(_ strategy: AudioStrategy) {
        savedAudioStrategies.append(strategy)
    }

    func saveSpeakerMode(_ isEnabled: Bool) {
        savedSpeakerModes.append(isEnabled)
    }
}

private final class SupportEventPortSpy: SupportEventPort {
    private(set) var events: [LiveSupportEvent] = []

    func record(_ event: LiveSupportEvent) {
        events.append(event)
    }
}
