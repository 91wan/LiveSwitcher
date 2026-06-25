import XCTest
@testable import LiveSwitcher

@MainActor
final class LiveRuntimeEffectRunnerDispatchTests: XCTestCase {
    func testMediaEffectsStillUseMediaPort() {
        let media = DispatchMediaPortSpy()
        let runner = LiveRuntimeEffectRunner(recordsOnly: false, media: media)
        var state = LiveRuntimeState()
        state.media.generation = 10

        runner.run(
            [.loadMedia(URL(fileURLWithPath: "/tmp/show.mp4"), generation: 10), .pauseMedia(generation: 10)],
            currentState: { state },
            dispatch: failIfDispatched()
        )

        XCTAssertEqual(media.calls, ["load:10:/tmp/show.mp4", "pause:10"])
    }

    func testBGMEffectsStillUseBGMPort() {
        let bgm = DispatchBGMPortSpy()
        let runner = LiveRuntimeEffectRunner(recordsOnly: false, bgm: bgm)
        var state = LiveRuntimeState()
        state.bgm.generation = 11
        let item = BGMItem(title: "Walk In", url: URL(fileURLWithPath: "/tmp/walkin.mp3"))

        runner.run(
            [.prepareBGM(item, generation: 11), .setBGMVolume(0.3, fade: 0.5, generation: 11)],
            currentState: { state },
            dispatch: failIfDispatched()
        )

        XCTAssertEqual(bgm.calls, ["prepare:11:Walk In", "volume:11:0.3:0.5"])
    }

    func testBGMTimerEffectsStillUseBGMTimerPort() {
        let timer = DispatchBGMTimerPortSpy()
        let runner = LiveRuntimeEffectRunner(recordsOnly: false, bgmTimer: timer)
        var state = LiveRuntimeState()
        state.bgm.generation = 12

        runner.run(
            [.startBGMTimer(generation: 12), .stopBGMTimer(generation: 12)],
            currentState: { state },
            dispatch: failIfDispatched()
        )

        XCTAssertEqual(timer.calls, ["start:12", "stop:12"])
    }

    func testProjectionEffectsStillUseProjectionPort() {
        let projection = DispatchProjectionPortSpy()
        let runner = LiveRuntimeEffectRunner(recordsOnly: false, projection: projection)

        runner.run(
            [.startProjection, .showOutputWindow, .hideOutputWindow, .stopProjection],
            currentState: { LiveRuntimeState() },
            dispatch: failIfDispatched()
        )

        XCTAssertEqual(projection.calls, ["start", "show", "hide", "stop"])
    }

    func testPPTEffectsStillUsePPTPort() {
        let ppt = DispatchPPTPortSpy()
        let runner = LiveRuntimeEffectRunner(recordsOnly: false, ppt: ppt)

        runner.run(
            [.startPPTEventTap, .stopPPTEventTap(reason: .operatorDisabled)],
            currentState: { LiveRuntimeState() },
            dispatch: failIfDispatched()
        )

        XCTAssertEqual(ppt.calls, ["start", "stop:operatorDisabled"])
    }

    func testRunAppleScriptStillUsesAutomationPort() {
        let automation = DispatchAutomationPortSpy()
        let runner = LiveRuntimeEffectRunner(recordsOnly: false, automation: automation)
        let script = "tell application \"Keynote\" to show next"

        runner.run(
            [.runAppleScript(script: script, action: "keynote.next-slide")],
            currentState: { LiveRuntimeState() },
            dispatch: failIfDispatched()
        )

        XCTAssertEqual(automation.calls, ["keynote.next-slide:\(script)"])
    }

    func testAutomationNoticeEffectsStillUseAutomationNoticePort() {
        let notices = DispatchAutomationNoticePortSpy()
        let runner = LiveRuntimeEffectRunner(recordsOnly: false, automationNotice: notices)
        let id = UUID(uuidString: "7a43d924-1a58-45dc-9d7b-344a838d77c2")!
        let notice = AutomationRuntimeNotice(
            id: id,
            action: "keynote.next-slide",
            title: "Title",
            message: "Message",
            severity: .warn,
            primaryAction: nil,
            createdAt: Date(timeIntervalSince1970: 100),
            expiresAfter: 3
        )
        let expiresAt = Date(timeIntervalSince1970: 103)

        runner.run(
            [.showAutomationNotice(notice), .expireAutomationNotice(id, at: expiresAt)],
            currentState: { LiveRuntimeState() },
            dispatch: failIfDispatched()
        )

        XCTAssertEqual(notices.calls, ["show:keynote.next-slide", "expire:\(id.uuidString):103"])
    }

