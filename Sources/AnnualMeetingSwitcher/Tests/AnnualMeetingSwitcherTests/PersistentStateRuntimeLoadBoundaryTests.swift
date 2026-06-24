import AppKit
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

        XCTAssertTrue(source.contains("runtime.hydratePersistentOwnedState(state)"))
        XCTAssertTrue(source.contains("projectPersistentStateToFacadeDuringLoad"))
        XCTAssertFalse(source.contains("applyPersistentStateToRuntimeIfOwned"))
        XCTAssertFalse(source.contains("runtimeState.audio.strategy"))
        XCTAssertFalse(source.contains("runtimeState.audio.isSpeakerMode"))
        XCTAssertFalse(source.contains("runtimeState.bgm.playMode"))
        XCTAssertFalse(source.contains("runtimeState.preferences ="))
        XCTAssertFalse(source.contains("AudioRuntimeReducer.recalculateAudio"))
        XCTAssertFalse(source.contains("replaceStateForPersistentLoad"))
    }

    func testApplyPersistentStateHydratesRuntimeAfterFinalFacadeSync() throws {
        let source = try persistenceSource()
        let body = try XCTUnwrap(source.extractedRuntimeFunctionBody(named: "applyPersistentState"))
        let syncRange = try XCTUnwrap(body.range(of: "syncRuntimeStateFromFacade(clearActionLog: false, dispatchAudioInputsChanged: false)"))
        let hydrateRange = try XCTUnwrap(body.range(of: "runtime.hydratePersistentOwnedState(state)"))

        XCTAssertLessThan(syncRange.lowerBound, hydrateRange.lowerBound)
    }

    func testPersistentProjectionUsesScopedFacadeDispatchSuppression() throws {
        let source = try persistenceSource()
        let body = try XCTUnwrap(source.extractedRuntimeFunctionBody(named: "projectPersistentStateToFacadeDuringLoad"))

        XCTAssertTrue(body.contains("withRuntimeFacadeDispatchSuppressed"))
        XCTAssertTrue(body.contains("audioStrategy = state.audioStrategy"))
        XCTAssertTrue(body.contains("themeOverride = state.themeOverride"))
    }

    func testPersistentProjectionDoesNotMutateRuntimeBridgeMode() throws {
        let source = try persistenceSource()
        let body = try XCTUnwrap(source.extractedRuntimeFunctionBody(named: "projectPersistentStateToFacadeDuringLoad"))

        XCTAssertFalse(body.contains("updateRuntimeEnvironment"))
        XCTAssertFalse(body.contains("bridgeMode"))
    }

    func testPersistentProjectionDoesNotReferenceRecordingOnly() throws {
        let source = try persistenceSource()

        XCTAssertFalse(source.contains(".recordingOnly"))
    }

    func testPersistentProjectionDoesNotDispatchOperatorActions() {
        let viewModel = makeViewModel(bridgeMode: .panicOwned)

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
        let viewModel = makeViewModel(bridgeMode: .panicOwned)

        viewModel.applyPersistentState(SwitcherPersistentState(audioStrategy: .followSource))
        viewModel.dispatchRuntimeFacadeAction(.operatorSetConsoleMode(.live))

        XCTAssertEqual(viewModel.runtime.state.mode, .live)
        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "operatorSetConsoleMode" })
    }

    func testRecordingOnlyPersistentLoadMirrorsFacadeAudioIntoRuntimeShadow() {
        let viewModel = makeViewModel(bridgeMode: .recordingOnly)

        viewModel.applyPersistentState(SwitcherPersistentState(
            audioStrategy: .followProgram,
            isSpeakerMode: true
        ))

        XCTAssertEqual(viewModel.runtime.state.audio.strategy, .followProgram)
        XCTAssertTrue(viewModel.runtime.state.audio.isSpeakerMode)
    }

    func testRecordingOnlyPersistentLoadMirrorsFacadePreferencesIntoRuntimeShadow() {
        let viewModel = makeViewModel(bridgeMode: .recordingOnly)
        let wallpaperURL = URL(fileURLWithPath: "/tmp/persistent-wallpaper.png")

        viewModel.applyPersistentState(SwitcherPersistentState(
            activeWallpaperURL: wallpaperURL,
            cornerLogoPosition: .bottomLeft,
            autoPlayNextVideoOnEnd: true,
            autoAdvanceAtScheduledTime: true,
            showAgendaTimeline: true,
            consoleMode: .live,
            themeOverride: .system
        ))

        XCTAssertEqual(viewModel.runtime.state.mode, .live)
        XCTAssertEqual(viewModel.runtime.state.preferences.themeOverride, .system)
        XCTAssertEqual(viewModel.runtime.state.preferences.activeWallpaperURL, wallpaperURL)
        XCTAssertEqual(viewModel.runtime.state.preferences.cornerLogoPosition, .bottomLeft)
        XCTAssertTrue(viewModel.runtime.state.preferences.autoPlayNextVideoOnEnd)
        XCTAssertTrue(viewModel.runtime.state.preferences.autoAdvanceAtScheduledTime)
        XCTAssertTrue(viewModel.runtime.state.preferences.showAgendaTimeline)
    }

    func testRecordingOnlyPersistentLoadMirrorsFacadeProgramQueueIntoRuntimeShadow() {
        let item = programItem("Recording Queue")
        let viewModel = makeViewModel(bridgeMode: .recordingOnly)

        viewModel.applyPersistentState(SwitcherPersistentState(programItems: [item]))

        XCTAssertEqual(viewModel.runtime.state.program.items, [item])
        XCTAssertEqual(viewModel.programItems, [item])
    }

    func testRecordingOnlyPersistentLoadMirrorsFacadeBGMPlayModeIntoRuntimeShadow() {
        let viewModel = makeViewModel(bridgeMode: .recordingOnly)

        viewModel.applyPersistentState(SwitcherPersistentState(bgmPlayMode: .sequential))

        XCTAssertEqual(viewModel.runtime.state.bgm.playMode, .sequential)
    }

    func testPersistentLoadPerformsNoFacadeAudioInputsChangedAction() {
        let viewModel = makeViewModel(bridgeMode: .panicOwned)

        viewModel.applyPersistentState(SwitcherPersistentState(audioStrategy: .followSource))

        XCTAssertFalse(viewModel.runtime.actionLog.contains { $0.actionName == "facadeAudioInputsChanged" })
        XCTAssertFalse(viewModel.runtime.recordedEffects.contains {
            if case .applyAudioRouting = $0 { return true }
            return false
        })
    }

    func testPersistentLoadDoesNotCreateOperatorActionLogEntries() {
        let viewModel = makeViewModel(bridgeMode: .panicOwned)

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
        let source = try persistenceSource()

        XCTAssertTrue(source.contains("syncRuntimeStateFromFacade(clearActionLog: false, dispatchAudioInputsChanged: false)"))
        XCTAssertFalse(source.contains("preservingActionLog"))
    }

    func testPersistentLoadPreservesExistingActionLogWithoutRepairAPI() {
        let viewModel = makeViewModel(bridgeMode: .panicOwned)
        viewModel.dispatchRuntimeFacadeAction(.operatorSetConsoleMode(.live))
        let existingActionLog = viewModel.runtime.actionLog

        viewModel.applyPersistentState(SwitcherPersistentState(audioStrategy: .followSource))

        XCTAssertEqual(viewModel.runtime.actionLog, existingActionLog)
    }

    func testPersistentHydrationDoesNotResetAudioSessionFields() {
        var state = LiveRuntimeState()
        state.audio.masterVolume = 0.2
        state.audio.isMasterMuted = true
        state.audio.isBGMTakeoverActive = true
        state.audio.effectiveMedia = 0.1
        state.audio.effectiveBGM = 0.4
        let viewModel = makeViewModel(runtimeState: state, bridgeMode: .panicOwned)

        viewModel.applyPersistentState(SwitcherPersistentState(
            audioStrategy: .followSource,
            isSpeakerMode: true
        ))

        XCTAssertEqual(viewModel.runtime.state.audio.masterVolume, 0.2)
        XCTAssertTrue(viewModel.runtime.state.audio.isMasterMuted)
        XCTAssertTrue(viewModel.runtime.state.audio.isBGMTakeoverActive)
        XCTAssertEqual(viewModel.runtime.state.audio.effectiveMedia, 0)
        XCTAssertEqual(viewModel.runtime.state.audio.effectiveBGM, 0)
    }

    func testPersistentHydrationDoesNotResetBGMPlaybackFields() {
        let item = BGMItem(title: "Runtime BGM", url: URL(fileURLWithPath: "/tmp/runtime-bgm.mp3"))
        var state = LiveRuntimeState()
        state.bgm.items = [item]
        state.bgm.currentID = item.id
        state.bgm.phase = .playing
        state.bgm.progress = 0.5
        state.bgm.generation = 8
        let viewModel = makeViewModel(runtimeState: state, bridgeMode: .panicOwned)

        viewModel.applyPersistentState(SwitcherPersistentState(bgmPlayMode: .loopOne))

        XCTAssertEqual(viewModel.runtime.state.bgm.currentID, item.id)
        XCTAssertTrue(viewModel.runtime.state.bgm.isPlaying)
        XCTAssertEqual(viewModel.runtime.state.bgm.progress, 0.5)
        XCTAssertEqual(viewModel.runtime.state.bgm.generation, 8)
    }

    func testPersistentLoadStillUsesFacadeLoadedProgramQueueWhenProgramQueueOwned() {
        let item = programItem("Runtime Loaded")
        let viewModel = makeViewModel(bridgeMode: .programQueueOwned)

        viewModel.applyPersistentState(SwitcherPersistentState(programItems: [item]))

        XCTAssertEqual(viewModel.runtime.state.program.items, [item])
        XCTAssertEqual(viewModel.programItems, [item])
    }

    func testPersistentLoadStillProjectsFacadeQueueBeforeProgramQueueOwnership() {
        let item = programItem("Facade Queue")
        let viewModel = makeViewModel(bridgeMode: .recordingOnly)

        viewModel.applyPersistentState(SwitcherPersistentState(programItems: [item]))

        XCTAssertEqual(viewModel.programItems, [item])
        XCTAssertEqual(viewModel.runtime.state.program.items, [item])
    }

    func testProgramQueueLoadDispatchOccursAfterSuppressionScopeEnds() {
        let item = programItem("Queue Dispatch")
        let viewModel = makeViewModel(bridgeMode: .programQueueOwned)

        viewModel.applyPersistentState(SwitcherPersistentState(
            programItems: [item],
            consoleMode: .live
        ))

        XCTAssertEqual(viewModel.runtimeFacadeDispatchSuppressionDepth, 0)
        XCTAssertEqual(viewModel.runtime.state.program.items, [item])
    }

    func testProgramQueueLoadStillDoesNotPolluteActionLog() {
        let item = programItem("Queue Dispatch")
        let viewModel = makeViewModel(bridgeMode: .programQueueOwned)

        viewModel.applyPersistentState(SwitcherPersistentState(programItems: [item]))

        XCTAssertFalse(viewModel.runtime.actionLog.contains { $0.actionName == "facadeLoadedProgramQueue" })
    }

    func testPersistentLoadStillLoadsBackgroundImage() {
        let viewModel = makeViewModel(bridgeMode: .panicOwned)
        let url = URL(fileURLWithPath: "/tmp/persistent-background.png")

        viewModel.applyPersistentState(SwitcherPersistentState(activeWallpaperURL: url))

        XCTAssertNotNil(viewModel.backgroundImage)
    }

    func testPersistentLoadStillLoadsCornerLogoImage() async throws {
        let viewModel = makeViewModel(bridgeMode: .panicOwned)
        let url = try makePNG(name: "persistent-logo")

        viewModel.applyPersistentState(SwitcherPersistentState(cornerLogoURL: url))
        await waitForCornerLogoReady(viewModel, activeURL: url)

        XCTAssertNotNil(viewModel.cornerLogoImage)
    }

    func testPersistentLoadStillClearsBackgroundImageForNilURL() {
        let viewModel = makeViewModel(bridgeMode: .panicOwned)
        viewModel.backgroundImage = NSImage(size: NSSize(width: 1, height: 1))

        viewModel.applyPersistentState(SwitcherPersistentState(activeWallpaperURL: nil))

        XCTAssertNil(viewModel.backgroundImage)
    }

    func testPersistentLoadStillClearsCornerLogoImageForNilURL() {
        let viewModel = makeViewModel(bridgeMode: .panicOwned)
        viewModel.cornerLogoImage = NSImage(size: NSSize(width: 1, height: 1))

        viewModel.applyPersistentState(SwitcherPersistentState(cornerLogoURL: nil))

        XCTAssertNil(viewModel.cornerLogoImage)
    }

    func testPersistentProjectionDoesNotDuplicateImageLoadThroughRuntimeEffects() {
        let viewModel = makeViewModel(bridgeMode: .panicOwned)

        viewModel.applyPersistentState(SwitcherPersistentState(
            activeWallpaperURL: URL(fileURLWithPath: "/tmp/background.png"),
            cornerLogoURL: URL(fileURLWithPath: "/tmp/logo.png")
        ))

        XCTAssertFalse(viewModel.runtime.recordedEffects.contains {
            switch $0 {
            case .loadBackgroundImage, .loadCornerLogoImage:
                return true
            default:
                return false
            }
        })
    }

    func testPersistentLoadEmitsNoSaveEffects() {
        let viewModel = makeViewModel(bridgeMode: .panicOwned)

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
                 .saveAutoAdvanceAtScheduledTime,
                 .saveShowAgendaTimeline,
                 .saveCornerLogoPosition:
                return true
            default:
                return false
            }
        })
    }

    func testPersistentLoadKeepsBridgeModePanicOwnedThroughoutImplementationBoundary() throws {
        let source = try persistenceSource()

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

    private func programItem(_ title: String) -> ProgramItem {
        ProgramItem(title: title, subtitle: "MEDIA", sourceURL: URL(fileURLWithPath: "/tmp/\(title).mp4"))
    }

    private func persistenceSource() throws -> String {
        try XCTUnwrap(optionalRepositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+Persistence.swift"
        ))
    }

    private func makePNG(name: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("live-switcher-\(name)-\(UUID().uuidString)")
            .appendingPathExtension("png")
        let image = NSImage(size: NSSize(width: 2, height: 2))
        image.lockFocus()
        NSColor.white.setFill()
        NSRect(x: 0, y: 0, width: 2, height: 2).fill()
        image.unlockFocus()
        let data = try XCTUnwrap(image.tiffRepresentation)
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: data))
        try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: url)
        return url
    }

    private func waitForCornerLogoReady(_ viewModel: SwitcherViewModel, activeURL: URL) async {
        for _ in 0..<100 {
            if viewModel.cornerLogoLoadPhase == .ready(activeURL: activeURL) {
                return
            }
            await Task.yield()
        }
        XCTFail("Corner logo did not become ready")
    }
}
