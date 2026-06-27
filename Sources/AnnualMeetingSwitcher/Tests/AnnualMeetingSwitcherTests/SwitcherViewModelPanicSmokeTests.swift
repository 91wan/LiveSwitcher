import AppKit
import SwiftUI
import XCTest
@testable import LiveSwitcher

@MainActor
final class SwitcherViewModelPanicSmokeTests: SwitcherViewModelSmokeTestCase {
    func testPanicModeForcesEffectiveMediaAndBGMVolumesToZero() throws {
        let viewModel = makeViewModel()
        viewModel.liveAudioFadeDuration = 0
        viewModel.masterVolume = 0.8
        viewModel.mediaVolume = 0.5
        viewModel.bgmVolume = 0.25
        viewModel.audioStrategy = .mixed
        let videoURL = try makeTempFileURL(ext: "mp4")
        defer { try? FileManager.default.removeItem(at: videoURL) }

        viewModel.switchToProgram(ProgramItem(title: "Opening", subtitle: "MP4", sourceURL: videoURL))
        XCTAssertTrue(viewModel.avCoordinator.isPlaying)
        XCTAssertEqual(viewModel.effectiveMediaOutputVolume(), 0.4, accuracy: 0.0001)
        XCTAssertEqual(viewModel.effectiveBGMOutputVolume(), 0.2, accuracy: 0.0001)

        viewModel.togglePanicMode()

        XCTAssertTrue(viewModel.isPanicMode)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertEqual(viewModel.effectiveMediaOutputVolume(), 0, accuracy: 0.0001)
        XCTAssertEqual(viewModel.effectiveBGMOutputVolume(), 0, accuracy: 0.0001)
        XCTAssertEqual(viewModel.avCoordinator.volume, 0, accuracy: 0.0001)
        XCTAssertEqual(viewModel.bgmFallbackPlayer.volume, 0, accuracy: 0.0001)
    }


    func testPanicRestoreResumesOnlyIfMediaWasPlayingBefore() throws {
        let viewModel = makeViewModel()
        viewModel.liveAudioFadeDuration = 0
        let videoURL = try makeTempFileURL(ext: "mp4")
        defer { try? FileManager.default.removeItem(at: videoURL) }

        viewModel.switchToProgram(ProgramItem(title: "Opening", subtitle: "MP4", sourceURL: videoURL))
        XCTAssertTrue(viewModel.avCoordinator.isPlaying)

        viewModel.togglePanicMode()
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)

        viewModel.togglePanicMode()
        XCTAssertFalse(viewModel.isPanicMode)
        XCTAssertTrue(viewModel.avCoordinator.isPlaying)
    }


    func testPanicRestoreDoesNotAutoPlayPausedMedia() throws {
        let viewModel = makeViewModel()
        viewModel.liveAudioFadeDuration = 0
        let videoURL = try makeTempFileURL(ext: "mp4")
        defer { try? FileManager.default.removeItem(at: videoURL) }

        viewModel.switchToProgram(ProgramItem(title: "Opening", subtitle: "MP4", sourceURL: videoURL))
        viewModel.avCoordinator.pause()
        let currentItem = try XCTUnwrap(viewModel.currentProgramItem)
        mirrorRuntimeMediaState(viewModel, item: currentItem, isPlaying: false)

        viewModel.togglePanicMode()
        viewModel.togglePanicMode()

        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
    }


    func testPanicRestoreDoesNotResumeIfProgramChangedDuringPanic() throws {
        let viewModel = makeViewModel()
        viewModel.liveAudioFadeDuration = 0
        let firstURL = try makeTempFileURL(ext: "mp4")
        let secondURL = try makeTempFileURL(ext: "mp4")
        defer {
            try? FileManager.default.removeItem(at: firstURL)
            try? FileManager.default.removeItem(at: secondURL)
        }
        let first = ProgramItem(title: "Opening", subtitle: "MP4", sourceURL: firstURL)
        let second = ProgramItem(title: "Awards", subtitle: "MP4", sourceURL: secondURL)

        viewModel.switchToProgram(first)
        viewModel.togglePanicMode()
        viewModel.switchToProgram(second)
        viewModel.avCoordinator.pause()

        viewModel.togglePanicMode()

        XCTAssertEqual(viewModel.currentProgramItem?.id, second.id)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
    }


    func testFadeToBlackDoesNotPauseMedia() throws {
        let viewModel = makeViewModel()
        let videoURL = try makeTempFileURL(ext: "mp4")
        defer { try? FileManager.default.removeItem(at: videoURL) }

        viewModel.switchToProgram(ProgramItem(title: "Opening", subtitle: "MP4", sourceURL: videoURL))
        viewModel.toggleFadeToBlack()

        XCTAssertTrue(viewModel.isFadeToBlackActive)
        XCTAssertTrue(viewModel.avCoordinator.isPlaying)
    }


    func testPanicModeOffRestoresCurrentRoutingInsteadOfOldSnapshot() throws {
        let viewModel = makeViewModel()
        viewModel.liveAudioFadeDuration = 0
        viewModel.masterVolume = 0.8
        viewModel.mediaVolume = 0.5
        viewModel.bgmVolume = 0.25
        viewModel.audioStrategy = .mixed
        let videoURL = try makeTempFileURL(ext: "mp4")
        defer { try? FileManager.default.removeItem(at: videoURL) }

        viewModel.switchToProgram(ProgramItem(title: "Opening", subtitle: "MP4", sourceURL: videoURL))
        viewModel.togglePanicMode()

        viewModel.masterVolume = 0.5
        viewModel.mediaVolume = 0.2
        viewModel.bgmVolume = 0.4
        viewModel.audioStrategy = .followSource

        viewModel.togglePanicMode()

        XCTAssertFalse(viewModel.isPanicMode)
        XCTAssertEqual(viewModel.effectiveMediaOutputVolume(), 0.1, accuracy: 0.0001)
        XCTAssertEqual(viewModel.effectiveBGMOutputVolume(), 0, accuracy: 0.0001)
        XCTAssertEqual(viewModel.avCoordinator.volume, 0.1, accuracy: 0.0001)
        XCTAssertEqual(viewModel.bgmFallbackPlayer.volume, 0, accuracy: 0.0001)
    }


    func testBGMTakeoverPlusPanicNeverResurrectsMediaAudio() throws {
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

        viewModel.switchToProgram(ProgramItem(title: "Opening", subtitle: "MP4", sourceURL: videoURL))
        viewModel.toggleBGM(BGMItem(title: "Walk-in", url: bgmURL, category: .warmUp))
        viewModel.togglePanicMode()

        XCTAssertFalse(viewModel.isBGMAudioTakeoverActive)
        XCTAssertTrue(viewModel.isPanicMode)
        XCTAssertEqual(viewModel.effectiveMediaOutputVolume(), 0, accuracy: 0.0001)
        XCTAssertEqual(viewModel.effectiveBGMOutputVolume(), 0, accuracy: 0.0001)

        viewModel.togglePanicMode()

        XCTAssertFalse(viewModel.isPanicMode)
        XCTAssertFalse(viewModel.isBGMAudioTakeoverActive)
        XCTAssertEqual(viewModel.effectiveMediaOutputVolume(), 0.4, accuracy: 0.0001)
        XCTAssertEqual(viewModel.effectiveBGMOutputVolume(), 0.2, accuracy: 0.0001)
        XCTAssertEqual(viewModel.avCoordinator.volume, 0.4, accuracy: 0.0001)
    }

}