    func testAudioRoutingEffectStillUsesCurrentStateFromContext() {
        let audio = DispatchAudioRoutingPortSpy()
        let runner = LiveRuntimeEffectRunner(recordsOnly: false, audioRouting: audio)
        var state = LiveRuntimeState()
        state.audio.isSpeakerMode = true

        runner.run(
            [.applyAudioRouting(reason: .speakerChanged)],
            currentState: { state },
            dispatch: failIfDispatched()
        )

        XCTAssertEqual(audio.reasons, [.speakerChanged])
        XCTAssertEqual(audio.speakerModes, [true])
    }

    func testImageAssetEffectsStillUseImageAssetPort() {
        let assets = DispatchImageAssetPortSpy()
        let runner = LiveRuntimeEffectRunner(recordsOnly: false, imageAssets: assets)

        runner.run(
            [
                .loadBackgroundImage(URL(fileURLWithPath: "/tmp/bg.png")),
                .loadCornerLogoImage(URL(fileURLWithPath: "/tmp/logo.png"))
            ],
            currentState: { LiveRuntimeState() },
            dispatch: failIfDispatched()
        )

        XCTAssertEqual(assets.calls, ["background:/tmp/bg.png", "corner:/tmp/logo.png"])
    }

    func testPersistenceEffectsStillUsePersistencePort() {
        let persistence = DispatchPersistencePortSpy()
        let runner = LiveRuntimeEffectRunner(recordsOnly: false, persistence: persistence)

        runner.run(
            [.saveConsoleMode(.live), .saveBGMPlayMode(.sequential), .savePersistentState],
            currentState: { LiveRuntimeState() },
            dispatch: failIfDispatched()
        )

        XCTAssertEqual(persistence.calls, ["console:live", "bgmPlayMode:\(BGMPlayMode.sequential.rawValue)", "save"])
    }

    func testSupportEffectStillUsesSupportPort() {
        let support = DispatchSupportPortSpy()
        let runner = LiveRuntimeEffectRunner(recordsOnly: false, support: support)
        let event = LiveSupportEvent(
            timestamp: Date(timeIntervalSince1970: 200),
            kind: .projectionStarted,
            detail: "source=dispatch-test"
        )

        runner.run(
            [.recordSupportEvent(event)],
            currentState: { LiveRuntimeState() },
            dispatch: failIfDispatched()
        )

        XCTAssertEqual(support.events, [event])
    }

    private func failIfDispatched() -> (LiveRuntimeAction) -> Void {
        { action in XCTFail("Existing effects must not dispatch callback action \(action.redactedName) in this PR") }
    }
}

private final class DispatchMediaPortSpy: MediaPlaybackPort {
    private(set) var calls: [String] = []

    func load(url: URL, generation: Int) { calls.append("load:\(generation):\(url.path)") }
    func play(generation: Int) { calls.append("play:\(generation)") }
    func pause(generation: Int) { calls.append("pause:\(generation)") }
    func restart(generation: Int) { calls.append("restart:\(generation)") }
    func seekToStart(generation: Int) { calls.append("seekToStart:\(generation)") }
    func seekToEnd(generation: Int) { calls.append("seekToEnd:\(generation)") }
    func seek(toProgress progress: Double, generation: Int) { calls.append("seekToProgress:\(generation):\(progress)") }
    func stop(generation: Int) { calls.append("stop:\(generation)") }
    func setVolume(_ volume: Float, fade: TimeInterval, generation: Int) {
        calls.append("volume:\(generation):\(volume):\(fade)")
    }
}

private final class DispatchBGMPortSpy: BGMPlaybackPort {
    private(set) var calls: [String] = []

