import XCTest
@testable import LiveSwitcher

@MainActor
final class BGMRuntimePanicBridgeTests: XCTestCase {
    func testPanicActivatePausesBGMThroughRuntimePort() {
        let viewModel = makeViewModel()
        let item = bgmItem(title: "Walk-in")
        viewModel.liveAudioFadeDuration = 0
        viewModel.bgmItems = [item]
        viewModel.toggleBGM(item)

        viewModel.togglePanicMode()

        XCTAssertTrue(hasPauseBGMEffect(in: viewModel))
        XCTAssertFalse(viewModel.isBGMPlaying)
    }

    func testPanicDeactivateResumesBGMThroughRuntimePortWhenSnapshotMatches() {
        let viewModel = makeViewModel()
        let item = bgmItem(title: "Walk-in")
        viewModel.liveAudioFadeDuration = 0
        viewModel.bgmItems = [item]
        viewModel.toggleBGM(item)
        viewModel.togglePanicMode()

        viewModel.togglePanicMode()

        XCTAssertTrue(hasPlayBGMEffect(in: viewModel))
        XCTAssertTrue(viewModel.isBGMPlaying)
    }

    func testPanicDeactivateDoesNotResumeBGMWhenTrackChanged() {
        let viewModel = makeViewModel()
        let first = bgmItem(title: "First")
        let second = bgmItem(title: "Second")
        viewModel.liveAudioFadeDuration = 0
        viewModel.bgmItems = [first, second]
        viewModel.toggleBGM(first)
        viewModel.togglePanicMode()
        viewModel.toggleBGM(second)

        viewModel.togglePanicMode()

        XCTAssertFalse(viewModel.isBGMPlaying)
    }

    func testPanicActivateFadesBGMToZeroBeforePause() {
        let viewModel = makeViewModel()
        let item = bgmItem(title: "Walk-in")
        viewModel.liveAudioFadeDuration = 0.05
        viewModel.bgmItems = [item]
        viewModel.toggleBGM(item)

        viewModel.togglePanicMode()

        XCTAssertEqual(viewModel.lastAudioRoutingTransition?.bgmFadeDuration, 0.05)
        XCTAssertTrue(viewModel.isBGMPlaying)
        RunLoop.main.run(until: Date().addingTimeInterval(0.09))
        XCTAssertFalse(viewModel.isBGMPlaying)
    }

    func testPanicPauseDoesNotHardCutBGMImmediatelyWhenFadeDurationPositive() {
        let viewModel = makeViewModel()
        let item = bgmItem(title: "Walk-in")
        viewModel.liveAudioFadeDuration = 0.05
        viewModel.bgmItems = [item]
        viewModel.toggleBGM(item)

        viewModel.togglePanicMode()

        XCTAssertTrue(viewModel.isBGMPlaying)
    }

    func testPanicDoesNotDirectlyCallBGMPlayers() throws {
        let source = try sourceText("ViewModel+Panic.swift")

        XCTAssertFalse(source.contains("bgmAudioPlayer?.pause()"))
        XCTAssertFalse(source.contains("bgmFallbackPlayer.pause()"))
        XCTAssertFalse(source.contains("bgmFallbackPlayer.play()"))
        XCTAssertFalse(source.contains("bgmAudioPlayer?.play()"))
        XCTAssertFalse(source.contains("startBGMTimer()"))
        XCTAssertFalse(source.contains("stopBGMTimer()"))
    }

    func testPanicDoesNotDirectlyStartStopBGMTimer() throws {
        let source = try sourceText("ViewModel+Panic.swift")

        XCTAssertFalse(source.contains("startBGMTimer"))
        XCTAssertFalse(source.contains("stopBGMTimer"))
    }

    func testPanicBGMResumeStartsAtZeroVolumeBeforeFade() {
        var state = LiveRuntimeState()
        let item = bgmItem(title: "Walk-in")
        state.bgm.items = [item]
        state.bgm.currentID = item.id
        state.bgm.generation = 6
        state.bgm.isPlaying = false

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .operatorResumedBGMAfterPanic(generation: 6),
            environment: .productionBGMOwning()
        )

        XCTAssertEqual(mutation.effects.prefix(2), [
            .setBGMVolume(0, fade: 0, generation: 6),
            .playBGM(generation: 6)
        ])
    }

    func testMediaPanicBridgeStillWorks() {
        var state = LiveRuntimeState()
        state.media.generation = 4
        state.media.isPlaying = true

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .operatorPausedMediaForPanic(generation: 4),
            environment: .productionBGMOwning()
        )

        XCTAssertFalse(mutation.state.media.isPlaying)
        XCTAssertTrue(mutation.effects.contains(.pauseMedia(generation: 4)))
    }

    private func makeViewModel() -> SwitcherViewModel {
        let suiteName = "BGMRuntimePanicBridgeTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false, userDefaults: defaults)
    }

    private func bgmItem(title: String) -> BGMItem {
        BGMItem(title: title, url: URL(fileURLWithPath: "/tmp/\(UUID().uuidString).mp3"))
    }

    private func hasPauseBGMEffect(in viewModel: SwitcherViewModel) -> Bool {
        viewModel.runtime.recordedEffects.contains {
            if case .pauseBGM = $0 { return true }
            return false
        }
    }

    private func hasPlayBGMEffect(in viewModel: SwitcherViewModel) -> Bool {
        viewModel.runtime.recordedEffects.contains {
            if case .playBGM = $0 { return true }
            return false
        }
    }

    private func sourceText(_ relativePath: String) throws -> String {
        try String(contentsOf: sourceURL(relativePath), encoding: .utf8)
    }

    private func sourceURL(_ relativePath: String) throws -> URL {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let candidates = [
            packageRoot.appendingPathComponent("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher").appendingPathComponent(relativePath),
            packageRoot.appendingPathComponent("Sources/AnnualMeetingSwitcher").appendingPathComponent(relativePath),
            packageRoot.appendingPathComponent(relativePath)
        ]
        if let url = candidates.first(where: { FileManager.default.fileExists(atPath: $0.path) }) {
            return url
        }
        return candidates[0]
    }
}
