import XCTest
@testable import LiveSwitcher

@MainActor
final class RuntimeClosurePortsTests: XCTestCase {
    func testClosureMediaPlaybackPortForwardsEveryMethod() {
        let port = ClosureMediaPlaybackPort()
        var events: [String] = []
        let url = URL(fileURLWithPath: "/tmp/media.mp4")
        port.loadHandler = { events.append("load:\($0.lastPathComponent):\($1)") }
        port.playHandler = { events.append("play:\($0)") }
        port.pauseHandler = { events.append("pause:\($0)") }
        port.restartHandler = { events.append("restart:\($0)") }
        port.seekToStartHandler = { events.append("seekStart:\($0)") }
        port.seekToEndHandler = { events.append("seekEnd:\($0)") }
        port.stopHandler = { events.append("stop:\($0)") }
        port.setVolumeHandler = { events.append("volume:\($0):\($1):\($2)") }

        port.load(url: url, generation: 1)
        port.play(generation: 2)
        port.pause(generation: 3)
        port.restart(generation: 4)
        port.seekToStart(generation: 5)
        port.seekToEnd(generation: 6)
        port.stop(generation: 7)
        port.setVolume(0.5, fade: 0.25, generation: 8)

        XCTAssertEqual(events, [
            "load:media.mp4:1",
            "play:2",
            "pause:3",
            "restart:4",
            "seekStart:5",
            "seekEnd:6",
            "stop:7",
            "volume:0.5:0.25:8"
        ])
    }

    func testClosureBGMPlaybackPortForwardsEveryMethod() {
        let port = ClosureBGMPlaybackPort()
        var events: [String] = []
        let item = BGMItem(title: "Walk In", url: URL(fileURLWithPath: "/tmp/walk-in.mp3"))
        port.prepareHandler = { events.append("prepare:\($0.title):\($1)") }
        port.playHandler = { events.append("play:\($0)") }
        port.pauseHandler = { events.append("pause:\($0)") }
        port.stopHandler = { events.append("stop:\($0):\($1)") }
        port.setVolumeHandler = { events.append("volume:\($0):\($1):\($2)") }
        port.seekToBeginningHandler = { events.append("begin:\($0)") }
        port.seekToProgressHandler = { events.append("progress:\($0):\($1)") }
        port.setPlayModeHandler = { events.append("mode:\($0.rawValue):\($1 ?? -1)") }

        port.prepare(item: item, generation: 1)
        port.play(generation: 2)
        port.pause(generation: 3)
        port.stop(fade: 0.4, generation: 4)
        port.setVolume(0.6, fade: 0.5, generation: 5)
        port.seekToBeginning(generation: 6)
        port.seek(toProgress: 0.7, generation: 7)
        port.setPlayMode(.loopOne, generation: 8)

        XCTAssertEqual(events, [
            "prepare:Walk In:1",
            "play:2",
            "pause:3",
            "stop:0.4:4",
            "volume:0.6:0.5:5",
            "begin:6",
            "progress:0.7:7",
            "mode:单曲循环:8"
        ])
    }

    func testClosureProjectionPortForwardsStartStopShowHideAndAvailability() {
        let port = ClosureProjectionPort()
        var events: [String] = []
        port.hasExternalDisplayHandler = { true }
        port.startHandler = { events.append("start") }
        port.stopHandler = { events.append("stop") }
        port.showHandler = { events.append("show") }
        port.hideHandler = { events.append("hide") }

        XCTAssertTrue(port.hasExternalDisplay)
        port.start()
        port.stop()
        port.show()
        port.hide()

        XCTAssertEqual(events, ["start", "stop", "show", "hide"])
    }

    func testClosurePPTEventTapPortForwardsStartAndStop() {
        let port = ClosurePPTEventTapPort()
        var events: [String] = []
        port.startHandler = { events.append("start") }
        port.stopHandler = { events.append("stop:\($0.rawValue)") }

        port.start()
        port.stop(reason: .failed)

        XCTAssertEqual(events, ["start", "stop:failed"])
    }

