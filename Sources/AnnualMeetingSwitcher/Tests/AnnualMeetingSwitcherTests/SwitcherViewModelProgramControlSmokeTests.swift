import AppKit
import SwiftUI
import XCTest
@testable import LiveSwitcher

@MainActor
final class SwitcherViewModelProgramControlSmokeTests: SwitcherViewModelSmokeTestCase {
    func testToggleMainVideoPlaybackPausesAndResumesCurrentVideo() throws {
        let viewModel = makeViewModel()
        let videoURL = try makeTempFileURL(ext: "mp4")
        defer { try? FileManager.default.removeItem(at: videoURL) }

        let videoItem = ProgramItem(title: "片头", subtitle: "MP4", sourceURL: videoURL)
        viewModel.switchToProgram(videoItem)

        XCTAssertTrue(viewModel.avCoordinator.isPlaying)
        XCTAssertEqual(viewModel.avCoordinator.currentURL, videoURL)

        viewModel.toggleMainVideoPlayback()
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertEqual(viewModel.currentProgramItem, videoItem)
        XCTAssertEqual(viewModel.avCoordinator.currentURL, videoURL)

        viewModel.toggleMainVideoPlayback()
        XCTAssertTrue(viewModel.avCoordinator.isPlaying)
        XCTAssertEqual(viewModel.currentProgramItem, videoItem)
        XCTAssertEqual(viewModel.avCoordinator.currentURL, videoURL)
    }


