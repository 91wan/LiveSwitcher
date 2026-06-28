import XCTest
@testable import LiveSwitcher

@MainActor
final class PersistentStateRuntimeLoadPreferencesTests: XCTestCase {
    func testApplyPersistentStateHydratesRuntimeOwnedFieldsWithoutFacadeDispatch() {
        let state = SwitcherPersistentState(
            audioStrategy: .followSource,
            isSpeakerMode: true,
            bgmPlayMode: .loopOne,
            activeWallpaperURL: URL(fileURLWithPath: "/tmp/loaded-wallpaper.png"),
            cornerLogoURL: URL(fileURLWithPath: "/tmp/loaded-logo.png"),
            cornerLogoPosition: .bottomRight,
            autoPlayNextVideoOnEnd: true,
            isAgendaTimeReminderEnabled: true,
            showAgendaTimeline: true,
            consoleMode: .live,
            themeOverride: .light
        )
        let viewModel = persistentRuntimeLoadMakeViewModel(bridgeMode: .bgmOwned)

        viewModel.applyPersistentState(state)

        XCTAssertEqual(viewModel.runtime.state.audio.strategy, .followSource)
        XCTAssertTrue(viewModel.runtime.state.audio.isSpeakerMode)
        XCTAssertEqual(viewModel.runtime.state.bgm.playMode, .loopOne)
        XCTAssertEqual(viewModel.runtime.state.mode, .live)
        XCTAssertEqual(viewModel.runtime.state.preferences.themeOverride, .light)
        XCTAssertEqual(viewModel.runtime.state.preferences.activeWallpaperURL, state.activeWallpaperURL)
        XCTAssertEqual(viewModel.runtime.state.preferences.cornerLogoURL, state.cornerLogoURL)
        XCTAssertTrue(viewModel.runtime.state.preferences.autoPlayNextVideoOnEnd)
        XCTAssertTrue(viewModel.runtime.state.preferences.isAgendaTimeReminderEnabled)
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
                 .saveAgendaTimeReminderEnabled,
                 .saveShowAgendaTimeline,
                 .saveCornerLogoPosition:
                return true
            default:
                return false
            }
        })
    }

    func testApplyPersistentStatePreservesExistingRuntimeActionLog() {
        let viewModel = persistentRuntimeLoadMakeViewModel(bridgeMode: .bgmOwned)
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
        let item = persistentRuntimeLoadProgramItem("Facade Loaded")
        let state = SwitcherPersistentState(
            audioStrategy: .bgmOnly,
            isSpeakerMode: true,
            bgmPlayMode: .sequential,
            programItems: [item],
            activeWallpaperURL: URL(fileURLWithPath: "/tmp/facade-wallpaper.png"),
            cornerLogoURL: URL(fileURLWithPath: "/tmp/facade-logo.png"),
            cornerLogoPosition: .bottomLeft,
            autoPlayNextVideoOnEnd: true,
            isAgendaTimeReminderEnabled: true,
            showAgendaTimeline: true,
            consoleMode: .live,
            themeOverride: .system
        )
        let viewModel = persistentRuntimeLoadMakeViewModel(bridgeMode: .recordingOnly)

        viewModel.applyPersistentState(state)

        XCTAssertEqual(viewModel.audioStrategy, .bgmOnly)
        XCTAssertTrue(viewModel.isSpeakerMode)
        XCTAssertEqual(viewModel.bgmPlayMode, .sequential)
        XCTAssertEqual(viewModel.programItems, [item])
        XCTAssertEqual(viewModel.activeWallpaperURL, state.activeWallpaperURL)
        XCTAssertEqual(viewModel.cornerLogoURL, state.cornerLogoURL)
        XCTAssertEqual(viewModel.cornerLogoPosition, .bottomLeft)
        XCTAssertTrue(viewModel.autoPlayNextVideoOnEnd)
        XCTAssertTrue(viewModel.isAgendaTimeReminderEnabled)
        XCTAssertTrue(viewModel.showAgendaTimeline)
        XCTAssertEqual(viewModel.consoleMode, .live)
        XCTAssertEqual(viewModel.themeOverride, .system)
    }

    func testApplyPersistentStateHydratesRuntimeAfterFinalFacadeSync() throws {
        let source = try persistentRuntimeLoadSource()
        let body = try XCTUnwrap(source.extractedRuntimeFunctionBody(named: "applyPersistentState"))
        let syncRange = try XCTUnwrap(body.range(of: "syncRuntimeStateFromFacade(clearActionLog: false, dispatchAudioInputsChanged: false)"))
        let hydrateRange = try XCTUnwrap(body.range(of: "runtime.hydratePersistentOwnedState(state)"))

        XCTAssertLessThan(syncRange.lowerBound, hydrateRange.lowerBound)
    }

    func testPersistentProjectionUsesScopedFacadeDispatchSuppression() throws {
        let source = try persistentRuntimeLoadSource()
        let body = try XCTUnwrap(source.extractedRuntimeFunctionBody(named: "projectPersistentStateToFacadeDuringLoad"))

        XCTAssertTrue(body.contains("withRuntimeFacadeDispatchSuppressed"))
        XCTAssertTrue(body.contains("audioStrategy = state.audioStrategy"))
        XCTAssertTrue(body.contains("themeOverride = state.themeOverride"))
    }

    func testPersistentProjectionDoesNotMutateRuntimeBridgeMode() throws {
        let source = try persistentRuntimeLoadSource()
        let body = try XCTUnwrap(source.extractedRuntimeFunctionBody(named: "projectPersistentStateToFacadeDuringLoad"))

        XCTAssertFalse(body.contains("updateRuntimeEnvironment"))
        XCTAssertFalse(body.contains("bridgeMode"))
    }

    func testPersistentProjectionDoesNotReferenceRecordingOnly() throws {
        let source = try persistentRuntimeLoadSource()

        XCTAssertFalse(source.contains(".recordingOnly"))
    }

    func testPersistentProjectionDoesNotDispatchOperatorActions() {
        let viewModel = persistentRuntimeLoadMakeViewModel(bridgeMode: .panicOwned)

        viewModel.applyPersistentState(SwitcherPersistentState(
            audioStrategy: .followSource,
            isSpeakerMode: true,
            bgmPlayMode: .loopOne,
            consoleMode: .live,
            themeOverride: .light
        ))

        XCTAssertFalse(viewModel.runtime.actionLog.contains {
            $0.actionName.hasPrefix("operator")
        })
    }

    func testPersistentProjectionRestoresDispatchAfterCompletion() {
        let viewModel = persistentRuntimeLoadMakeViewModel(bridgeMode: .panicOwned)

        viewModel.applyPersistentState(SwitcherPersistentState(audioStrategy: .followSource))
        viewModel.dispatchRuntimeFacadeAction(.operatorSetConsoleMode(.live))

        XCTAssertEqual(viewModel.runtime.state.mode, .live)
        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "operatorSetConsoleMode" })
    }

    func testRecordingOnlyPersistentLoadMirrorsFacadePreferencesIntoRuntimeShadow() {
        let viewModel = persistentRuntimeLoadMakeViewModel(bridgeMode: .recordingOnly)
        let wallpaperURL = URL(fileURLWithPath: "/tmp/persistent-wallpaper.png")

        viewModel.applyPersistentState(SwitcherPersistentState(
            activeWallpaperURL: wallpaperURL,
            cornerLogoPosition: .bottomLeft,
            autoPlayNextVideoOnEnd: true,
            isAgendaTimeReminderEnabled: true,
            showAgendaTimeline: true,
            consoleMode: .live,
            themeOverride: .system
        ))

        XCTAssertEqual(viewModel.runtime.state.mode, .live)
        XCTAssertEqual(viewModel.runtime.state.preferences.themeOverride, .system)
        XCTAssertEqual(viewModel.runtime.state.preferences.activeWallpaperURL, wallpaperURL)
        XCTAssertEqual(viewModel.runtime.state.preferences.cornerLogoPosition, .bottomLeft)
        XCTAssertTrue(viewModel.runtime.state.preferences.autoPlayNextVideoOnEnd)
        XCTAssertTrue(viewModel.runtime.state.preferences.isAgendaTimeReminderEnabled)
        XCTAssertTrue(viewModel.runtime.state.preferences.showAgendaTimeline)
    }

    func testPersistentLoadDoesNotCreateOperatorActionLogEntries() {
        let viewModel = persistentRuntimeLoadMakeViewModel(bridgeMode: .panicOwned)

        viewModel.applyPersistentState(SwitcherPersistentState(
            audioStrategy: .followSource,
            isSpeakerMode: true,
            consoleMode: .live,
            themeOverride: .light
        ))

        XCTAssertTrue(viewModel.runtime.actionLog.allSatisfy { !$0.actionName.hasPrefix("operator") })
    }

    func testLiveRuntimeStoreDoesNotExposePersistentLoadReplacementAPI() throws {
        let source = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeStore.swift")

        XCTAssertFalse(source.contains("replaceStateForPersistentLoad"))
    }

    func testPersistentLoadUsesExistingFacadeSyncReplacementAPI() throws {
        let source = try persistentRuntimeLoadSource()

        XCTAssertTrue(source.contains("syncRuntimeStateFromFacade(clearActionLog: false, dispatchAudioInputsChanged: false)"))
        XCTAssertFalse(source.contains("preservingActionLog"))
    }

    func testPersistentLoadPreservesExistingActionLogWithoutRepairAPI() {
        let viewModel = persistentRuntimeLoadMakeViewModel(bridgeMode: .panicOwned)
        viewModel.dispatchRuntimeFacadeAction(.operatorSetConsoleMode(.live))
        let existingActionLog = viewModel.runtime.actionLog

        viewModel.applyPersistentState(SwitcherPersistentState(audioStrategy: .followSource))

        XCTAssertEqual(viewModel.runtime.actionLog, existingActionLog)
    }

    func testPersistentLoadEmitsNoSaveEffects() {
        let viewModel = persistentRuntimeLoadMakeViewModel(bridgeMode: .panicOwned)

        viewModel.applyPersistentState(SwitcherPersistentState(
            audioStrategy: .followSource,
            isSpeakerMode: true,
            bgmPlayMode: .loopOne,
            consoleMode: .live,
            themeOverride: .light
        ))

        XCTAssertFalse(viewModel.runtime.recordedEffects.contains {
            switch $0 {
            case .saveAudioStrategy,
                 .saveSpeakerMode,
                 .saveBGMPlayMode,
                 .saveConsoleMode,
                 .saveThemeOverride,
                 .saveAutoPlayNextVideoOnEnd,
                 .saveAgendaTimeReminderEnabled,
                 .saveShowAgendaTimeline,
                 .saveCornerLogoPosition:
                return true
            default:
                return false
            }
        })
    }

    func testPersistentLoadKeepsBridgeModePanicOwnedThroughoutImplementationBoundary() throws {
        let source = try persistentRuntimeLoadSource()

        XCTAssertFalse(source.contains("updateRuntimeEnvironment(bridgeMode:"))
        XCTAssertFalse(source.contains("bridgeMode: .recordingOnly"))
        XCTAssertFalse(source.contains("requiresSilentProjection"))
    }

    func testProductionViewModelRuntimeBridgeModeRemainsPanicOwned() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)

        XCTAssertEqual(viewModel.runtimeBridgeMode, .panicOwned)
    }

    func testProductionConnectedPortsRemainPanicOwnedSet() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)

        XCTAssertEqual(
            viewModel.runtimeConnectedPortKinds,
            [
                .media,
                .bgm,
                .bgmTimer,
                .panicDelay,
                .projection,
                .ppt,
                .automationNotice,
                .support,
                .automation,
                .presentationQuery,
                .programActivation,
                .audioRouting,
                .imageAssets,
                .persistence
            ]
        )
    }

    func testNoPersistentLoadBridgeModeDomainOrPortAdded() {
        for rawValue in ["persistentLoadOwned", "silentProjectionOwned", "facadeDispatchSuppressedOwned"] {
            XCTAssertFalse(LiveRuntimeBridgeMode.allCases.contains { $0.rawValue == rawValue }, rawValue)
        }
        for rawValue in ["persistentLoad", "silentProjection", "facadeDispatchSuppressed"] {
            XCTAssertFalse(LiveRuntimeDomain.allCases.contains { $0.rawValue == rawValue }, rawValue)
            XCTAssertFalse(LiveRuntimeEffectPortKind.allCases.contains { $0.rawValue == rawValue }, rawValue)
        }
    }
}