    func testClosureAutomationNoticePortForwardsShowAndExpire() {
        let port = ClosureAutomationNoticePort()
        let id = UUID()
        let date = Date(timeIntervalSince1970: 10)
        let notice = AutomationRuntimeNotice(
            id: id,
            action: "keynote.next-slide",
            title: "title",
            message: "message",
            severity: .warn,
            primaryAction: .openSafetyCockpit,
            createdAt: date,
            expiresAfter: 1
        )
        var events: [String] = []
        port.showHandler = { events.append("show:\($0.id)") }
        port.expireHandler = { events.append("expire:\($0):\($1.timeIntervalSince1970)") }

        port.show(notice)
        port.expire(id: id, at: date)

        XCTAssertEqual(events, ["show:\(id)", "expire:\(id):10.0"])
    }

    func testClosureSupportEventPortForwardsRecord() {
        let port = ClosureSupportEventPort()
        let event = LiveSupportEvent(
            timestamp: Date(timeIntervalSince1970: 1),
            kind: .projectionStarted,
            detail: "isBroadcasting=true"
        )
        var recorded: [LiveSupportEvent] = []
        port.recordHandler = { recorded.append($0) }

        port.record(event)

        XCTAssertEqual(recorded, [event])
    }

    func testClosureAutomationPortForwardsRun() {
        let port = ClosureAutomationPort()
        var runs: [(String, String)] = []
        port.runHandler = { runs.append(($0, $1)) }

        port.run(script: "tell application \"Keynote\"", action: "keynote.present")

        XCTAssertEqual(runs.map(\.0), ["tell application \"Keynote\""])
        XCTAssertEqual(runs.map(\.1), ["keynote.present"])
    }

    func testClosureAudioRoutingPortForwardsApply() {
        let port = ClosureAudioRoutingPort()
        var reasons: [AudioRoutingRuntimeChangeReason] = []
        var states: [LiveRuntimeState] = []
        let state = LiveRuntimeState()
        port.applyHandler = {
            reasons.append($0)
            states.append($1)
        }

        port.apply(reason: .speakerChanged, state: state)

        XCTAssertEqual(reasons, [.speakerChanged])
        XCTAssertEqual(states, [state])
    }

    func testClosureImageAssetPortForwardsLoads() {
        let port = ClosureImageAssetPort()
        var backgrounds: [URL?] = []
        var logos: [URL?] = []
        let background = URL(fileURLWithPath: "/tmp/bg.png")
        let logo = URL(fileURLWithPath: "/tmp/logo.png")
        port.loadBackgroundImageHandler = { backgrounds.append($0) }
        port.loadCornerLogoImageHandler = { logos.append($0) }

        port.loadBackgroundImage(from: background)
        port.loadCornerLogoImage(from: logo)

        XCTAssertEqual(backgrounds, [background])
        XCTAssertEqual(logos, [logo])
    }

    func testClosurePersistencePortForwardsSpecificSaves() {
        let port = ClosurePersistencePort()
        var events: [String] = []
        port.saveHandler = { events.append("save") }
        port.saveConsoleModeHandler = { events.append("console:\($0.rawValue)") }
        port.saveThemeOverrideHandler = { events.append("theme:\($0.rawValue)") }
        port.saveAudioStrategyHandler = { events.append("strategy:\($0.rawValue)") }
        port.saveSpeakerModeHandler = { events.append("speaker:\($0)") }
        port.saveBGMPlayModeHandler = { events.append("bgmMode:\($0.rawValue)") }
        port.saveAutoPlayNextVideoOnEndHandler = { events.append("autoNext:\($0)") }
        port.saveAutoAdvanceAtScheduledTimeHandler = { events.append("autoAdvance:\($0)") }
        port.saveShowAgendaTimelineHandler = { events.append("timeline:\($0)") }
        port.saveCornerLogoPositionHandler = { events.append("corner:\($0.rawValue)") }

        port.save()
        port.saveConsoleMode(.live)
        port.saveThemeOverride(.dark)
        port.saveAudioStrategy(.mixed)
        port.saveSpeakerMode(true)
        port.saveBGMPlayMode(.sequential)
        port.saveAutoPlayNextVideoOnEnd(true)
        port.saveAutoAdvanceAtScheduledTime(true)
        port.saveShowAgendaTimeline(true)
        port.saveCornerLogoPosition(.bottomLeft)

        XCTAssertEqual(events, [
            "save",
            "console:live",
            "theme:dark",
            "strategy:mixed",
            "speaker:true",
            "bgmMode:顺序播放",
            "autoNext:true",
            "autoAdvance:true",
            "timeline:true",
            "corner:bottomLeft"
        ])
    }
}
