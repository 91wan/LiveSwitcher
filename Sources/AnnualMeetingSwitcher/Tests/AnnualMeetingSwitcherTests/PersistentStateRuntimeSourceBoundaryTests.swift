import XCTest
@testable import LiveSwitcher

@MainActor
final class PersistentStateRuntimeSourceBoundaryTests: XCTestCase {
    func testRuntimeOwnedPersistentSnapshotUsesRuntimeSources() {
        let programItem = programItem("Runtime Program")
        var state = LiveRuntimeState()
        state.mode = .live
        state.audio.strategy = .followProgram
        state.audio.isSpeakerMode = true
        state.bgm.playMode = .loopOne
        state.program.items = [programItem]
        state.preferences.themeOverride = .system
        state.preferences.activeWallpaperURL = URL(fileURLWithPath: "/tmp/runtime-wallpaper.png")
        state.preferences.cornerLogoURL = URL(fileURLWithPath: "/tmp/runtime-logo.png")
        state.preferences.autoPlayNextVideoOnEnd = true
        state.preferences.isAgendaTimeReminderEnabled = true
        state.preferences.showAgendaTimeline = false
        state.preferences.cornerLogoPosition = .bottomLeft
        let viewModel = makeViewModel(runtimeState: state, bridgeMode: .panicOwned)
        configureStalePersistentFacade(viewModel)
        viewModel.runtime.replaceStateForFacadeSync(state, clearActionLog: true)

        let snapshot = viewModel.makePersistentStateSnapshot()

        XCTAssertEqual(snapshot.audioStrategy, .followProgram)
        XCTAssertTrue(snapshot.isSpeakerMode)
        XCTAssertEqual(snapshot.bgmPlayMode, .loopOne)
        XCTAssertEqual(snapshot.programItems, [programItem])
        XCTAssertEqual(snapshot.consoleMode, .live)
        XCTAssertEqual(snapshot.themeOverride, .system)
        XCTAssertEqual(snapshot.activeWallpaperURL, state.preferences.activeWallpaperURL)
        XCTAssertEqual(snapshot.cornerLogoURL, state.preferences.cornerLogoURL)
        XCTAssertTrue(snapshot.autoPlayNextVideoOnEnd)
        XCTAssertTrue(snapshot.isAgendaTimeReminderEnabled)
        XCTAssertFalse(snapshot.showAgendaTimeline)
        XCTAssertEqual(snapshot.cornerLogoPosition, .bottomLeft)
    }

    func testViewModelOwnedLibrariesStillUseFacadeSourcesInPersistentSnapshot() {
        let bgmItem = BGMItem(title: "Library BGM", url: URL(fileURLWithPath: "/tmp/library.mp3"), category: .award)
        let wallpaper = URL(fileURLWithPath: "/tmp/facade-library-wallpaper.png")
        let lowerThird = LowerThirdPreset(id: UUID(), name: "Name", role: "Role", organization: "Org", orderIndex: 0)
        let countdown = CountdownPreset(id: UUID(), title: "Break", totalSeconds: 60, orderIndex: 0)
        let ticker = TickerPreset(id: UUID(), text: "Welcome", speedIndex: 0, orderIndex: 0)
        let viewModel = makeViewModel(bridgeMode: .panicOwned)
        viewModel.bgmItems = [bgmItem]
        viewModel.backgroundWallpapers = [wallpaper]
        viewModel.lowerThirdPresets = [lowerThird]
        viewModel.countdownPresets = [countdown]
        viewModel.tickerPresets = [ticker]

        let snapshot = viewModel.makePersistentStateSnapshot()

        XCTAssertEqual(snapshot.bgmItems, [bgmItem])
        XCTAssertEqual(snapshot.backgroundWallpapers, [wallpaper])
        XCTAssertEqual(snapshot.lowerThirdPresets, [lowerThird])
        XCTAssertEqual(snapshot.countdownPresets, [countdown])
        XCTAssertEqual(snapshot.tickerPresets, [ticker])
    }

    func testPersistentSnapshotSourceUsesRuntimeBackedHelpers() throws {
        let source = try persistenceSource()
        let body = try XCTUnwrap(source.extractedRuntimeFunctionBody(named: "makePersistentStateSnapshot"))

        [
            "audioStrategy: audioStrategy",
            "isSpeakerMode: isSpeakerMode",
            "bgmPlayMode: bgmPlayMode",
            "programItems: programItems",
            "activeWallpaperURL: activeWallpaperURL",
            "cornerLogoURL: cornerLogoURL",
            "cornerLogoPosition: cornerLogoPosition",
            "autoPlayNextVideoOnEnd: autoPlayNextVideoOnEnd",
            "isAgendaTimeReminderEnabled: isAgendaTimeReminderEnabled",
            "showAgendaTimeline: showAgendaTimeline",
            "consoleMode: consoleMode",
            "themeOverride: themeOverride"
        ].forEach { directSource in
            XCTAssertFalse(body.contains(directSource), directSource)
        }
        XCTAssertTrue(source.contains("runtimeBackedPreferencesForPersistentSnapshot"))
        XCTAssertTrue(source.contains("runtimeBackedAudioStrategyForPersistentSnapshot"))
        XCTAssertTrue(source.contains("runtimeBackedBGMPlayModeForPersistentSnapshot"))
        XCTAssertTrue(source.contains("runtimeBackedProgramItemsForPersistentSnapshot"))
    }

    private func makeViewModel(
        runtimeState: LiveRuntimeState = LiveRuntimeState(),
        bridgeMode: LiveRuntimeBridgeMode
    ) -> SwitcherViewModel {
        let runtime = LiveRuntimeStore(
            initialState: runtimeState,
            effectRunner: .recording(),
            environment: LiveRuntimeEnvironment(bridgeMode: bridgeMode)
        )
        return SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            runtime: runtime
        )
    }

    private func configureStalePersistentFacade(_ viewModel: SwitcherViewModel) {
        viewModel.audioStrategy = .bgmOnly
        viewModel.isSpeakerMode = false
        viewModel.bgmPlayMode = .sequential
        viewModel.applyProgramQueueProjectionFromRuntime([programItem("Facade Program")])
        viewModel.consoleMode = .setup
        viewModel.themeOverride = .dark
        viewModel.activeWallpaperURL = URL(fileURLWithPath: "/tmp/facade-wallpaper.png")
        viewModel.cornerLogoURL = URL(fileURLWithPath: "/tmp/facade-logo.png")
        viewModel.cornerLogoPosition = .topRight
        viewModel.autoPlayNextVideoOnEnd = false
        viewModel.isAgendaTimeReminderEnabled = false
        viewModel.showAgendaTimeline = true
    }

    private func programItem(_ title: String) -> ProgramItem {
        ProgramItem(title: title, subtitle: "MEDIA", sourceURL: URL(fileURLWithPath: "/tmp/\(title).mp4"))
    }

    private func persistenceSource() throws -> String {
        try XCTUnwrap(optionalRepositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+Persistence.swift"
        ))
    }
}
