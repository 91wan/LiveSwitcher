import AppKit
import XCTest
@testable import LiveSwitcher

@MainActor
final class PersistentLoadRuntimePreservationTests: XCTestCase {
    func testPersistentLoadPreservesRuntimeCurrentProgramSelection() {
        let fixture = makeFixture()

        fixture.viewModel.applyPersistentState(fixture.persistentState)

        XCTAssertEqual(fixture.viewModel.runtime.state.program.currentID, fixture.original.program.currentID)
        XCTAssertEqual(fixture.viewModel.runtime.state.program.currentDetachedItem, fixture.original.program.currentDetachedItem)
        XCTAssertEqual(fixture.viewModel.runtime.state.program.currentSwitchedAt, fixture.original.program.currentSwitchedAt)
    }

    func testPersistentLoadPreservesRuntimeMediaPlaybackState() {
        let fixture = makeFixture()

        fixture.viewModel.applyPersistentState(fixture.persistentState)

        XCTAssertEqual(fixture.viewModel.runtime.state.media.loadedURL, fixture.original.media.loadedURL)
        XCTAssertEqual(fixture.viewModel.runtime.state.media.isPlaying, fixture.original.media.isPlaying)
        XCTAssertEqual(fixture.viewModel.runtime.state.media.currentTime, fixture.original.media.currentTime)
        XCTAssertEqual(fixture.viewModel.runtime.state.media.duration, fixture.original.media.duration)
    }

    func testPersistentLoadPreservesRuntimeMediaGeneration() {
        let fixture = makeFixture()

        fixture.viewModel.applyPersistentState(fixture.persistentState)

        XCTAssertEqual(fixture.viewModel.runtime.state.media.generation, fixture.original.media.generation)
    }

    func testPersistentLoadPreservesRuntimeBGMPlaybackState() {
        let fixture = makeFixture()

        fixture.viewModel.applyPersistentState(fixture.persistentState)

        XCTAssertEqual(fixture.viewModel.runtime.state.bgm.currentID, fixture.original.bgm.currentID)
        XCTAssertEqual(fixture.viewModel.runtime.state.bgm.isPlaying, fixture.original.bgm.isPlaying)
        XCTAssertEqual(fixture.viewModel.runtime.state.bgm.progress, fixture.original.bgm.progress)
        XCTAssertEqual(fixture.viewModel.runtime.state.bgm.currentTime, fixture.original.bgm.currentTime)
        XCTAssertEqual(fixture.viewModel.runtime.state.bgm.duration, fixture.original.bgm.duration)
    }

    func testPersistentLoadPreservesRuntimeBGMGeneration() {
        let fixture = makeFixture()

        fixture.viewModel.applyPersistentState(fixture.persistentState)

        XCTAssertEqual(fixture.viewModel.runtime.state.bgm.generation, fixture.original.bgm.generation)
    }

    func testPersistentLoadPreservesRuntimePanicState() {
        let fixture = makeFixture()

        fixture.viewModel.applyPersistentState(fixture.persistentState)

        XCTAssertEqual(fixture.viewModel.runtime.state.panic.isActive, fixture.original.panic.isActive)
        XCTAssertEqual(fixture.viewModel.runtime.state.panic.generation, fixture.original.panic.generation)
    }

    func testPersistentLoadPreservesRuntimePanicSnapshot() {
        let fixture = makeFixture()

        fixture.viewModel.applyPersistentState(fixture.persistentState)

        XCTAssertEqual(fixture.viewModel.runtime.state.panic.snapshot, fixture.original.panic.snapshot)
    }

    func testPersistentLoadPreservesRuntimePPTState() {
        let fixture = makeFixture()

        fixture.viewModel.applyPersistentState(fixture.persistentState)

        XCTAssertEqual(fixture.viewModel.runtime.state.ppt, fixture.original.ppt)
    }

    func testPersistentLoadPreservesRuntimeProjectionState() {
        let fixture = makeFixture()

        fixture.viewModel.applyPersistentState(fixture.persistentState)

        XCTAssertEqual(fixture.viewModel.runtime.state.projection, fixture.original.projection)
    }

    func testPersistentLoadPreservesRuntimeAutomationNoticeState() {
        let fixture = makeFixture()

        fixture.viewModel.applyPersistentState(fixture.persistentState)

        XCTAssertEqual(fixture.viewModel.runtime.state.automation, fixture.original.automation)
    }

    func testPersistentLoadPreservesRuntimeSupportState() {
        let fixture = makeFixture()

        fixture.viewModel.applyPersistentState(fixture.persistentState)

        XCTAssertEqual(fixture.viewModel.runtime.state.support, fixture.original.support)
    }

    func testPersistentLoadPreservesRuntimePresentationQueryState() {
        let fixture = makeFixture()

        fixture.viewModel.applyPersistentState(fixture.persistentState)

        XCTAssertEqual(fixture.viewModel.runtime.state.presentationQuery, fixture.original.presentationQuery)
    }