    func prepare(item: BGMItem, generation: Int) { calls.append("prepare:\(generation):\(item.title)") }
    func play(generation: Int) { calls.append("play:\(generation)") }
    func pause(generation: Int) { calls.append("pause:\(generation)") }
    func stop(fade: TimeInterval, generation: Int) { calls.append("stop:\(generation):\(fade)") }
    func setVolume(_ volume: Float, fade: TimeInterval, generation: Int) {
        calls.append("volume:\(generation):\(volume):\(fade)")
    }
    func seekToBeginning(generation: Int) { calls.append("seekToBeginning:\(generation)") }
    func seek(toProgress progress: Double, generation: Int) { calls.append("seekToProgress:\(generation):\(progress)") }
    func setPlayMode(_ playMode: BGMPlayMode, generation: Int?) {
        calls.append("playMode:\(generation.map(String.init) ?? "nil"):\(playMode.rawValue)")
    }
}

private final class DispatchBGMTimerPortSpy: BGMTimerPort {
    private(set) var calls: [String] = []

    func start(generation: Int) { calls.append("start:\(generation)") }
    func stop(generation: Int) { calls.append("stop:\(generation)") }
}

private final class DispatchProjectionPortSpy: ProjectionPort {
    var hasExternalDisplay = true
    private(set) var calls: [String] = []

    func start() { calls.append("start") }
    func stop() { calls.append("stop") }
    func show() { calls.append("show") }
    func hide() { calls.append("hide") }
}

private final class DispatchPPTPortSpy: PPTEventTapPort {
    private(set) var calls: [String] = []

    func start() { calls.append("start") }
    func stop(reason: PPTStopReason) { calls.append("stop:\(reason.rawValue)") }
}

private final class DispatchAutomationPortSpy: AutomationPort {
    private(set) var calls: [String] = []

    func run(script: String, action: String) { calls.append("\(action):\(script)") }
}

private final class DispatchAutomationNoticePortSpy: AutomationNoticePort {
    private(set) var calls: [String] = []

    func show(_ notice: AutomationRuntimeNotice) { calls.append("show:\(notice.action)") }
    func expire(id: UUID, at date: Date) { calls.append("expire:\(id.uuidString):\(Int(date.timeIntervalSince1970))") }
}

private final class DispatchAudioRoutingPortSpy: AudioRoutingPort {
    private(set) var reasons: [AudioRoutingRuntimeChangeReason] = []
    private(set) var speakerModes: [Bool] = []

    func apply(reason: AudioRoutingRuntimeChangeReason, state: LiveRuntimeState) {
        reasons.append(reason)
        speakerModes.append(state.audio.isSpeakerMode)
    }
}

private final class DispatchImageAssetPortSpy: ImageAssetPort {
    private(set) var calls: [String] = []

    func loadBackgroundImage(from url: URL?) { calls.append("background:\(url?.path ?? "nil")") }
    func loadCornerLogoImage(from url: URL?) { calls.append("corner:\(url?.path ?? "nil")") }
}

private final class DispatchPersistencePortSpy: PersistencePort {
    private(set) var calls: [String] = []

    func save() { calls.append("save") }
    func saveConsoleMode(_ mode: ConsoleMode) { calls.append("console:\(mode.rawValue)") }
    func saveThemeOverride(_ theme: ThemeOverride) { calls.append("theme:\(theme.rawValue)") }
    func saveAudioStrategy(_ strategy: AudioStrategy) { calls.append("audio:\(strategy.rawValue)") }
    func saveSpeakerMode(_ isEnabled: Bool) { calls.append("speaker:\(isEnabled)") }
    func saveBGMPlayMode(_ playMode: BGMPlayMode) { calls.append("bgmPlayMode:\(playMode.rawValue)") }
    func saveAutoPlayNextVideoOnEnd(_ isEnabled: Bool) { calls.append("autoPlay:\(isEnabled)") }
    func saveAutoAdvanceAtScheduledTime(_ isEnabled: Bool) { calls.append("autoAdvance:\(isEnabled)") }
    func saveShowAgendaTimeline(_ isEnabled: Bool) { calls.append("agenda:\(isEnabled)") }
    func saveCornerLogoPosition(_ position: CornerLogoPosition) { calls.append("logoPosition:\(position.rawValue)") }
}

private final class DispatchSupportPortSpy: SupportEventPort {
    private(set) var events: [LiveSupportEvent] = []

    func record(_ event: LiveSupportEvent) { events.append(event) }
}
