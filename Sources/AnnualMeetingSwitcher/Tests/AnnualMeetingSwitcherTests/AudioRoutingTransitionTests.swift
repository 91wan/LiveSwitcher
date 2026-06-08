import XCTest
import AppKit
@testable import LiveSwitcher

@MainActor
final class AudioRoutingTransitionTests: XCTestCase {
    private func makeViewModel() -> SwitcherViewModel {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)
        viewModel.externalScreenProvider = { NSScreen.main ?? NSScreen.screens.first }
        viewModel.actionHandlers.keynotePresentation = { _ in }
        viewModel.actionHandlers.pptxOpen = { _ in }
        viewModel.actionHandlers.activeDeckPresentation = {}
        viewModel.actionHandlers.invalidDeck = { _ in }
        viewModel.actionHandlers.deckStop = {}
        return viewModel
    }

    private func makeTempURL(ext: String) throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(ext)
        FileManager.default.createFile(atPath: url.path, contents: Data("stub".utf8))
        return url
    }

    func testProgramChangeFromBGMToMediaUsesFadedRouting() throws {
        let viewModel = makeViewModel()
        viewModel.liveAudioFadeDuration = 1.25
        let videoURL = try makeTempURL(ext: "mp4")
        defer { try? FileManager.default.removeItem(at: videoURL) }

        viewModel.switchToProgram(ProgramItem(title: "Opening", subtitle: "MP4", sourceURL: videoURL))

        XCTAssertEqual(viewModel.lastAudioRoutingTransition?.reason, .programChanged)
        XCTAssertEqual(viewModel.lastAudioRoutingTransition?.mediaFadeDuration, 1.25)
        XCTAssertEqual(viewModel.lastAudioRoutingTransition?.bgmFadeDuration, 1.25)
    }

    func testFirstMediaProgramWhileBGMPlayingStartsMutedBeforeFadeIn() throws {
        let viewModel = makeViewModel()
        viewModel.masterVolume = 0.8
        viewModel.mediaVolume = 0.5
        viewModel.audioStrategy = .mixed
        viewModel.liveAudioFadeDuration = 1.25
        viewModel.avCoordinator.volume = 0.4
        viewModel.isBGMPlaying = true
        let videoURL = try makeTempURL(ext: "mp4")
        defer { try? FileManager.default.removeItem(at: videoURL) }
        let item = ProgramItem(title: "Opening", subtitle: "MP4", sourceURL: videoURL)

        viewModel.switchToProgram(item)

        XCTAssertEqual(viewModel.currentProgramItem, item)
        XCTAssertEqual(viewModel.avCoordinator.currentURL, videoURL)
        XCTAssertEqual(viewModel.avCoordinator.volume, 0, accuracy: 0.0001)
        XCTAssertEqual(viewModel.lastAudioRoutingTransition?.reason, .programChanged)
        XCTAssertEqual(viewModel.lastAudioRoutingTransition?.mediaFadeDuration, 1.25)
    }

    func testSwitchingBetweenMediaItemsStartsNewItemMutedBeforeFadeIn() throws {
        let viewModel = makeViewModel()
        viewModel.masterVolume = 0.8
        viewModel.mediaVolume = 0.5
        viewModel.audioStrategy = .mixed
        viewModel.liveAudioFadeDuration = 0
        let firstURL = try makeTempURL(ext: "mp4")
        let secondURL = try makeTempURL(ext: "mp4")
        defer {
            try? FileManager.default.removeItem(at: firstURL)
            try? FileManager.default.removeItem(at: secondURL)
        }
        let first = ProgramItem(title: "Opening", subtitle: "MP4", sourceURL: firstURL)
        let second = ProgramItem(title: "Awards", subtitle: "MP4", sourceURL: secondURL)

        viewModel.switchToProgram(first)
        XCTAssertEqual(viewModel.avCoordinator.volume, 0.4, accuracy: 0.0001)

        viewModel.liveAudioFadeDuration = 1.25
        viewModel.resetLastAudioRoutingTransitionForTesting()
        viewModel.switchToProgram(second)

        XCTAssertEqual(viewModel.currentProgramItem, second)
        XCTAssertEqual(viewModel.avCoordinator.currentURL, secondURL)
        XCTAssertEqual(viewModel.avCoordinator.volume, 0, accuracy: 0.0001)
        XCTAssertEqual(viewModel.lastAudioRoutingTransition?.reason, .programChanged)
        XCTAssertEqual(viewModel.lastAudioRoutingTransition?.mediaFadeDuration, 1.25)
    }

    func testSwitchingFromNonMediaBackToMediaStartsNewItemMutedBeforeFadeIn() throws {
        let viewModel = makeViewModel()
        viewModel.masterVolume = 0.8
        viewModel.mediaVolume = 0.5
        viewModel.audioStrategy = .mixed
        viewModel.liveAudioFadeDuration = 0
        let firstURL = try makeTempURL(ext: "mp4")
        let htmlURL = try makeTempURL(ext: "html")
        let secondURL = try makeTempURL(ext: "mp4")
        defer {
            try? FileManager.default.removeItem(at: firstURL)
            try? FileManager.default.removeItem(at: htmlURL)
            try? FileManager.default.removeItem(at: secondURL)
        }
        let first = ProgramItem(title: "Opening", subtitle: "MP4", sourceURL: firstURL)
        let html = ProgramItem(title: "Agenda", subtitle: "HTML", sourceURL: htmlURL)
        let second = ProgramItem(title: "Awards", subtitle: "MP4", sourceURL: secondURL)

        viewModel.switchToProgram(first)
        XCTAssertEqual(viewModel.avCoordinator.volume, 0.4, accuracy: 0.0001)

        viewModel.liveAudioFadeDuration = 1.25
        viewModel.switchToProgram(html)
        viewModel.avCoordinator.volume = 0.4
        viewModel.resetLastAudioRoutingTransitionForTesting()

        viewModel.switchToProgram(second)

        XCTAssertEqual(viewModel.currentProgramItem, second)
        XCTAssertEqual(viewModel.avCoordinator.currentURL, secondURL)
        XCTAssertEqual(viewModel.avCoordinator.volume, 0, accuracy: 0.0001)
        XCTAssertEqual(viewModel.lastAudioRoutingTransition?.reason, .programChanged)
        XCTAssertEqual(viewModel.lastAudioRoutingTransition?.mediaFadeDuration, 1.25)
    }

    func testSwitchingFromClearedCurrentWithLoadedMediaStartsNewItemMutedBeforeFadeIn() throws {
        let viewModel = makeViewModel()
        viewModel.masterVolume = 0.8
        viewModel.mediaVolume = 0.5
        viewModel.audioStrategy = .mixed
        viewModel.liveAudioFadeDuration = 0
        let firstURL = try makeTempURL(ext: "mp4")
        let secondURL = try makeTempURL(ext: "mp4")
        defer {
            try? FileManager.default.removeItem(at: firstURL)
            try? FileManager.default.removeItem(at: secondURL)
        }
        let first = ProgramItem(title: "Opening", subtitle: "MP4", sourceURL: firstURL)
        let second = ProgramItem(title: "Encore", subtitle: "MP4", sourceURL: secondURL)

        viewModel.switchToProgram(first)
        XCTAssertTrue(viewModel.avCoordinator.hasLoadedMedia)
        XCTAssertEqual(viewModel.avCoordinator.volume, 0.4, accuracy: 0.0001)

        viewModel.liveAudioFadeDuration = 1.25
        viewModel.applyCurrentProgramProjectionFromRuntime(nil, switchedAt: nil)
        viewModel.avCoordinator.volume = 0.4
        viewModel.resetLastAudioRoutingTransitionForTesting()

        viewModel.switchToProgram(second)

        XCTAssertEqual(viewModel.currentProgramItem, second)
        XCTAssertEqual(viewModel.avCoordinator.currentURL, secondURL)
        XCTAssertEqual(viewModel.avCoordinator.volume, 0, accuracy: 0.0001)
        XCTAssertEqual(viewModel.lastAudioRoutingTransition?.reason, .programChanged)
        XCTAssertEqual(viewModel.lastAudioRoutingTransition?.mediaFadeDuration, 1.25)
    }

    func testSwitchingFromStoppedClearedCurrentStartsNewItemMutedBeforeFadeIn() throws {
        let viewModel = makeViewModel()
        viewModel.masterVolume = 0.8
        viewModel.mediaVolume = 0.5
        viewModel.audioStrategy = .mixed
        viewModel.liveAudioFadeDuration = 0
        let firstURL = try makeTempURL(ext: "mp4")
        let secondURL = try makeTempURL(ext: "mp4")
        defer {
            try? FileManager.default.removeItem(at: firstURL)
            try? FileManager.default.removeItem(at: secondURL)
        }
        let first = ProgramItem(title: "Opening", subtitle: "MP4", sourceURL: firstURL)
        let second = ProgramItem(title: "Encore", subtitle: "MP4", sourceURL: secondURL)

        viewModel.addProgramItem(first)
        viewModel.switchToProgram(first)
        XCTAssertEqual(viewModel.avCoordinator.volume, 0.4, accuracy: 0.0001)

        viewModel.liveAudioFadeDuration = 1.25
        viewModel.removeProgramItem(withID: first.id)
        viewModel.avCoordinator.volume = 0.4
        viewModel.resetLastAudioRoutingTransitionForTesting()

        viewModel.switchToProgram(second)

        XCTAssertEqual(viewModel.currentProgramItem, second)
        XCTAssertEqual(viewModel.avCoordinator.currentURL, secondURL)
        XCTAssertEqual(viewModel.avCoordinator.volume, 0, accuracy: 0.0001)
        XCTAssertEqual(viewModel.lastAudioRoutingTransition?.reason, .programChanged)
        XCTAssertEqual(viewModel.lastAudioRoutingTransition?.mediaFadeDuration, 1.25)
    }

    func testMediaPlaybackPauseAndResumeUseFadedRouting() throws {
        let viewModel = makeViewModel()
        viewModel.liveAudioFadeDuration = 1.0
        let videoURL = try makeTempURL(ext: "mp4")
        defer { try? FileManager.default.removeItem(at: videoURL) }

        viewModel.switchToProgram(ProgramItem(title: "Opening", subtitle: "MP4", sourceURL: videoURL))
        viewModel.resetLastAudioRoutingTransitionForTesting()

        viewModel.toggleMainVideoPlayback()
        XCTAssertEqual(viewModel.lastAudioRoutingTransition?.reason, .mediaPlaybackChanged)
        XCTAssertEqual(viewModel.lastAudioRoutingTransition?.mediaFadeDuration, 1.0)
        XCTAssertEqual(viewModel.lastAudioRoutingTransition?.bgmFadeDuration, 1.0)

        viewModel.resetLastAudioRoutingTransitionForTesting()
        viewModel.toggleMainVideoPlayback()
        XCTAssertEqual(viewModel.lastAudioRoutingTransition?.reason, .mediaPlaybackChanged)
    }

    func testAudioStrategyChangeUsesFadedRouting() throws {
        let viewModel = makeViewModel()
        viewModel.liveAudioFadeDuration = 1.5

        viewModel.audioStrategy = .followProgram

        XCTAssertEqual(viewModel.lastAudioRoutingTransition?.reason, .strategyChanged)
        XCTAssertEqual(viewModel.lastAudioRoutingTransition?.mediaFadeDuration, 1.5)
        XCTAssertEqual(viewModel.lastAudioRoutingTransition?.bgmFadeDuration, 1.5)
    }

    func testSameAudioStrategyDoesNotCreateNewTransition() {
        let viewModel = makeViewModel()
        viewModel.audioStrategy = .followProgram
        viewModel.resetLastAudioRoutingTransitionForTesting()

        viewModel.audioStrategy = .followProgram

        XCTAssertNil(viewModel.lastAudioRoutingTransition)
    }

    func testSameProgramIDDoesNotTriggerProgramFade() throws {
        let viewModel = makeViewModel()
        let url = try makeTempURL(ext: "mp4")
        defer { try? FileManager.default.removeItem(at: url) }
        let item = ProgramItem(title: "Opening", subtitle: "MP4", sourceURL: url)

        let switchedAtDate = Date()
        viewModel.applyCurrentProgramProjectionFromRuntime(item, switchedAt: switchedAtDate)
        let switchedAt = viewModel.currentProgramSwitchedAt
        viewModel.resetLastAudioRoutingTransitionForTesting()

        viewModel.applyCurrentProgramProjectionFromRuntime(item, switchedAt: switchedAt)

        XCTAssertNil(viewModel.lastAudioRoutingTransition)
        XCTAssertEqual(viewModel.currentProgramSwitchedAt, switchedAt)
    }

    func testSameFaderAndMuteValuesDoNotCreateTransitions() {
        let viewModel = makeViewModel()
        viewModel.masterVolume = 0.7
        viewModel.mediaVolume = 0.6
        viewModel.bgmVolume = 0.4
        viewModel.isMasterAudioMuted = true
        viewModel.isMediaAudioMuted = true
        viewModel.isBGMAudioMuted = true
        viewModel.resetLastAudioRoutingTransitionForTesting()

        viewModel.masterVolume = 0.7
        viewModel.mediaVolume = 0.6
        viewModel.bgmVolume = 0.4
        viewModel.isMasterAudioMuted = true
        viewModel.isMediaAudioMuted = true
        viewModel.isBGMAudioMuted = true

        XCTAssertNil(viewModel.lastAudioRoutingTransition)
    }

    func testBGMTakeoverUsesLimiterChangedRoutingReason() {
        let viewModel = makeViewModel()
        viewModel.liveAudioFadeDuration = 1.5

        viewModel.isBGMAudioTakeoverActive = true

        XCTAssertEqual(viewModel.lastAudioRoutingTransition?.reason, .limiterChanged)
        XCTAssertEqual(viewModel.lastAudioRoutingTransition?.mediaFadeDuration, 1.5)
        XCTAssertEqual(viewModel.lastAudioRoutingTransition?.bgmFadeDuration, 1.5)
    }

    func testDirectSpeakerModeSetterStillAppliesSpeakerRouting() {
        let viewModel = makeViewModel()
        viewModel.liveAudioFadeDuration = 1.25
        viewModel.resetLastAudioRoutingTransitionForTesting()

        viewModel.isSpeakerMode = true

        XCTAssertEqual(viewModel.lastAudioRoutingTransition?.reason, .speakerChanged)
        XCTAssertEqual(viewModel.lastAudioRoutingTransition?.mediaFadeDuration, 1.25)
        XCTAssertEqual(viewModel.lastAudioRoutingTransition?.bgmFadeDuration, 1.25)
    }

    func testFaderDragUsesShortRoutingTransition() {
        let viewModel = makeViewModel()
        viewModel.liveAudioFadeDuration = 2.0

        viewModel.masterVolume = 0.7

        XCTAssertEqual(viewModel.lastAudioRoutingTransition?.reason, .operatorFaderChanged)
        XCTAssertLessThanOrEqual(viewModel.lastAudioRoutingTransition?.mediaFadeDuration ?? 1, 0.08)
        XCTAssertLessThanOrEqual(viewModel.lastAudioRoutingTransition?.bgmFadeDuration ?? 1, 0.08)
    }

    func testFollowProgramVideoPauseCrossfadesBackToBGM() throws {
        let viewModel = makeViewModel()
        viewModel.liveAudioFadeDuration = 0
        viewModel.masterVolume = 0.8
        viewModel.mediaVolume = 0.5
        viewModel.bgmVolume = 0.5
        viewModel.audioStrategy = .followProgram
        let videoURL = try makeTempURL(ext: "mp4")
        defer { try? FileManager.default.removeItem(at: videoURL) }

        viewModel.switchToProgram(ProgramItem(title: "Opening", subtitle: "MP4", sourceURL: videoURL))
        XCTAssertEqual(viewModel.effectiveMediaOutputVolume(), 0.4, accuracy: 0.0001)
        XCTAssertEqual(viewModel.effectiveBGMOutputVolume(), 0, accuracy: 0.0001)

        viewModel.toggleMainVideoPlayback()

        XCTAssertEqual(viewModel.effectiveMediaOutputVolume(), 0, accuracy: 0.0001)
        XCTAssertEqual(viewModel.effectiveBGMOutputVolume(), 0.4, accuracy: 0.0001)
        XCTAssertEqual(viewModel.lastAudioRoutingTransition?.reason, .mediaPlaybackChanged)
    }

    func testMixedKeepsBothChannelsAndOnlyChangesLevels() throws {
        let viewModel = makeViewModel()
        viewModel.liveAudioFadeDuration = 0
        viewModel.masterVolume = 0.8
        viewModel.mediaVolume = 0.5
        viewModel.bgmVolume = 0.25
        viewModel.audioStrategy = .mixed
        let videoURL = try makeTempURL(ext: "mp4")
        defer { try? FileManager.default.removeItem(at: videoURL) }

        viewModel.switchToProgram(ProgramItem(title: "Opening", subtitle: "MP4", sourceURL: videoURL))

        XCTAssertEqual(viewModel.effectiveMediaOutputVolume(), 0.4, accuracy: 0.0001)
        XCTAssertEqual(viewModel.effectiveBGMOutputVolume(), 0.2, accuracy: 0.0001)
    }
}
