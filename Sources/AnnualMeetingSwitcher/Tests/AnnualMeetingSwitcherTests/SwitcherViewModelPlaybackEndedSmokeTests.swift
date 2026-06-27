import AppKit
import SwiftUI
import XCTest
@testable import LiveSwitcher

@MainActor
final class SwitcherViewModelPlaybackEndedSmokeTests: SwitcherViewModelSmokeTestCase {
    func testPlaybackEndedClearsCurrentProgramAndReturnsToWallpaper() throws {
        let viewModel = makeViewModel()
        let videoURL = try makeTempFileURL(ext: "mp4")
        let wallpaperURL = try makeWallpaperURL()
        defer {
            try? FileManager.default.removeItem(at: videoURL)
            try? FileManager.default.removeItem(at: wallpaperURL)
        }

        viewModel.addWallpaper(url: wallpaperURL)
        viewModel.setActiveWallpaper(url: wallpaperURL)
        let videoItem = ProgramItem(title: "片尾视频", subtitle: "MP4", sourceURL: videoURL)

        viewModel.isBroadcasting = true
        viewModel.switchToProgram(videoItem)
        XCTAssertTrue(viewModel.avCoordinator.isPlaying)
        XCTAssertEqual(viewModel.avCoordinator.currentURL, videoURL)

        viewModel.avCoordinator.isPlaying = false
        viewModel.avCoordinator.didPlayToEnd = true
        viewModel.handlePlaybackEnded()

        XCTAssertNil(viewModel.currentProgramItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertTrue(viewModel.avCoordinator.didPlayToEnd)
        XCTAssertNotNil(viewModel.backgroundImage)
        XCTAssertTrue(viewModel.isBroadcasting)
    }


    func testPlaybackEndedAutoPlaysNextVideoOnlyWhenEnabled() throws {
        let viewModel = makeViewModel()
        let firstVideoURL = try makeTempFileURL(ext: "mp4")
        let secondVideoURL = try makeTempFileURL(ext: "mov")
        defer {
            try? FileManager.default.removeItem(at: firstVideoURL)
            try? FileManager.default.removeItem(at: secondVideoURL)
        }

        let firstVideo = ProgramItem(title: "片头", subtitle: "MP4", sourceURL: firstVideoURL)
        let secondVideo = ProgramItem(title: "下一条", subtitle: "MOV", sourceURL: secondVideoURL)
        viewModel.addProgramItem(firstVideo)
        viewModel.addProgramItem(secondVideo)
        viewModel.autoPlayNextVideoOnEnd = true
        viewModel.switchToProgram(firstVideo)

        viewModel.avCoordinator.isPlaying = false
        viewModel.avCoordinator.didPlayToEnd = true
        viewModel.avCoordinator.onPlaybackEnded?()

        XCTAssertEqual(viewModel.currentProgramItem, secondVideo)
        XCTAssertEqual(viewModel.avCoordinator.currentURL, secondVideoURL)
        XCTAssertTrue(viewModel.avCoordinator.isPlaying)
        XCTAssertFalse(viewModel.avCoordinator.didPlayToEnd)
        XCTAssertNil(viewModel.currentHTMLURL)
    }


    func testPlaybackEndedWithMissingAutoNextVideoReturnsToIdleInsteadOfStaleCurrent() throws {
        let viewModel = makeViewModel()
        let firstVideoURL = try makeTempFileURL(ext: "mp4")
        let missingNextURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")
        defer { try? FileManager.default.removeItem(at: firstVideoURL) }

        let firstVideo = ProgramItem(title: "片头", subtitle: "MP4", sourceURL: firstVideoURL)
        let missingNext = ProgramItem(title: "已移动下一条", subtitle: "MOV", sourceURL: missingNextURL)
        viewModel.addProgramItem(firstVideo)
        viewModel.addProgramItem(missingNext)
        viewModel.autoPlayNextVideoOnEnd = true
        viewModel.switchToProgram(firstVideo)

        viewModel.avCoordinator.isPlaying = false
        viewModel.avCoordinator.didPlayToEnd = true
        viewModel.avCoordinator.onPlaybackEnded?()

        XCTAssertNil(viewModel.currentProgramItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertTrue(viewModel.avCoordinator.didPlayToEnd)
        XCTAssertNotEqual(viewModel.avCoordinator.currentURL, missingNextURL)
        XCTAssertEqual(viewModel.supportEvents.last?.kind, .programItemFileMissing)
        XCTAssertTrue(viewModel.supportEvents.last?.detail.contains("sourceKind=media") == true)
        XCTAssertEqual(viewModel.automationRuntimeNotice?.title, "节目文件不存在")
    }


    func testPlaybackEndedDoesNotAutoOpenNonVideoNextProgram() throws {
        let viewModel = makeViewModel()
        let videoURL = try makeTempFileURL(ext: "mp4")
        let htmlURL = try makeTempFileURL(ext: "html")
        let pptxURL = try makeTempFileURL(ext: "pptx")
        defer {
            try? FileManager.default.removeItem(at: videoURL)
            try? FileManager.default.removeItem(at: htmlURL)
            try? FileManager.default.removeItem(at: pptxURL)
        }
        var openedPPTXCount = 0
        viewModel.programActivationSideEffects.openPPTX = { _ in openedPPTXCount += 1 }

        let videoItem = ProgramItem(title: "片头", subtitle: "MP4", sourceURL: videoURL)
        let htmlItem = ProgramItem(title: "大屏页", subtitle: "HTML", sourceURL: htmlURL)
        let pptxItem = ProgramItem(title: "汇报", subtitle: "PPTX", sourceURL: pptxURL)
        viewModel.addProgramItem(videoItem)
        viewModel.addProgramItem(htmlItem)
        viewModel.addProgramItem(pptxItem)
        viewModel.autoPlayNextVideoOnEnd = true
        viewModel.switchToProgram(videoItem)

        viewModel.avCoordinator.isPlaying = false
        viewModel.avCoordinator.didPlayToEnd = true
        viewModel.avCoordinator.onPlaybackEnded?()

        XCTAssertNil(viewModel.currentProgramItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertEqual(openedPPTXCount, 0)
    }


    func testPlaybackEndedDoesNotAutoAdvanceToAudioProgram() throws {
        let viewModel = makeViewModel()
        let videoURL = try makeTempFileURL(ext: "mp4")
        let audioURL = try makeTempFileURL(ext: "mp3")
        defer {
            try? FileManager.default.removeItem(at: videoURL)
            try? FileManager.default.removeItem(at: audioURL)
        }

        let firstVideo = ProgramItem(title: "片头", subtitle: "MP4", sourceURL: videoURL)
        let nextAudio = ProgramItem(title: "暖场音乐", subtitle: "MP3", sourceURL: audioURL)
        viewModel.addProgramItem(firstVideo)
        viewModel.addProgramItem(nextAudio)
        viewModel.autoPlayNextVideoOnEnd = true
        viewModel.switchToProgram(firstVideo)

        viewModel.avCoordinator.isPlaying = false
        viewModel.avCoordinator.didPlayToEnd = true
        viewModel.avCoordinator.onPlaybackEnded?()

        XCTAssertNil(viewModel.currentProgramItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertNotEqual(viewModel.avCoordinator.currentURL, audioURL)
    }


    func testPlaybackEndedCallbackUsesCoordinatorHookToReturnToWallpaper() throws {
        let viewModel = makeViewModel()
        let videoURL = try makeTempFileURL(ext: "mp4")
        let wallpaperURL = try makeWallpaperURL()
        defer {
            try? FileManager.default.removeItem(at: videoURL)
            try? FileManager.default.removeItem(at: wallpaperURL)
        }

        viewModel.addWallpaper(url: wallpaperURL)
        viewModel.setActiveWallpaper(url: wallpaperURL)
        let videoItem = ProgramItem(title: "片尾视频", subtitle: "MP4", sourceURL: videoURL)

        viewModel.isBroadcasting = true
        viewModel.switchToProgram(videoItem)
        XCTAssertEqual(viewModel.currentProgramItem, videoItem)
        XCTAssertEqual(viewModel.avCoordinator.currentURL, videoURL)
        XCTAssertTrue(viewModel.avCoordinator.isPlaying)

        viewModel.avCoordinator.isPlaying = false
        viewModel.avCoordinator.didPlayToEnd = true
        viewModel.avCoordinator.onPlaybackEnded?()

        XCTAssertNil(viewModel.currentProgramItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertTrue(viewModel.avCoordinator.didPlayToEnd)
        XCTAssertNotNil(viewModel.backgroundImage)
        XCTAssertTrue(viewModel.isBroadcasting)
    }


    func testPlaybackEndedWhileBroadcastingDoesNotHideOutputWindow() throws {
        let viewModel = makeViewModel()
        let outputSpy = SwitcherViewModelSmokeOutputWindowControllerSpy()
        let videoURL = try makeTempFileURL(ext: "mp4")
        let wallpaperURL = try makeWallpaperURL()
        defer {
            try? FileManager.default.removeItem(at: videoURL)
            try? FileManager.default.removeItem(at: wallpaperURL)
        }

        viewModel.outputWindowControllerFactory = { outputSpy }
        viewModel.addWallpaper(url: wallpaperURL)
        viewModel.setActiveWallpaper(url: wallpaperURL)
        let videoItem = ProgramItem(title: "片尾视频", subtitle: "MP4", sourceURL: videoURL)
        viewModel.switchToProgram(videoItem)
        viewModel.handleBroadcastToggle()

        viewModel.avCoordinator.isPlaying = false
        viewModel.avCoordinator.didPlayToEnd = true
        viewModel.avCoordinator.onPlaybackEnded?()

        XCTAssertNil(viewModel.currentProgramItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertNotNil(viewModel.backgroundImage)
        XCTAssertTrue(viewModel.isBroadcasting)
        XCTAssertEqual(outputSpy.showCount, 1)
        XCTAssertEqual(outputSpy.hideCount, 0)
    }


    func testRepeatedPlaybackEndedCallbacksRemainIdleAndKeepOutputWindowVisible() throws {
        let viewModel = makeViewModel()
        let outputSpy = SwitcherViewModelSmokeOutputWindowControllerSpy()
        let videoURL = try makeTempFileURL(ext: "mp4")
        let wallpaperURL = try makeWallpaperURL()
        defer {
            try? FileManager.default.removeItem(at: videoURL)
            try? FileManager.default.removeItem(at: wallpaperURL)
        }

        viewModel.outputWindowControllerFactory = { outputSpy }
        viewModel.addWallpaper(url: wallpaperURL)
        viewModel.setActiveWallpaper(url: wallpaperURL)
        let videoItem = ProgramItem(title: "片尾视频", subtitle: "MP4", sourceURL: videoURL)
        viewModel.switchToProgram(videoItem)
        viewModel.handleBroadcastToggle()

        viewModel.avCoordinator.isPlaying = false
        viewModel.avCoordinator.didPlayToEnd = true
        viewModel.avCoordinator.onPlaybackEnded?()
        viewModel.avCoordinator.onPlaybackEnded?()

        XCTAssertNil(viewModel.currentProgramItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertTrue(viewModel.avCoordinator.didPlayToEnd)
        XCTAssertNotNil(viewModel.backgroundImage)
        XCTAssertTrue(viewModel.isBroadcasting)
        XCTAssertEqual(outputSpy.showCount, 1)
        XCTAssertEqual(outputSpy.hideCount, 0)
    }
}