    func testToggleMainVideoPlaybackIsNoOpForCurrentHTMLProgram() throws {
        let viewModel = makeViewModel()
        let htmlURL = try makeTempFileURL(ext: "html")
        defer { try? FileManager.default.removeItem(at: htmlURL) }

        let htmlItem = ProgramItem(title: "签到页", subtitle: "HTML", sourceURL: htmlURL)
        viewModel.switchToProgram(htmlItem)

        XCTAssertEqual(viewModel.currentProgramItem, htmlItem)
        XCTAssertEqual(viewModel.currentHTMLURL, htmlURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)

        viewModel.toggleMainVideoPlayback()

        XCTAssertEqual(viewModel.currentProgramItem, htmlItem)
        XCTAssertEqual(viewModel.currentHTMLURL, htmlURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
    }


    func testToggleMainVideoPlaybackIsNoOpWithoutCurrentProgram() {
        let viewModel = makeViewModel()

        XCTAssertNil(viewModel.currentProgramItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)

        viewModel.toggleMainVideoPlayback()

        XCTAssertNil(viewModel.currentProgramItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
    }


    func testToggleMainVideoPlaybackForDeckProgramInvokesDeckStopHandler() throws {
        let viewModel = makeViewModel()
        let keynoteURL = try makeTempFileURL(ext: "key")
        defer { try? FileManager.default.removeItem(at: keynoteURL) }

        let keynoteItem = ProgramItem(title: "主持稿", subtitle: "KEY", sourceURL: keynoteURL)
        var stopInvocationCount = 0
        viewModel.programActivationSideEffects.stopDeck = {
            stopInvocationCount += 1
        }

        viewModel.applyCurrentProgramProjectionFromRuntime(keynoteItem, switchedAt: Date())
        mirrorRuntimeCurrentProgramState(viewModel, item: keynoteItem)
        viewModel.toggleMainVideoPlayback()

        XCTAssertEqual(stopInvocationCount, 1)
        XCTAssertEqual(viewModel.currentProgramItem, keynoteItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
    }


    func testToggleMainVideoPlaybackForActiveDeckWithoutSourceInvokesDeckStopHandler() {
        let viewModel = makeViewModel()
        let activeDeckItem = ProgramItem(title: "主持稿", subtitle: "KEY (活动)", sourceURL: nil)
        var stopInvocationCount = 0
        viewModel.programActivationSideEffects.stopDeck = {
            stopInvocationCount += 1
        }

        viewModel.applyCurrentProgramProjectionFromRuntime(activeDeckItem, switchedAt: Date())
        mirrorRuntimeCurrentProgramState(viewModel, item: activeDeckItem)
        viewModel.toggleMainVideoPlayback()

        XCTAssertEqual(stopInvocationCount, 1)
        XCTAssertEqual(viewModel.currentProgramItem, activeDeckItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
    }


    func testTogglePauseSwitchesToRequestedProgramWhenItemIsNotCurrent() throws {
        let viewModel = makeViewModel()
        let currentVideoURL = try makeTempFileURL(ext: "mp4")
        let targetVideoURL = try makeTempFileURL(ext: "mp4")
        defer {
            try? FileManager.default.removeItem(at: currentVideoURL)
            try? FileManager.default.removeItem(at: targetVideoURL)
        }

        let currentItem = ProgramItem(title: "当前节目", subtitle: "MP4", sourceURL: currentVideoURL)
        let targetItem = ProgramItem(title: "目标节目", subtitle: "MP4", sourceURL: targetVideoURL)

        viewModel.switchToProgram(currentItem)
        XCTAssertEqual(viewModel.currentProgramItem, currentItem)
        XCTAssertEqual(viewModel.avCoordinator.currentURL, currentVideoURL)

        viewModel.togglePause(for: targetItem)

        XCTAssertEqual(viewModel.currentProgramItem, targetItem)
        XCTAssertEqual(viewModel.avCoordinator.currentURL, targetVideoURL)
        XCTAssertTrue(viewModel.avCoordinator.isPlaying)
    }


    func testTogglePauseProgramSwitchWhileBroadcastingDoesNotReopenOutputWindow() throws {
        let viewModel = makeViewModel()
        let outputSpy = SwitcherViewModelSmokeOutputWindowControllerSpy()
        let currentVideoURL = try makeTempFileURL(ext: "mp4")
        let targetHTMLURL = try makeTempFileURL(ext: "html")
        defer {
            try? FileManager.default.removeItem(at: currentVideoURL)
            try? FileManager.default.removeItem(at: targetHTMLURL)
        }

        viewModel.outputWindowControllerFactory = { outputSpy }
        let currentItem = ProgramItem(title: "片头", subtitle: "MP4", sourceURL: currentVideoURL)
        let targetItem = ProgramItem(title: "签到页", subtitle: "HTML", sourceURL: targetHTMLURL)

        viewModel.switchToProgram(currentItem)
        viewModel.handleBroadcastToggle()
        XCTAssertEqual(outputSpy.mountCount, 1)
        XCTAssertEqual(outputSpy.showCount, 1)

        viewModel.togglePause(for: targetItem)

        XCTAssertEqual(viewModel.currentProgramItem, targetItem)
        XCTAssertEqual(viewModel.currentHTMLURL, targetHTMLURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertTrue(viewModel.isBroadcasting)
        XCTAssertEqual(outputSpy.mountCount, 1)
        XCTAssertEqual(outputSpy.showCount, 1)
        XCTAssertEqual(outputSpy.hideCount, 0)
    }


    func testTogglePauseForCurrentProgramTogglesPlaybackState() throws {
        let viewModel = makeViewModel()
        let videoURL = try makeTempFileURL(ext: "mp4")
        defer { try? FileManager.default.removeItem(at: videoURL) }

        let videoItem = ProgramItem(title: "片头", subtitle: "MP4", sourceURL: videoURL)
        viewModel.switchToProgram(videoItem)
        XCTAssertTrue(viewModel.avCoordinator.isPlaying)

        viewModel.togglePause(for: videoItem)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertEqual(viewModel.currentProgramItem, videoItem)

        viewModel.togglePause(for: videoItem)
        XCTAssertTrue(viewModel.avCoordinator.isPlaying)
        XCTAssertEqual(viewModel.currentProgramItem, videoItem)
    }


    func testTogglePauseForCurrentHTMLProgramIsNoOp() throws {
        let viewModel = makeViewModel()
        let htmlURL = try makeTempFileURL(ext: "html")
        defer { try? FileManager.default.removeItem(at: htmlURL) }

        let htmlItem = ProgramItem(title: "签到页", subtitle: "HTML", sourceURL: htmlURL)
        viewModel.switchToProgram(htmlItem)

        XCTAssertEqual(viewModel.currentProgramItem, htmlItem)
        XCTAssertEqual(viewModel.currentHTMLURL, htmlURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)

        viewModel.togglePause(for: htmlItem)

        XCTAssertEqual(viewModel.currentProgramItem, htmlItem)
        XCTAssertEqual(viewModel.currentHTMLURL, htmlURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
    }


    func testTogglePauseForCurrentActiveDeckInvokesDeckStopHandler() {
        let viewModel = makeViewModel()
        let activeDeckItem = ProgramItem(title: "主持稿", subtitle: "KEY (活动)", sourceURL: nil)
        var stopInvocationCount = 0
        viewModel.programActivationSideEffects.stopDeck = {
            stopInvocationCount += 1
        }

        viewModel.applyCurrentProgramProjectionFromRuntime(activeDeckItem, switchedAt: Date())
        mirrorRuntimeCurrentProgramState(viewModel, item: activeDeckItem)

        viewModel.togglePause(for: activeDeckItem)

        XCTAssertEqual(stopInvocationCount, 1)
        XCTAssertEqual(viewModel.currentProgramItem, activeDeckItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
    }


    func testTogglePauseForCurrentDeckProgramInvokesDeckStopHandler() throws {
        let viewModel = makeViewModel()
        let keynoteURL = try makeTempFileURL(ext: "key")
        defer { try? FileManager.default.removeItem(at: keynoteURL) }

        let keynoteItem = ProgramItem(title: "主持稿", subtitle: "KEY", sourceURL: keynoteURL)
        var stopInvocationCount = 0
        viewModel.programActivationSideEffects.stopDeck = {
            stopInvocationCount += 1
        }

        viewModel.applyCurrentProgramProjectionFromRuntime(keynoteItem, switchedAt: Date())
        mirrorRuntimeCurrentProgramState(viewModel, item: keynoteItem)

        viewModel.togglePause(for: keynoteItem)

        XCTAssertEqual(stopInvocationCount, 1)
        XCTAssertEqual(viewModel.currentProgramItem, keynoteItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
    }


    func testTogglePauseSwitchesToActiveDeckWithoutSourceWhenItemIsNotCurrent() throws {
        let viewModel = makeViewModel()
        let videoURL = try makeTempFileURL(ext: "mp4")
        defer { try? FileManager.default.removeItem(at: videoURL) }

        var presentFrontDeckInvocationCount = 0
        viewModel.programActivationSideEffects.presentActiveDeck = {
            presentFrontDeckInvocationCount += 1
        }

        let videoItem = ProgramItem(title: "片头", subtitle: "MP4", sourceURL: videoURL)
        let activeDeckItem = ProgramItem(title: "主持稿", subtitle: "KEY (活动)", sourceURL: nil)

        viewModel.switchToProgram(videoItem)
        XCTAssertEqual(viewModel.currentProgramItem, videoItem)
        XCTAssertEqual(viewModel.avCoordinator.currentURL, videoURL)
        XCTAssertTrue(viewModel.avCoordinator.isPlaying)

        viewModel.togglePause(for: activeDeckItem)

        XCTAssertEqual(viewModel.currentProgramItem, activeDeckItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertEqual(presentFrontDeckInvocationCount, 1)
    }


    func testTogglePauseSwitchesFromCurrentHTMLToDifferentHTMLProgram() throws {
        let viewModel = makeViewModel()
        let firstHTMLURL = try makeTempFileURL(ext: "html")
        let secondHTMLURL = try makeTempFileURL(ext: "html")
        defer {
            try? FileManager.default.removeItem(at: firstHTMLURL)
            try? FileManager.default.removeItem(at: secondHTMLURL)
        }

        let currentItem = ProgramItem(title: "签到页", subtitle: "HTML", sourceURL: firstHTMLURL)
        let targetItem = ProgramItem(title: "主视觉", subtitle: "HTML", sourceURL: secondHTMLURL)

        viewModel.switchToProgram(currentItem)
        XCTAssertEqual(viewModel.currentProgramItem, currentItem)
        XCTAssertEqual(viewModel.currentHTMLURL, firstHTMLURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)

        viewModel.togglePause(for: targetItem)

        XCTAssertEqual(viewModel.currentProgramItem, targetItem)
        XCTAssertEqual(viewModel.currentHTMLURL, secondHTMLURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
    }


    func testTogglePauseSwitchesFromCurrentHTMLToDeckProgram() throws {
        let viewModel = makeViewModel()
        let htmlURL = try makeTempFileURL(ext: "html")
        let keynoteURL = try makeTempFileURL(ext: "key")
        defer {
            try? FileManager.default.removeItem(at: htmlURL)
            try? FileManager.default.removeItem(at: keynoteURL)
        }

        var presentedURL: URL?
        viewModel.programActivationSideEffects.presentKeynote = { url in
            presentedURL = url
        }

        let currentItem = ProgramItem(title: "签到页", subtitle: "HTML", sourceURL: htmlURL)
        let targetItem = ProgramItem(title: "主持稿", subtitle: "KEY", sourceURL: keynoteURL)

        viewModel.switchToProgram(currentItem)
        XCTAssertEqual(viewModel.currentProgramItem, currentItem)
        XCTAssertEqual(viewModel.currentHTMLURL, htmlURL)

        viewModel.togglePause(for: targetItem)

        XCTAssertEqual(viewModel.currentProgramItem, targetItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertEqual(presentedURL, keynoteURL)
    }


    func testTogglePauseSwitchesFromCurrentDeckToHTMLProgram() throws {
        let viewModel = makeViewModel()
        let keynoteURL = try makeTempFileURL(ext: "key")
        let htmlURL = try makeTempFileURL(ext: "html")
        defer {
            try? FileManager.default.removeItem(at: keynoteURL)
            try? FileManager.default.removeItem(at: htmlURL)
        }

        var presentedURL: URL?
        viewModel.programActivationSideEffects.presentKeynote = { url in
            presentedURL = url
        }

        let currentItem = ProgramItem(title: "主持稿", subtitle: "KEY", sourceURL: keynoteURL)
        let targetItem = ProgramItem(title: "签到页", subtitle: "HTML", sourceURL: htmlURL)

        viewModel.switchToProgram(currentItem)
        XCTAssertEqual(viewModel.currentProgramItem, currentItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertEqual(presentedURL, keynoteURL)

        viewModel.togglePause(for: targetItem)

        XCTAssertEqual(viewModel.currentProgramItem, targetItem)
        XCTAssertEqual(viewModel.currentHTMLURL, htmlURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
    }

}
