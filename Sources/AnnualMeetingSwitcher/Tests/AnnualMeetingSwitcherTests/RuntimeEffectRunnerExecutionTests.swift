import XCTest
@testable import LiveSwitcher

final class RuntimeEffectRunnerExecutionTests: XCTestCase {
    func testEffectRunnerRecordsRedactedEffects() {
        let runner = LiveRuntimeEffectRunner.recording()

        runner.run(
            [.runAppleScript(script: "tell application \"Keynote\" to open POSIX file \"/tmp/private.key\"", action: "keynote.open")],
            currentState: { LiveRuntimeState() },
            dispatch: { _ in XCTFail("Effect runner should not dispatch") }
        )

        XCTAssertEqual(runner.recordedEffects, [.runAppleScript(script: "<redacted>", action: "keynote.open")])
    }

    func testEffectRunnerRecordsOnlyDoesNotExecutePorts() {
        let media = RunnerMediaPortSpy()
        let runner = LiveRuntimeEffectRunner(recordsOnly: true, media: media)

        runner.run(
            [.playMedia(generation: 1)],
            currentState: { LiveRuntimeState() },
            dispatch: { _ in XCTFail("Effect runner should not dispatch") }
        )

        XCTAssertEqual(runner.recordedEffects, [.playMedia(generation: 1)])
        XCTAssertEqual(media.calls, [])
    }

    func testEffectRunnerConnectedPortsUnchangedAfterSplit() {
        let runner = SwitcherRuntimePortBundle().makeEffectRunner()

        XCTAssertEqual(
            runner.connectedPortKinds,
            [.media, .bgm, .bgmTimer, .projection, .ppt, .automationNotice, .support, .automation, .presentationQuery, .audioRouting, .imageAssets, .persistence]
        )
    }

    func testMediaEffectsRespectCurrentGeneration() {
        let media = RunnerMediaPortSpy()
        let runner = LiveRuntimeEffectRunner(recordsOnly: false, media: media)
        var state = LiveRuntimeState()
        state.media.generation = 3

        runner.run(
            [.loadMedia(URL(fileURLWithPath: "/tmp/current.mp4"), generation: 3), .playMedia(generation: 3)],
            currentState: { state },
            dispatch: { _ in XCTFail("Effect runner should not dispatch") }
        )

        XCTAssertEqual(media.calls, ["load:3:/tmp/current.mp4", "play:3"])
    }

    func testStaleMediaEffectsAreIgnored() {
        let media = RunnerMediaPortSpy()
        let runner = LiveRuntimeEffectRunner(recordsOnly: false, media: media)
        var state = LiveRuntimeState()
        state.media.generation = 3

        runner.run(
            [.loadMedia(URL(fileURLWithPath: "/tmp/stale.mp4"), generation: 2), .playMedia(generation: 2)],
            currentState: { state },
            dispatch: { _ in XCTFail("Effect runner should not dispatch") }
        )

        XCTAssertEqual(media.calls, [])
    }

    func testBGMEffectsRespectCurrentGeneration() {
        let bgm = RunnerBGMPortSpy()
        let runner = LiveRuntimeEffectRunner(recordsOnly: false, bgm: bgm)
        let item = BGMItem(title: "Current", url: URL(fileURLWithPath: "/tmp/current.mp3"))
        var state = LiveRuntimeState()
        state.bgm.generation = 5

        runner.run(
            [.prepareBGM(item, generation: 5), .playBGM(generation: 5)],
            currentState: { state },
            dispatch: { _ in XCTFail("Effect runner should not dispatch") }
        )

        XCTAssertEqual(bgm.calls, ["prepare:5:Current", "play:5"])
    }

    func testStaleBGMEffectsAreIgnored() {
        let bgm = RunnerBGMPortSpy()
        let runner = LiveRuntimeEffectRunner(recordsOnly: false, bgm: bgm)
        let item = BGMItem(title: "Stale", url: URL(fileURLWithPath: "/tmp/stale.mp3"))
        var state = LiveRuntimeState()
        state.bgm.generation = 5

        runner.run(
            [.prepareBGM(item, generation: 4), .playBGM(generation: 4)],
            currentState: { state },
            dispatch: { _ in XCTFail("Effect runner should not dispatch") }
        )

        XCTAssertEqual(bgm.calls, [])
    }

