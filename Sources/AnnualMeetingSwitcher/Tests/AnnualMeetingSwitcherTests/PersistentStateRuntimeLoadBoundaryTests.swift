import XCTest
@testable import LiveSwitcher

@MainActor
final class PersistentStateRuntimeLoadBoundaryTests: XCTestCase {
    func testApplyPersistentStateHydratesRuntimeOwnedFieldsWithoutFacadeDispatch() {
        let state = SwitcherPersistentState(
            audioStrategy: .followSource,
            isSpeakerMode: true,
            bgmPlayMode: .loopOne,
            activeWallpaperURL: URL(fileURLWithPath: "/tmp/loaded-wallpaper.png"),
            cornerLogoURL: URL(fileURLWithPath: "/tmp/loaded-logo.png"),
            cornerLogoPosition: .bottomRight,
            autoPlayNextVideoOnEnd: true,
            autoAdvanceAtScheduledTime: true,
            showAgendaTimeline: true,
            consoleMode: .live,
            themeOverride: .light
        )
        let viewModel = makeViewModel(bridgeMode: .bgmOwned)

        viewModel.applyPersistentState(state)

        XCTAssertEqual(viewModel.runtime.state.audio.strategy, .followSource)
        XCTAssertTrue(viewModel.runtime.state.audio.isSpeakerMode)
        XCTAssertEqual(viewModel.runtime.state.bgm.playMode, .loopOne)
        XCTAssertEqual(viewModel.runtime.state.mode, .live)
        XCTAssertEqual(viewModel.runtime.state.preferences.themeOverride, .light)
        XCTAssertEqual(viewModel.runtime.state.preferences.activeWallpaperURL, state.activeWallpaperURL)
        XCTAssertEqual(viewModel.runtime.state.preferences.cornerLogoURL, state.cornerLogoURL)
        XCTAssertTrue(viewModel.runtime.state.preferences.autoPlayNextVideoOnEnd)
        XCTAssertTrue(viewModel.runtime.state.preferences.autoAdvanceAtScheduledTime)
        XCTAssertTrue(viewModel.runtime.state.preferences.showAgendaTimeline)
        XCTAssertEqual(viewModel.runtime.state.preferences.cornerLogoPosition, .bottomRight)
        XCTAssertTrue(viewModel.runtime.actionLog.isEmpty)
        XCTAssertFalse(viewModel.runtime.recordedEffects.contains { effect in
            switch effect {
            case .saveAudioStrategy,
                 .saveSpeakerMode,
                 .saveBGMPlayMode,
                 .saveConsoleMode,
                 .saveThemeOverride,
                 .saveAutoPlayNextVideoOnEnd,
                 .saveAutoAdvanceAtScheduledTime,
                 .saveShowAgendaTimeline,
                 .saveCornerLogoPosition:
                return true
            default:
                return false
            }
        })
    }

    func testApplyPersistentStatePreservesExistingRuntimeActionLog() {
        let viewModel = makeViewModel(bridgeMode: .bgmOwned)
        viewModel.runtime.dispatch(.operatorSetConsoleMode(.live))
        let existingActionLog = viewModel.runtime.actionLog

        viewModel.applyPersistentState(SwitcherPersistentState(
            audioStrategy: .followSource,
            isSpeakerMode: true,
            bgmPlayMode: .loopOne,
            consoleMode: .setup,
            themeOverride: .light
        ))

        XCTAssertEqual(viewModel.runtime.actionLog, existingActionLog)
    }

    func testApplyPersistentStateKeepsFacadeOwnedLoadBehaviorBeforeOwnership() {
        let item = programItem("Facade Loaded")
        let state = SwitcherPersistentState(
            audioStrategy: .bgmOnly,
            isSpeakerMode: true,
            bgmPlayMode: .sequential,
            programItems: [item],
            activeWallpaperURL: URL(fileURLWithPath: "/tmp/facade-wallpaper.png"),
            cornerLogoURL: URL(fileURLWithPath: "/tmp/facade-logo.png"),
            cornerLogoPosition: .bottomLeft,
            autoPlayNextVideoOnEnd: true,
            autoAdvanceAtScheduledTime: true,
            showAgendaTimeline: true,
            consoleMode: .live,
            themeOverride: .system
        )
        let viewModel = makeViewModel(bridgeMode: .recordingOnly)

        viewModel.applyPersistentState(state)

        XCTAssertEqual(viewModel.audioStrategy, .bgmOnly)
        XCTAssertTrue(viewModel.isSpeakerMode)
        XCTAssertEqual(viewModel.bgmPlayMode, .sequential)
        XCTAssertEqual(viewModel.programItems, [item])
        XCTAssertEqual(viewModel.activeWallpaperURL, state.activeWallpaperURL)
        XCTAssertEqual(viewModel.cornerLogoURL, state.cornerLogoURL)
        XCTAssertEqual(viewModel.cornerLogoPosition, .bottomLeft)
        XCTAssertTrue(viewModel.autoPlayNextVideoOnEnd)
        XCTAssertTrue(viewModel.autoAdvanceAtScheduledTime)
        XCTAssertTrue(viewModel.showAgendaTimeline)
        XCTAssertEqual(viewModel.consoleMode, .live)
        XCTAssertEqual(viewModel.themeOverride, .system)
    }

    func testApplyPersistentStateHydratesRuntimeProgramQueueWhenOwned() {
        let item = programItem("Runtime Loaded")
        let viewModel = makeViewModel(bridgeMode: .programQueueOwned)

        viewModel.applyPersistentState(SwitcherPersistentState(programItems: [item]))

        XCTAssertEqual(viewModel.runtime.state.program.items, [item])
        XCTAssertEqual(viewModel.programItems, [item])
        XCTAssertFalse(viewModel.runtime.actionLog.contains { $0.actionName == "facadeLoadedProgramQueue" })
    }

    func testApplyPersistentStateSourceUsesRuntimeHydrationHelper() throws {
        let source = try persistenceSource()

        XCTAssertTrue(source.contains("applyPersistentStateToRuntimeIfOwned"))
        XCTAssertTrue(source.contains("projectPersistentStateToFacadeDuringLoad"))
        XCTAssertTrue(source.contains("bridgeMode.owns(.audio)"))
        XCTAssertTrue(source.contains("bridgeMode.owns(.bgm)"))
        XCTAssertTrue(source.contains("bridgeMode.owns(.persistence)"))
        XCTAssertTrue(source.contains("runtime.replaceStateForPersistentLoad(runtimeState, preservingActionLog: actionLog)"))
    }

    private func makeViewModel(bridgeMode: LiveRuntimeBridgeMode) -> SwitcherViewModel {
        let runtime = LiveRuntimeStore(
            initialState: LiveRuntimeState(),
            effectRunner: .recording(),
            environment: LiveRuntimeEnvironment(bridgeMode: bridgeMode)
        )
        return SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            runtime: runtime
        )
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
