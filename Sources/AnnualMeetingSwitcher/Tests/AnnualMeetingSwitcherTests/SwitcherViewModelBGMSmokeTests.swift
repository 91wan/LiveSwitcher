import AppKit
import SwiftUI
import XCTest
@testable import LiveSwitcher

@MainActor
final class SwitcherViewModelBGMSmokeTests: SwitcherViewModelSmokeTestCase {
    func testLoopModeCyclesThroughExpectedSequence() {
        let viewModel = makeViewModel()

        XCTAssertEqual(viewModel.bgmPlayMode, .loopAll)

        viewModel.toggleLoopMode()
        XCTAssertEqual(viewModel.bgmPlayMode, .loopOne)

        viewModel.toggleLoopMode()
        XCTAssertEqual(viewModel.bgmPlayMode, .sequential)

        viewModel.toggleLoopMode()
        XCTAssertEqual(viewModel.bgmPlayMode, .loopAll)
    }


    func testBGMVolumeAdjustmentsClampBetweenZeroAndOne() {
        let viewModel = makeViewModel()

        viewModel.bgmVolume = 0.02
        viewModel.bgmVolumeDown()
        XCTAssertEqual(viewModel.bgmVolume, 0.0, accuracy: 0.0001)

        viewModel.bgmVolume = 0.98
        viewModel.bgmVolumeUp()
        XCTAssertEqual(viewModel.bgmVolume, 1.0, accuracy: 0.0001)
    }


    func testMoveBGMItemsWithinCategoryDoesNotReorderOtherCategories() {
        let viewModel = makeViewModel()
        let warmA = BGMItem(title: "Warm A", url: URL(fileURLWithPath: "/tmp/warm-a.mp3"), category: .warmUp)
        let ambient = BGMItem(title: "Ambient", url: URL(fileURLWithPath: "/tmp/ambient.mp3"), category: .ambient)
        let warmB = BGMItem(title: "Warm B", url: URL(fileURLWithPath: "/tmp/warm-b.mp3"), category: .warmUp)
        let exit = BGMItem(title: "Exit", url: URL(fileURLWithPath: "/tmp/exit.mp3"), category: .exit)
        let warmC = BGMItem(title: "Warm C", url: URL(fileURLWithPath: "/tmp/warm-c.mp3"), category: .warmUp)
        viewModel.bgmItems = [warmA, ambient, warmB, exit, warmC]

        viewModel.moveBGMItems(in: .warmUp, from: IndexSet(integer: 2), to: 0)

        XCTAssertEqual(viewModel.bgmItems, [warmC, ambient, warmA, exit, warmB])
    }


    func testMixedStrategyKeepsMediaAndBGMChannelsActive() {
        let runtime = LiveRuntimeStore(
            effectRunner: .recording(),
            environment: .productionAudioOwned(liveAudioFadeDuration: 0)
        )
        let viewModel = SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            runtime: runtime
        )
        viewModel.liveAudioFadeDuration = 0

        viewModel.masterVolume = 0.8
        viewModel.mediaVolume = 0.5
        viewModel.bgmVolume = 0.25
        viewModel.audioStrategy = .mixed
        viewModel.currentBGMItem = BGMItem(title: "BGM", url: URL(fileURLWithPath: "/tmp/bgm.mp3"), category: .warmUp)
        viewModel.isBGMPlaying = true
        viewModel.applyCurrentProgramProjectionFromRuntime(
            ProgramItem(
                title: "片头",
                subtitle: "MP4",
                sourceURL: URL(fileURLWithPath: "/tmp/opening.mp4")
            ),
            switchedAt: Date()
        )
        viewModel.avCoordinator.isPlaying = true
        viewModel.applyCurrentRuntimeAudioRouting(reason: .operatorFaderChanged)