    func testBGMPlayModeNilGenerationExecutes() {
        let bgm = RunnerBGMPortSpy()
        let runner = LiveRuntimeEffectRunner(recordsOnly: false, bgm: bgm)

        runner.run(
            [.setBGMPlayMode(.sequential, generation: nil)],
            currentState: { LiveRuntimeState() },
            dispatch: { _ in XCTFail("Effect runner should not dispatch") }
        )

        XCTAssertEqual(bgm.calls, ["playMode:nil:\(BGMPlayMode.sequential.rawValue)"])
    }

    func testAudioRoutingEffectReceivesCurrentState() {
        let audio = RunnerAudioRoutingPortSpy()
        let runner = LiveRuntimeEffectRunner(recordsOnly: false, audioRouting: audio)
        var state = LiveRuntimeState()
        state.audio.isSpeakerMode = true

        runner.run(
            [.applyAudioRouting(reason: .speakerChanged)],
            currentState: { state },
            dispatch: { _ in XCTFail("Effect runner should not dispatch") }
        )

        XCTAssertEqual(audio.reasons, [.speakerChanged])
        XCTAssertEqual(audio.speakerModes, [true])
    }

    func testSupportRecordEffectCallsSupportPort() {
        let support = RunnerSupportPortSpy()
        let runner = LiveRuntimeEffectRunner(recordsOnly: false, support: support)
        let event = LiveSupportEvent(
            timestamp: Date(timeIntervalSince1970: 10),
            kind: .projectionStarted,
            detail: "source=runner"
        )

        runner.run(
            [.recordSupportEvent(event)],
            currentState: { LiveRuntimeState() },
            dispatch: { _ in XCTFail("Effect runner should not dispatch") }
        )

        XCTAssertEqual(support.events, [event])
    }

    func testAutomationRunEffectPassesRawScriptToPortButRecordsRedacted() {
        let automation = RunnerAutomationPortSpy()
        let runner = LiveRuntimeEffectRunner(recordsOnly: false, automation: automation)
        let rawScript = "tell application \"Keynote\" to open POSIX file \"/tmp/private.key\""

        runner.run(
            [.runAppleScript(script: rawScript, action: "keynote.open")],
            currentState: { LiveRuntimeState() },
            dispatch: { _ in XCTFail("Effect runner should not dispatch") }
        )

        XCTAssertEqual(automation.calls, ["keynote.open:\(rawScript)"])
        XCTAssertEqual(runner.recordedEffects, [.runAppleScript(script: "<redacted>", action: "keynote.open")])
    }
}

private final class RunnerMediaPortSpy: MediaPlaybackPort {
    private(set) var calls: [String] = []

    func load(url: URL, generation: Int) { calls.append("load:\(generation):\(url.path)") }
    func play(generation: Int) { calls.append("play:\(generation)") }
    func pause(generation: Int) { calls.append("pause:\(generation)") }
    func restart(generation: Int) { calls.append("restart:\(generation)") }
    func seekToStart(generation: Int) { calls.append("seekToStart:\(generation)") }
    func seekToEnd(generation: Int) { calls.append("seekToEnd:\(generation)") }
    func stop(generation: Int) { calls.append("stop:\(generation)") }
    func setVolume(_ volume: Float, fade: TimeInterval, generation: Int) {
        calls.append("volume:\(generation):\(volume):\(fade)")
    }
}

private final class RunnerBGMPortSpy: BGMPlaybackPort {
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

private final class RunnerAudioRoutingPortSpy: AudioRoutingPort {
    private(set) var reasons: [AudioRoutingRuntimeChangeReason] = []
    private(set) var speakerModes: [Bool] = []

    func apply(reason: AudioRoutingRuntimeChangeReason, state: LiveRuntimeState) {
        reasons.append(reason)
        speakerModes.append(state.audio.isSpeakerMode)
    }
}

private final class RunnerSupportPortSpy: SupportEventPort {
    private(set) var events: [LiveSupportEvent] = []

    func record(_ event: LiveSupportEvent) {
        events.append(event)
    }
}

private final class RunnerAutomationPortSpy: AutomationPort {
    private(set) var calls: [String] = []

    func run(script: String, action: String) {
        calls.append("\(action):\(script)")
    }
}
