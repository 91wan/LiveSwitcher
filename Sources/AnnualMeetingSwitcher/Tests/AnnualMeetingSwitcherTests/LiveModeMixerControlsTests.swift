import XCTest
@testable import LiveSwitcher

@MainActor
final class LiveModeMixerControlsTests: XCTestCase {
    func testAudioMeterModelMapsMutedRealtimeAndEstimatedLevels() {
        let muted = LiveAudioMeterModel.make(effectiveVolume: 0, isMuted: true)
        XCTAssertEqual(muted.level, 0)
        XCTAssertEqual(muted.decibelText, "-∞ dB")
        XCTAssertEqual(muted.statusKind, .muted)
        XCTAssertFalse(muted.isEstimated)

        let realtimeWithGain = LiveAudioMeterModel.make(realtimeDB: -6, fallbackEffectiveVolume: 0.5, isMuted: false)
        XCTAssertEqual(realtimeWithGain.decibelText, "-12 dB")
        XCTAssertEqual(realtimeWithGain.statusKind, .ready)
        XCTAssertFalse(realtimeWithGain.isEstimated)

        let realtimeClipping = LiveAudioMeterModel.make(realtimeDB: -1, fallbackEffectiveVolume: 1, isMuted: false)
        XCTAssertEqual(realtimeClipping.decibelText, "-1 dB")
        XCTAssertEqual(realtimeClipping.statusKind, .warn)
        XCTAssertFalse(realtimeClipping.isEstimated)

        let estimated = LiveAudioMeterModel.make(realtimeDB: nil, fallbackEffectiveVolume: 0.5, isMuted: false)
        XCTAssertGreaterThan(estimated.level, 0)
        XCTAssertLessThan(estimated.level, 1)
        XCTAssertEqual(estimated.decibelText, "≈ -6 dB")
        XCTAssertEqual(estimated.statusKind, .ready)
        XCTAssertTrue(estimated.isEstimated)
    }

    func testAudioRoutingEngineAppliesPanicMuteTakeoverAndSpeakerLimiter() {
        var input = routingInput()

        XCTAssertEqual(AudioRoutingEngine.output(for: input), AudioRoutingOutput(media: 1, bgm: 0))

        input.isPanicMode = true
        XCTAssertEqual(AudioRoutingEngine.output(for: input), AudioRoutingOutput(media: 0, bgm: 0))

        input = routingInput()
        input.isMasterMuted = true
        XCTAssertEqual(AudioRoutingEngine.output(for: input), AudioRoutingOutput(media: 0, bgm: 0))

        input = routingInput()
        input.isBGMAudioTakeoverActive = true
        XCTAssertEqual(AudioRoutingEngine.output(for: input), AudioRoutingOutput(media: 0, bgm: 0.5))

        input = routingInput()
        input.audioStrategy = .mixed
        input.isSpeakerMode = true
        XCTAssertEqual(AudioRoutingEngine.output(for: input), AudioRoutingOutput(media: 0.07, bgm: 0.07))
    }

    func testAudioMixerPageModelSurfacesLimiterStatusAndChannelImpact() {
        let normal = mixerModel(isPanicMode: false, isSpeakerMode: false, isBGMAudioTakeoverActive: false)
        let speaker = mixerModel(isPanicMode: false, isSpeakerMode: true, isBGMAudioTakeoverActive: false)
        let takeover = mixerModel(isPanicMode: false, isSpeakerMode: false, isBGMAudioTakeoverActive: true)
        let panic = mixerModel(isPanicMode: true, isSpeakerMode: false, isBGMAudioTakeoverActive: false)

        XCTAssertEqual(normal.routingStatusText, AudioStrategy.followProgram.displayTitle)
        XCTAssertEqual(normal.routingStatusKind, .idle)
        XCTAssertEqual(normal.channelLimitText, "无强制静音")
        XCTAssertEqual(speaker.routingStatusText, "\(AudioStrategy.followProgram.displayTitle) · 主持人")
        XCTAssertEqual(speaker.routingStatusKind, .warn)
        XCTAssertEqual(speaker.channelLimitText, "压低：媒体、BGM")
        XCTAssertEqual(takeover.routingStatusText, "\(AudioStrategy.followProgram.displayTitle) · BGM 接管")
        XCTAssertEqual(takeover.channelLimitText, "静音：媒体")
        XCTAssertEqual(panic.routingStatusKind, .fail)
        XCTAssertEqual(panic.channelLimitText, "静音：媒体、BGM")
    }