        XCTAssertEqual(viewModel.effectiveMediaOutputVolume(), 0.4, accuracy: 0.0001)
        XCTAssertEqual(viewModel.effectiveBGMOutputVolume(), 0.2, accuracy: 0.0001)
        XCTAssertEqual(viewModel.avCoordinator.volume, 0.4, accuracy: 0.0001)
        XCTAssertEqual(viewModel.bgmFallbackPlayer.volume, 0.2, accuracy: 0.0001)
    }


    func testFollowProgramFallsBackToBGMWhenMediaIsNotPlaying() {
        let viewModel = makeViewModel()

        viewModel.masterVolume = 0.8
        viewModel.mediaVolume = 0.5
        viewModel.bgmVolume = 0.25
        viewModel.audioStrategy = .followProgram
        let item = ProgramItem(
            title: "片头",
            subtitle: "MP4",
            sourceURL: URL(fileURLWithPath: "/tmp/opening.mp4")
        )
        viewModel.applyCurrentProgramProjectionFromRuntime(item, switchedAt: Date())

        viewModel.avCoordinator.isPlaying = false
        mirrorRuntimeMediaState(viewModel, item: item, isPlaying: false)
        viewModel.syncRuntimeAudioInputsFromFacade(reason: nil)
        XCTAssertEqual(viewModel.effectiveMediaOutputVolume(), 0, accuracy: 0.0001)
        XCTAssertEqual(viewModel.effectiveBGMOutputVolume(), 0.2, accuracy: 0.0001)

        viewModel.avCoordinator.isPlaying = true
        mirrorRuntimeMediaState(viewModel, item: item, isPlaying: true)
        viewModel.syncRuntimeAudioInputsFromFacade(reason: nil)
        XCTAssertEqual(viewModel.effectiveMediaOutputVolume(), 0.4, accuracy: 0.0001)
        XCTAssertEqual(viewModel.effectiveBGMOutputVolume(), 0, accuracy: 0.0001)
    }


    func testFollowSourceAndSpeakerModeDoNotResurrectMutedBGM() {
        let viewModel = makeViewModel()
        viewModel.liveAudioFadeDuration = 0

        viewModel.masterVolume = 0.8
        viewModel.mediaVolume = 0.5
        viewModel.bgmVolume = 0.9
        viewModel.audioStrategy = .followSource
        viewModel.applyCurrentProgramProjectionFromRuntime(
            ProgramItem(
                title: "网页",
                subtitle: "HTML",
                sourceURL: URL(fileURLWithPath: "/tmp/lobby.html")
            ),
            switchedAt: Date()
        )
        viewModel.toggleSpeakerMode()

        XCTAssertEqual(viewModel.effectiveMediaOutputVolume(), 0, accuracy: 0.0001)
        XCTAssertEqual(viewModel.effectiveBGMOutputVolume(), 0, accuracy: 0.0001)
        XCTAssertEqual(viewModel.bgmFallbackPlayer.volume, 0, accuracy: 0.0001)
    }


    func testSpeakerModeCompressesBGMWithoutChangingAudioStrategy() {
        let viewModel = makeViewModel()
        viewModel.masterVolume = 0.8
        viewModel.bgmVolume = 0.5
        viewModel.audioStrategy = .mixed

        XCTAssertEqual(viewModel.effectiveBGMOutputVolume(), 0.4, accuracy: 0.0001)

        viewModel.toggleSpeakerMode()

        XCTAssertTrue(viewModel.isSpeakerMode)
        XCTAssertEqual(viewModel.audioStrategy, .mixed)
        XCTAssertEqual(viewModel.effectiveBGMOutputVolume(), 0.056, accuracy: 0.0001)
    }


    func testSpeakerModeDucksMediaAudioWithoutLiftingLowerUserFader() throws {
        let viewModel = makeViewModel()
        viewModel.liveAudioFadeDuration = 0
        viewModel.masterVolume = 0.8
        viewModel.mediaVolume = 0.5
        viewModel.audioStrategy = .mixed
        let videoURL = try makeTempFileURL(ext: "mp4")
        defer { try? FileManager.default.removeItem(at: videoURL) }

        viewModel.switchToProgram(ProgramItem(title: "开场视频", subtitle: "MP4", sourceURL: videoURL))
        XCTAssertEqual(viewModel.effectiveMediaOutputVolume(), 0.4, accuracy: 0.0001)

        viewModel.toggleSpeakerMode()

        XCTAssertTrue(viewModel.isSpeakerMode)
        XCTAssertEqual(viewModel.audioStrategy, .mixed)
        XCTAssertEqual(viewModel.effectiveMediaOutputVolume(), 0.056, accuracy: 0.0001)
        XCTAssertEqual(viewModel.avCoordinator.volume, 0.056, accuracy: 0.0001)

        viewModel.mediaVolume = 0.02
        XCTAssertEqual(viewModel.effectiveMediaOutputVolume(), 0.016, accuracy: 0.0001)
    }


    func testLiveSpeakerModeToggleDucksMediaAndBGMThroughRouting() throws {
        let viewModel = makeViewModel()
        viewModel.liveAudioFadeDuration = 0
        viewModel.masterVolume = 0.8
        viewModel.mediaVolume = 0.5
        viewModel.bgmVolume = 0.5
        viewModel.audioStrategy = .mixed
        let videoURL = try makeTempFileURL(ext: "mp4")
        defer { try? FileManager.default.removeItem(at: videoURL) }

        viewModel.toggleBGM(BGMItem(title: "BGM", url: URL(fileURLWithPath: "/tmp/bgm.mp3"), category: .warmUp))
        viewModel.switchToProgram(ProgramItem(title: "开场视频", subtitle: "MP4", sourceURL: videoURL))
        viewModel.toggleSpeakerMode()

        XCTAssertTrue(viewModel.isSpeakerMode)
        XCTAssertEqual(viewModel.effectiveMediaOutputVolume(), 0.056, accuracy: 0.0001)
        XCTAssertEqual(viewModel.effectiveBGMOutputVolume(), 0.056, accuracy: 0.0001)
        XCTAssertEqual(viewModel.avCoordinator.volume, 0.056, accuracy: 0.0001)
        XCTAssertEqual(viewModel.bgmFallbackPlayer.volume, 0.056, accuracy: 0.0001)
    }


    func testBGMPlaybackDoesNotImplicitlyTakeOverMediaAudioWithoutChangingStrategy() throws {
        let viewModel = makeViewModel()
        viewModel.liveAudioFadeDuration = 0
        viewModel.masterVolume = 0.8
        viewModel.mediaVolume = 0.5
        viewModel.bgmVolume = 0.25
        viewModel.audioStrategy = .mixed

        let videoURL = try makeTempFileURL(ext: "mp4")
        let bgmURL = try makeTempFileURL(ext: "mp3")
        defer {
            try? FileManager.default.removeItem(at: videoURL)
            try? FileManager.default.removeItem(at: bgmURL)
        }

        let videoItem = ProgramItem(title: "开场视频", subtitle: "MP4", sourceURL: videoURL)
        let bgmItem = BGMItem(title: "暖场音乐", url: bgmURL, category: .warmUp)
        viewModel.switchToProgram(videoItem)
        XCTAssertEqual(viewModel.audioStrategy, .mixed)
        XCTAssertEqual(viewModel.effectiveMediaOutputVolume(), 0.4, accuracy: 0.0001)

        viewModel.toggleBGM(bgmItem)

        XCTAssertTrue(viewModel.isBGMPlaying)
        XCTAssertFalse(viewModel.isBGMAudioTakeoverActive)
        XCTAssertEqual(viewModel.audioStrategy, .mixed)
        XCTAssertEqual(viewModel.effectiveMediaOutputVolume(), 0.4, accuracy: 0.0001)
        XCTAssertEqual(viewModel.effectiveBGMOutputVolume(), 0.2, accuracy: 0.0001)
        XCTAssertEqual(viewModel.avCoordinator.volume, 0.4, accuracy: 0.0001)
        XCTAssertEqual(viewModel.bgmFallbackPlayer.volume, 0.2, accuracy: 0.0001)
    }


    func testStoppingBGMRestoresMediaAudioUsingExistingStrategy() throws {
        let viewModel = makeViewModel()
        viewModel.liveAudioFadeDuration = 0
        viewModel.masterVolume = 0.8
        viewModel.mediaVolume = 0.5
        viewModel.bgmVolume = 0.25
        viewModel.audioStrategy = .mixed

        let videoURL = try makeTempFileURL(ext: "mp4")
        let bgmURL = try makeTempFileURL(ext: "mp3")
        defer {
            try? FileManager.default.removeItem(at: videoURL)
            try? FileManager.default.removeItem(at: bgmURL)
        }

        let videoItem = ProgramItem(title: "开场视频", subtitle: "MP4", sourceURL: videoURL)
        let bgmItem = BGMItem(title: "暖场音乐", url: bgmURL, category: .warmUp)
        viewModel.switchToProgram(videoItem)
        viewModel.toggleBGM(bgmItem)

        viewModel.toggleBGM(bgmItem)

        XCTAssertFalse(viewModel.isBGMPlaying)
        XCTAssertFalse(viewModel.isBGMAudioTakeoverActive)
        XCTAssertEqual(viewModel.audioStrategy, .mixed)
        XCTAssertEqual(viewModel.effectiveMediaOutputVolume(), 0.4, accuracy: 0.0001)
        XCTAssertEqual(viewModel.avCoordinator.volume, 0.4, accuracy: 0.0001)
        XCTAssertEqual(viewModel.bgmFallbackPlayer.volume, 0, accuracy: 0.0001)
    }


    func testBGMPlaybackDoesNotOverrideFollowSourceStrategy() throws {
        let viewModel = makeViewModel()
        viewModel.liveAudioFadeDuration = 0
        viewModel.masterVolume = 0.8
        viewModel.mediaVolume = 0.5
        viewModel.bgmVolume = 0.25
        viewModel.audioStrategy = .followSource

        let videoURL = try makeTempFileURL(ext: "mp4")
        let bgmURL = try makeTempFileURL(ext: "mp3")
        defer {
            try? FileManager.default.removeItem(at: videoURL)
            try? FileManager.default.removeItem(at: bgmURL)
        }

        let videoItem = ProgramItem(title: "开场视频", subtitle: "MP4", sourceURL: videoURL)
        let bgmItem = BGMItem(title: "暖场音乐", url: bgmURL, category: .warmUp)
        viewModel.switchToProgram(videoItem)
        XCTAssertEqual(viewModel.effectiveMediaOutputVolume(), 0.4, accuracy: 0.0001)
        XCTAssertEqual(viewModel.effectiveBGMOutputVolume(), 0, accuracy: 0.0001)

        viewModel.toggleBGM(bgmItem)

        XCTAssertFalse(viewModel.isBGMAudioTakeoverActive)
        XCTAssertEqual(viewModel.audioStrategy, .followSource)
        XCTAssertEqual(viewModel.effectiveMediaOutputVolume(), 0.4, accuracy: 0.0001)
        XCTAssertEqual(viewModel.effectiveBGMOutputVolume(), 0, accuracy: 0.0001)
    }


    func testChangingAudioStrategyWhileBGMIsPlayingUpdatesEffectiveVolumesAndPlayers() throws {
        let viewModel = makeViewModel()
        viewModel.liveAudioFadeDuration = 0
        viewModel.masterVolume = 0.8
        viewModel.mediaVolume = 0.5
        viewModel.bgmVolume = 0.25
        viewModel.audioStrategy = .mixed

        let videoURL = try makeTempFileURL(ext: "mp4")
        let bgmURL = try makeTempFileURL(ext: "mp3")
        defer {
            try? FileManager.default.removeItem(at: videoURL)
            try? FileManager.default.removeItem(at: bgmURL)
        }

        viewModel.switchToProgram(ProgramItem(title: "开场视频", subtitle: "MP4", sourceURL: videoURL))
        viewModel.toggleBGM(BGMItem(title: "暖场音乐", url: bgmURL, category: .warmUp))

        XCTAssertEqual(viewModel.avCoordinator.volume, 0.4, accuracy: 0.0001)
        XCTAssertEqual(viewModel.bgmFallbackPlayer.volume, 0.2, accuracy: 0.0001)

        viewModel.audioStrategy = .followProgram
        XCTAssertEqual(viewModel.effectiveMediaOutputVolume(), 0.4, accuracy: 0.0001)
        XCTAssertEqual(viewModel.effectiveBGMOutputVolume(), 0, accuracy: 0.0001)
        XCTAssertEqual(viewModel.avCoordinator.volume, 0.4, accuracy: 0.0001)
        XCTAssertEqual(viewModel.bgmFallbackPlayer.volume, 0, accuracy: 0.0001)

        viewModel.audioStrategy = .bgmOnly
        XCTAssertEqual(viewModel.effectiveMediaOutputVolume(), 0, accuracy: 0.0001)
        XCTAssertEqual(viewModel.effectiveBGMOutputVolume(), 0.2, accuracy: 0.0001)
        XCTAssertEqual(viewModel.avCoordinator.volume, 0, accuracy: 0.0001)
        XCTAssertEqual(viewModel.bgmFallbackPlayer.volume, 0.2, accuracy: 0.0001)
    }


    func testSwitchingBGMItemsCancelsStaleFadeTargets() throws {
        let viewModel = makeViewModel()
        viewModel.liveAudioFadeDuration = 0
        viewModel.masterVolume = 0.8
        viewModel.mediaVolume = 0.5
        viewModel.bgmVolume = 0.25
        viewModel.audioStrategy = .mixed

        let videoURL = try makeTempFileURL(ext: "mp4")
        let firstBGMURL = try makeTempFileURL(ext: "mp3")
        let secondBGMURL = try makeTempFileURL(ext: "mp3")
        defer {
            try? FileManager.default.removeItem(at: videoURL)
            try? FileManager.default.removeItem(at: firstBGMURL)
            try? FileManager.default.removeItem(at: secondBGMURL)
        }

        let videoItem = ProgramItem(title: "开场视频", subtitle: "MP4", sourceURL: videoURL)
        let firstBGM = BGMItem(title: "暖场音乐 A", url: firstBGMURL, category: .warmUp)
        let secondBGM = BGMItem(title: "暖场音乐 B", url: secondBGMURL, category: .warmUp)
        viewModel.switchToProgram(videoItem)

        viewModel.toggleBGM(firstBGM)
        viewModel.toggleBGM(secondBGM)

        XCTAssertEqual(viewModel.currentBGMItem, secondBGM)
        XCTAssertTrue(viewModel.isBGMPlaying)
        XCTAssertFalse(viewModel.isBGMAudioTakeoverActive)
        XCTAssertEqual(viewModel.effectiveMediaOutputVolume(), 0.4, accuracy: 0.0001)
        XCTAssertEqual(viewModel.avCoordinator.volume, 0.4, accuracy: 0.0001)
        XCTAssertEqual(viewModel.bgmFallbackPlayer.volume, 0.2, accuracy: 0.0001)
    }


    func testBGMNextPreviousAreNoopsWhenOnlyOneTrackInCurrentCategory() throws {
        let viewModel = makeViewModel()
        viewModel.liveAudioFadeDuration = 0
        let bgmURL = try makeTempFileURL(ext: "mp3")
        defer { try? FileManager.default.removeItem(at: bgmURL) }
        let item = BGMItem(title: "Only Track", url: bgmURL, category: .warmUp)
        viewModel.bgmItems = [item]
        viewModel.toggleBGM(item)

        viewModel.playNextBGM()
        XCTAssertTrue(viewModel.isBGMPlaying)
        XCTAssertEqual(viewModel.currentBGMItem?.id, item.id)

        viewModel.playPreviousBGM()
        XCTAssertTrue(viewModel.isBGMPlaying)
        XCTAssertEqual(viewModel.currentBGMItem?.id, item.id)
    }


    func testFallbackBGMSeekUpdatesCurrentTimeAndKeepsDuration() {
        let viewModel = makeViewModel()
        let item = BGMItem(title: "Fallback", url: URL(fileURLWithPath: "/tmp/fallback.mp3"))
        viewModel.bgmItems = [item]
        viewModel.currentBGMItem = item
        viewModel.syncRuntimeStateFromFacade(clearActionLog: false)
        var state = viewModel.runtime.state
        state.bgm.currentID = item.id
        state.bgm.duration = 200
        viewModel.runtime.replaceStateForFacadeSync(state)
        viewModel.bgmDuration = 200

        viewModel.seekBGM(toProgress: 0.25)

        XCTAssertEqual(viewModel.bgmProgress, 0.25, accuracy: 0.0001)
        XCTAssertEqual(viewModel.bgmCurrentTime, 50, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(viewModel.bgmDuration), 200, accuracy: 0.0001)
    }


    func testFallbackBGMSeekWithoutKnownDurationDoesNotMoveDisplayedProgress() {
        let viewModel = makeViewModel()
        viewModel.bgmDuration = nil
        viewModel.bgmCurrentTime = 18
        viewModel.bgmProgress = 0.4

        viewModel.seekBGM(toProgress: 0.8)

        XCTAssertEqual(viewModel.bgmProgress, 0.4, accuracy: 0.0001)
        XCTAssertEqual(viewModel.bgmCurrentTime, 18, accuracy: 0.0001)
        XCTAssertNil(viewModel.bgmDuration)
    }


    func testBGMDurationRejectsNonFiniteValues() {
        let viewModel = makeViewModel()

        viewModel.bgmDuration = .infinity

        XCTAssertNil(viewModel.bgmDuration)
    }


    func testFallbackBGMSeekToBeginningKeepsKnownDuration() {
        let viewModel = makeViewModel()
        let item = BGMItem(title: "Fallback", url: URL(fileURLWithPath: "/tmp/fallback.mp3"))
        viewModel.bgmItems = [item]
        viewModel.currentBGMItem = item
        viewModel.syncRuntimeStateFromFacade(clearActionLog: false)
        var state = viewModel.runtime.state
        state.bgm.currentID = item.id
        state.bgm.phase = .selected
        state.bgm.duration = 90
        state.bgm.progress = 0.5
        state.bgm.currentTime = 45
        viewModel.runtime.replaceStateForFacadeSync(state)
        viewModel.bgmDuration = 90
        viewModel.bgmCurrentTime = 45
        viewModel.bgmProgress = 0.5

        viewModel.seekBGMToBeginning()

        XCTAssertEqual(viewModel.bgmProgress, 0, accuracy: 0.0001)
        XCTAssertEqual(viewModel.bgmCurrentTime, 0, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(viewModel.bgmDuration), 90, accuracy: 0.0001)
    }


    func testExplicitBGMTakeoverStillMutesMediaWhenOperatorEnablesIt() throws {
        let viewModel = makeViewModel()
        viewModel.liveAudioFadeDuration = 0
        viewModel.masterVolume = 0.8
        viewModel.mediaVolume = 0.5
        viewModel.bgmVolume = 0.25
        viewModel.audioStrategy = .mixed
        let videoURL = try makeTempFileURL(ext: "mp4")
        defer { try? FileManager.default.removeItem(at: videoURL) }

        viewModel.switchToProgram(ProgramItem(title: "Opening", subtitle: "MP4", sourceURL: videoURL))
        viewModel.toggleBGM(BGMItem(title: "BGM", url: URL(fileURLWithPath: "/tmp/bgm.mp3"), category: .warmUp))
        viewModel.isBGMAudioTakeoverActive = true
        viewModel.applyAudioRouting()

        XCTAssertEqual(viewModel.effectiveMediaOutputVolume(), 0, accuracy: 0.0001)
        XCTAssertEqual(viewModel.effectiveBGMOutputVolume(), 0.2, accuracy: 0.0001)
        XCTAssertEqual(viewModel.avCoordinator.volume, 0, accuracy: 0.0001)
        XCTAssertEqual(viewModel.bgmFallbackPlayer.volume, 0.2, accuracy: 0.0001)
    }

}