    func testPersistentLoadPreservesRuntimeProgramActivationState() {
        let fixture = makeFixture()

        fixture.viewModel.applyPersistentState(fixture.persistentState)

        XCTAssertEqual(fixture.viewModel.runtime.state.programActivation, fixture.original.programActivation)
    }

    func testPersistentLoadPreservesRuntimeAudioVolumesAndMutes() {
        let fixture = makeFixture()

        fixture.viewModel.applyPersistentState(fixture.persistentState)

        XCTAssertEqual(fixture.viewModel.runtime.state.audio.masterVolume, fixture.original.audio.masterVolume)
        XCTAssertEqual(fixture.viewModel.runtime.state.audio.mediaVolume, fixture.original.audio.mediaVolume)
        XCTAssertEqual(fixture.viewModel.runtime.state.audio.bgmVolume, fixture.original.audio.bgmVolume)
        XCTAssertEqual(fixture.viewModel.runtime.state.audio.isMasterMuted, fixture.original.audio.isMasterMuted)
        XCTAssertEqual(fixture.viewModel.runtime.state.audio.isMediaMuted, fixture.original.audio.isMediaMuted)
        XCTAssertEqual(fixture.viewModel.runtime.state.audio.isBGMMuted, fixture.original.audio.isBGMMuted)
    }

    func testPersistentLoadPreservesRuntimeAudioRoutingState() {
        let fixture = makeFixture()

        fixture.viewModel.applyPersistentState(fixture.persistentState)

        XCTAssertEqual(fixture.viewModel.runtime.state.audio.isBGMTakeoverActive, fixture.original.audio.isBGMTakeoverActive)
        XCTAssertEqual(fixture.viewModel.runtime.state.audio.routingContext, fixture.original.audio.routingContext)
        let expected = expectedAudioOutput(from: fixture.viewModel.runtime.state)
        XCTAssertEqual(fixture.viewModel.runtime.state.audio.effectiveMedia, expected.media, accuracy: 0.0001)
        XCTAssertEqual(fixture.viewModel.runtime.state.audio.effectiveBGM, expected.bgm, accuracy: 0.0001)
        XCTAssertNotEqual(fixture.viewModel.runtime.state.audio.effectiveMedia, fixture.original.audio.effectiveMedia)
        XCTAssertNotEqual(fixture.viewModel.runtime.state.audio.effectiveBGM, fixture.original.audio.effectiveBGM)
    }

    func testPersistentHydrationUpdatesOnlyPersistedAudioFields() {
        let fixture = makeFixture()

        fixture.viewModel.applyPersistentState(fixture.persistentState)

        XCTAssertEqual(fixture.viewModel.runtime.state.audio.strategy, fixture.persistentState.audioStrategy)
        XCTAssertEqual(fixture.viewModel.runtime.state.audio.isSpeakerMode, fixture.persistentState.isSpeakerMode)
        XCTAssertEqual(fixture.viewModel.runtime.state.audio.masterVolume, fixture.original.audio.masterVolume)
    }

    func testPersistentHydrationUpdatesOnlyBGMPlayMode() {
        let fixture = makeFixture()

        fixture.viewModel.applyPersistentState(fixture.persistentState)

        XCTAssertEqual(fixture.viewModel.runtime.state.bgm.playMode, fixture.persistentState.bgmPlayMode)
        XCTAssertEqual(fixture.viewModel.runtime.state.bgm.currentID, fixture.original.bgm.currentID)
    }

    func testPersistentHydrationUpdatesOnlyModeAndPreferences() {
        let fixture = makeFixture()

        fixture.viewModel.applyPersistentState(fixture.persistentState)

        XCTAssertEqual(fixture.viewModel.runtime.state.mode, fixture.persistentState.consoleMode)
        XCTAssertEqual(fixture.viewModel.runtime.state.preferences.themeOverride, fixture.persistentState.themeOverride)
        XCTAssertEqual(fixture.viewModel.runtime.state.preferences.activeWallpaperURL, fixture.persistentState.activeWallpaperURL)
        XCTAssertEqual(fixture.viewModel.runtime.state.projection, fixture.original.projection)
    }