    func testCutBusModelEnablesTakeNextOnlyWhenQueueHasNextPlayableItem() {
        let current = ProgramItem(id: UUID(), title: "Opening", subtitle: "MP4", sourceURL: fileURL("opening.mp4"))
        let marker = ProgramItem.agendaMarker(title: "Break")
        let next = ProgramItem(id: UUID(), title: "Awards", subtitle: "HTML", sourceURL: fileURL("awards.html"))

        let noNext = LiveCutBusModel.make(programItems: [current, marker], currentProgramItem: current)
        let hasNext = LiveCutBusModel.make(programItems: [current, marker, next], currentProgramItem: current)

        XCTAssertFalse(noNext.canTakeNext)
        XCTAssertNil(noNext.nextIndex)
        XCTAssertEqual(noNext.nextTitle, "没有下一项")
        XCTAssertTrue(hasNext.canTakeNext)
        XCTAssertEqual(hasNext.nextIndex, 2)
        XCTAssertEqual(hasNext.nextTitle, "Awards")
    }

    func testReturnToStartControlRequiresSeekableCurrentMedia() {
        let video = ProgramItem(title: "Video", subtitle: "VIDEO", sourceURL: fileURL("clip.mp4"))
        let html = ProgramItem(title: "HTML", subtitle: "HTML", sourceURL: fileURL("page.html"))

        let mediaControl = LiveMediaReturnToStartControlModel.make(currentItem: video)
        let htmlControl = LiveMediaReturnToStartControlModel.make(currentItem: html)
        let emptyControl = LiveMediaReturnToStartControlModel.make(currentItem: nil)

        XCTAssertTrue(mediaControl.isEnabled)
        XCTAssertEqual(mediaControl.title, "回到片头")
        XCTAssertEqual(mediaControl.help, "暂停当前视频并回到 00:00")
        XCTAssertFalse(htmlControl.isEnabled)
        XCTAssertFalse(emptyControl.isEnabled)
    }

    func testRuntimeStatusModelPrioritizesPreflightExceptionsAndSummary() {
        var snapshot = LivePreflightSnapshot.fixture(
            hasExternalDisplay: false,
            isBroadcasting: false,
            currentProgramTitle: nil,
            wallpaperCount: 0,
            effectiveMediaVolume: 0,
            effectiveBGMVolume: 0
        )

        let fail = LiveRuntimeStatusModel.make(snapshot: snapshot)
        XCTAssertEqual(fail.kind, .fail)
        XCTAssertTrue(fail.text.contains("外接显示器"))
        XCTAssertTrue(fail.text.contains("0 信号源"))

        snapshot = LivePreflightSnapshot.fixture(
            hasExternalDisplay: true,
            isBroadcasting: true,
            currentProgramTitle: "Opening",
            wallpaperCount: 1,
            effectiveMediaVolume: 0.5,
            effectiveBGMVolume: 0.4
        )
        let live = LiveRuntimeStatusModel.make(snapshot: snapshot)
        XCTAssertEqual(live.kind, .live)
        XCTAssertTrue(live.text.contains("直播"))
        XCTAssertTrue(live.text.contains("当前: Opening"))
    }

    func testMasterMeterChoosesLoudestRealtimePostFaderSourceAndIgnoresMutedStates() {
        let viewModel = makeViewModel()
        viewModel.masterVolume = 1
        viewModel.mediaVolume = 0.1
        viewModel.bgmVolume = 1
        viewModel.avCoordinator.isPlaying = true
        viewModel.avCoordinator.realtimeLevelDB = -6
        viewModel.bgmRealtimeLevelDB = -18
        viewModel.isBGMPlaying = true

        XCTAssertEqual(viewModel.liveMasterMeterRealtimeDB(), -18)
        XCTAssertEqual(viewModel.liveMasterMeterFallbackVolume(), viewModel.effectiveBGMOutputVolume())

        viewModel.isMasterAudioMuted = true
        XCTAssertNil(viewModel.liveMasterMeterRealtimeDB())
        XCTAssertEqual(
            viewModel.liveMasterMeterFallbackVolume(),
            max(viewModel.effectiveMediaOutputVolume(), viewModel.effectiveBGMOutputVolume())
        )
    }