    private func makeFixture() -> (viewModel: SwitcherViewModel, original: LiveRuntimeState, persistentState: SwitcherPersistentState) {
        let currentItem = ProgramItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000101")!,
            title: "Current",
            subtitle: "MEDIA",
            sourceURL: URL(fileURLWithPath: "/tmp/current.mp4")
        )
        let bgmItem = BGMItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000201")!,
            title: "Runtime BGM",
            url: URL(fileURLWithPath: "/tmp/runtime-bgm.mp3"),
            category: .warmUp
        )
        var state = LiveRuntimeState()
        state.program.items = [currentItem]
        state.program.currentID = currentItem.id
        state.program.currentSwitchedAt = Date(timeIntervalSince1970: 12_345)
        state.media.loadedURL = currentItem.sourceURL
        state.media.isPlaying = true
        state.media.currentTime = 42
        state.media.duration = 120
        state.media.generation = 7
        state.bgm.items = [bgmItem]
        state.bgm.currentID = bgmItem.id
        state.bgm.phase = .playing
        state.bgm.playMode = .loopAll
        state.bgm.progress = 0.35
        state.bgm.currentTime = 30
        state.bgm.duration = 90
        state.bgm.generation = 9
        state.audio.masterVolume = 0.8
        state.audio.mediaVolume = 0.7
        state.audio.bgmVolume = 0.6
        state.audio.strategy = .mixed
        state.audio.isMasterMuted = true
        state.audio.isMediaMuted = true
        state.audio.isBGMMuted = false
        state.audio.isSpeakerMode = false
        state.audio.isBGMTakeoverActive = true
        state.audio.routingContext = AudioRoutingContext(
            isCurrentProgramMediaSource: true,
            isMediaPlaying: true,
            isBGMPlaying: true,
            isPanicMode: true
        )
        state.audio.effectiveMedia = 0.3
        state.audio.effectiveBGM = 0.2
        state.panic.isActive = true
        state.panic.snapshot = PanicPlaybackSnapshot(
            currentProgramID: currentItem.id,
            wasMediaPlaying: true,
            currentBGMID: bgmItem.id,
            wasBGMPlaying: true
        )
        state.panic.generation = 4
        state.ppt.isRequested = true
        state.ppt.isEventTapActive = true
        state.ppt.lastFailureReason = "runtime failure"
        state.projection.isBroadcasting = true
        state.projection.hasExternalDisplay = true
        state.projection.lastDisplayLostAt = Date(timeIntervalSince1970: 9_999)
        state.projection.safetyNotice = "runtime projection"
        state.automation.notice = AutomationRuntimeNoticePolicy.make(
            action: "keynote.next-slide",
            createdAt: Date(timeIntervalSince1970: 10)
        )
        state.automation.suppressionUntilByAction = ["keynote.next-slide": Date(timeIntervalSince1970: 90)]
        state.support.events = [
            LiveSupportEvent(timestamp: Date(timeIntervalSince1970: 20), kind: .projectionStarted, detail: "source=runtime")
        ]
        state.support.coalescedCounts = ["projectionStarted": 1]
        state.presentationQuery.activeRequestID = UUID(uuidString: "00000000-0000-0000-0000-000000000301")!
        state.presentationQuery.latestCompletedRequestID = UUID(uuidString: "00000000-0000-0000-0000-000000000302")!
        state.presentationQuery.latestResult = PresentationQueryResult(openFilePaths: ["/tmp/runtime.key"], windowNames: ["Runtime.key"])
        state.presentationQuery.latestFailure = PresentationQueryFailure(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000303")!,
            action: "scan",
            sanitizedMessage: "runtime"
        )
        state.presentationQuery.consumedRequestIDs = [UUID(uuidString: "00000000-0000-0000-0000-000000000304")!]
        state.programActivation.activeRequestID = UUID(uuidString: "00000000-0000-0000-0000-000000000401")!
        state.programActivation.latestCompletedRequestID = UUID(uuidString: "00000000-0000-0000-0000-000000000402")!

        let runtime = LiveRuntimeStore(
            initialState: state,
            effectRunner: .recording(),
            environment: .productionPanicOwning(now: Date(timeIntervalSince1970: 1))
        )
        let viewModel = SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            runtime: runtime
        )
        viewModel.syncRuntimeStateFromFacade(clearActionLog: true, dispatchAudioInputsChanged: false)

        let persistentState = SwitcherPersistentState(
            audioStrategy: .followSource,
            isSpeakerMode: true,
            bgmPlayMode: .loopOne,
            programItems: [currentItem],
            activeWallpaperURL: URL(fileURLWithPath: "/tmp/persistent-wallpaper.png"),
            cornerLogoURL: URL(fileURLWithPath: "/tmp/persistent-logo.png"),
            cornerLogoPosition: .bottomRight,
            autoPlayNextVideoOnEnd: true,
            isAgendaTimeReminderEnabled: true,
            showAgendaTimeline: true,
            consoleMode: .live,
            themeOverride: .light
        )
        return (viewModel, state, persistentState)
    }

    private func expectedAudioOutput(from state: LiveRuntimeState) -> AudioRoutingOutput {
        let context = state.audio.routingContext
        return AudioRoutingEngine.output(for: AudioRoutingInput(
            masterVolume: state.audio.masterVolume,
            mediaVolume: state.audio.mediaVolume,
            bgmVolume: state.audio.bgmVolume,
            audioStrategy: state.audio.strategy,
            isCurrentProgramMediaSource: context.isCurrentProgramMediaSource,
            isMediaPlaying: context.isMediaPlaying,
            isBGMAudioTakeoverActive: state.audio.isBGMTakeoverActive,
            isSpeakerMode: state.audio.isSpeakerMode,
            isPanicMode: context.isPanicMode,
            isMasterMuted: state.audio.isMasterMuted,
            isMediaMuted: state.audio.isMediaMuted,
            isBGMMuted: state.audio.isBGMMuted,
            speakerModeDuckedRatio: AudioRoutingDefaults.speakerModeDuckedRatio
        ))
    }
}