    func testFadeToBlackAndReturnToStartDispatchNarrowLiveActions() {
        let media = ProgramItem(title: "Video", subtitle: "VIDEO", sourceURL: fileURL("clip.mp4"))
        let viewModel = makeViewModel(currentProgram: media)
        viewModel.isMasterAudioMuted = false
        viewModel.isMediaAudioMuted = false
        viewModel.isBGMAudioMuted = false

        viewModel.toggleFadeToBlack()
        XCTAssertTrue(viewModel.isFadeToBlackActive)
        XCTAssertFalse(viewModel.isPanicMode)
        XCTAssertFalse(viewModel.isMasterAudioMuted)
        XCTAssertFalse(viewModel.isMediaAudioMuted)
        XCTAssertFalse(viewModel.isBGMAudioMuted)
        XCTAssertTrue(viewModel.supportEvents.contains { $0.kind == .fadeToBlackChanged })

        viewModel.runtime.replaceStateForFacadeSync(viewModel.runtime.state, clearActionLog: true)
        viewModel.returnCurrentMediaToStart()
        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "operatorReturnedCurrentMediaToStart" })
        XCTAssertFalse(viewModel.runtime.actionLog.contains { $0.actionName == "operatorRestartedCurrentMedia" })
    }

    private func routingInput() -> AudioRoutingInput {
        AudioRoutingInput(
            masterVolume: 1,
            mediaVolume: 1,
            bgmVolume: 0.5,
            audioStrategy: .followProgram,
            isCurrentProgramMediaSource: true,
            isMediaPlaying: true,
            isBGMAudioTakeoverActive: false,
            isSpeakerMode: false,
            isPanicMode: false,
            speakerModeDuckedRatio: AudioRoutingDefaults.speakerModeDuckedRatio
        )
    }

    private func mixerModel(
        isPanicMode: Bool,
        isSpeakerMode: Bool,
        isBGMAudioTakeoverActive: Bool
    ) -> AudioMixerPageModel {
        AudioMixerPageModel(
            masterVolume: 1,
            mediaVolume: 1,
            mediaEffectiveVolume: 1,
            bgmVolume: 0.5,
            bgmEffectiveVolume: 0.5,
            strategy: .followProgram,
            isPanicMode: isPanicMode,
            isSpeakerMode: isSpeakerMode,
            isBGMAudioTakeoverActive: isBGMAudioTakeoverActive
        )
    }

    private func makeViewModel(currentProgram: ProgramItem? = nil) -> SwitcherViewModel {
        var state = LiveRuntimeState()
        if let currentProgram {
            state.program.items = [currentProgram]
            state.program.currentID = currentProgram.id
        }
        let runtime = LiveRuntimeStore(
            initialState: state,
            effectRunner: .recording(),
            environment: .productionProgramActivationOwning()
        )
        let viewModel = SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            userDefaults: isolatedDefaults(),
            runtime: runtime
        )
        viewModel.syncProgramQueueFacadeFromRuntime()
        viewModel.syncCurrentProgramFacadeFromRuntime()
        return viewModel
    }

    private func isolatedDefaults() -> UserDefaults {
        let suiteName = "LiveModeMixerControlsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func fileURL(_ name: String) -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(name)
    }
}

private extension LivePreflightSnapshot {
    static func fixture(
        hasExternalDisplay: Bool,
        isBroadcasting: Bool,
        currentProgramTitle: String?,
        wallpaperCount: Int,
        effectiveMediaVolume: Float,
        effectiveBGMVolume: Float
    ) -> LivePreflightSnapshot {
        LivePreflightSnapshot(
            appVersion: "0.0.0",
            hasExternalDisplay: hasExternalDisplay,
            isBroadcasting: isBroadcasting,
            broadcastSafetyNotice: nil,
            programItemCount: currentProgramTitle == nil ? 0 : 1,
            currentProgramTitle: currentProgramTitle,
            currentProgramSource: currentProgramTitle == nil ? nil : "Media",
            bgmItemCount: 1,
            isBGMPlaying: false,
            isBGMAudioTakeoverActive: false,
            isSpeakerMode: false,
            isPanicMode: false,
            isPageInterceptEnabled: false,
            activeOverlayCount: 0,
            activeOverlayKinds: [],
            countdownRemainingSeconds: nil,
            wallpaperCount: wallpaperCount,
            autoPlayNextVideoOnEnd: false,
            effectiveMediaVolume: effectiveMediaVolume,
            effectiveBGMVolume: effectiveBGMVolume
        )
    }
}
