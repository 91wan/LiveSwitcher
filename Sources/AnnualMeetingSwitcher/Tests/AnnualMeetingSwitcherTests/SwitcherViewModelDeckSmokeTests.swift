import AppKit
import SwiftUI
import XCTest
@testable import LiveSwitcher

@MainActor
final class SwitcherViewModelDeckSmokeTests: SwitcherViewModelSmokeTestCase {
    func testSwitchingToActiveDeckItemWithoutSourceURLStopsPreviousVideo() throws {
        let viewModel = makeViewModel()
        let videoURL = try makeTempFileURL(ext: "mp4")
        let htmlURL = try makeTempFileURL(ext: "html")
        defer {
            try? FileManager.default.removeItem(at: videoURL)
            try? FileManager.default.removeItem(at: htmlURL)
        }

        var presentFrontDeckInvocationCount = 0
        viewModel.programActivationSideEffects.presentActiveDeck = {
            presentFrontDeckInvocationCount += 1
        }

        let videoItem = ProgramItem(title: "片头", subtitle: "MP4", sourceURL: videoURL)
        let activeDeckItem = ProgramItem(title: "主持稿", subtitle: "KEY (活动)", sourceURL: nil)

        viewModel.currentHTMLURL = htmlURL
        viewModel.switchToProgram(videoItem)
        XCTAssertEqual(viewModel.avCoordinator.currentURL, videoURL)
        XCTAssertTrue(viewModel.avCoordinator.isPlaying)

        viewModel.switchToProgram(activeDeckItem)

        XCTAssertEqual(viewModel.currentProgramItem, activeDeckItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertEqual(presentFrontDeckInvocationCount, 1)
    }


    func testSwitchingFromVideoToActiveDeckWhileBroadcastingDoesNotReopenOutputWindow() throws {
        let viewModel = makeViewModel()
        let outputSpy = SwitcherViewModelSmokeOutputWindowControllerSpy()
        let videoURL = try makeTempFileURL(ext: "mp4")
        defer { try? FileManager.default.removeItem(at: videoURL) }

        var presentFrontDeckInvocationCount = 0
        viewModel.outputWindowControllerFactory = { outputSpy }
        viewModel.programActivationSideEffects.presentActiveDeck = {
            presentFrontDeckInvocationCount += 1
        }

        let videoItem = ProgramItem(title: "片头", subtitle: "MP4", sourceURL: videoURL)
        let activeDeckItem = ProgramItem(title: "主持稿", subtitle: "KEY (活动)", sourceURL: nil)

        viewModel.switchToProgram(videoItem)
        viewModel.handleBroadcastToggle()
        XCTAssertEqual(outputSpy.mountCount, 1)
        XCTAssertEqual(outputSpy.showCount, 1)

        viewModel.switchToProgram(activeDeckItem)

        XCTAssertEqual(viewModel.currentProgramItem, activeDeckItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertTrue(viewModel.isBroadcasting)
        XCTAssertEqual(presentFrontDeckInvocationCount, 1)
        XCTAssertEqual(outputSpy.mountCount, 1)
        XCTAssertEqual(outputSpy.showCount, 1)
        XCTAssertEqual(outputSpy.hideCount, 0)
    }


    func testSwitchingFromActiveDeckToHTMLWhileBroadcastingDoesNotReopenOutputWindow() throws {
        let viewModel = makeViewModel()
        let outputSpy = SwitcherViewModelSmokeOutputWindowControllerSpy()
        let htmlURL = try makeTempFileURL(ext: "html")
        defer { try? FileManager.default.removeItem(at: htmlURL) }

        var presentFrontDeckInvocationCount = 0
        viewModel.outputWindowControllerFactory = { outputSpy }
        viewModel.programActivationSideEffects.presentActiveDeck = {
            presentFrontDeckInvocationCount += 1
        }

        let activeDeckItem = ProgramItem(title: "主持稿", subtitle: "KEY (活动)", sourceURL: nil)
        let htmlItem = ProgramItem(title: "签到页", subtitle: "HTML", sourceURL: htmlURL)

        viewModel.switchToProgram(activeDeckItem)
        viewModel.handleBroadcastToggle()
        XCTAssertEqual(outputSpy.mountCount, 1)
        XCTAssertEqual(outputSpy.showCount, 1)

        viewModel.switchToProgram(htmlItem)

        XCTAssertEqual(viewModel.currentProgramItem, htmlItem)
        XCTAssertEqual(viewModel.currentHTMLURL, htmlURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertTrue(viewModel.isBroadcasting)
        XCTAssertEqual(presentFrontDeckInvocationCount, 1)
        XCTAssertEqual(outputSpy.mountCount, 1)
        XCTAssertEqual(outputSpy.showCount, 1)
        XCTAssertEqual(outputSpy.hideCount, 0)
    }


    func testSwitchingAwayFromActiveDeckStopsDeckPresentation() throws {
        let viewModel = makeViewModel()
        let videoURL = try makeTempFileURL(ext: "mp4")
        defer { try? FileManager.default.removeItem(at: videoURL) }

        let activeDeckItem = ProgramItem(title: "主持稿", subtitle: "KEY (活动)", sourceURL: nil)
        let videoItem = ProgramItem(title: "返场视频", subtitle: "MP4", sourceURL: videoURL)
        var presentFrontDeckInvocationCount = 0
        var stopInvocationCount = 0
        viewModel.programActivationSideEffects.presentActiveDeck = {
            presentFrontDeckInvocationCount += 1
        }
        viewModel.programActivationSideEffects.stopDeck = {
            stopInvocationCount += 1
        }

        viewModel.switchToProgram(activeDeckItem)
        XCTAssertEqual(viewModel.currentProgramItem, activeDeckItem)
        XCTAssertEqual(presentFrontDeckInvocationCount, 1)

        viewModel.switchToProgram(videoItem)

        XCTAssertEqual(viewModel.currentProgramItem, videoItem)
        XCTAssertEqual(viewModel.avCoordinator.currentURL, videoURL)
        XCTAssertTrue(viewModel.avCoordinator.isPlaying)
        XCTAssertEqual(stopInvocationCount, 1)
    }


    func testSelectingAgendaMarkerDoesNotStopCurrentActiveDeckPresentation() {
        let viewModel = makeViewModel()
        let activeDeckItem = ProgramItem(title: "主持稿", subtitle: "KEY (活动)", sourceURL: nil)
        let agendaMarker = ProgramItem.agendaMarker(title: "中场提醒")
        var presentFrontDeckInvocationCount = 0
        var stopInvocationCount = 0
        viewModel.programActivationSideEffects.presentActiveDeck = {
            presentFrontDeckInvocationCount += 1
        }
        viewModel.programActivationSideEffects.stopDeck = {
            stopInvocationCount += 1
        }

        viewModel.switchToProgram(activeDeckItem)
        viewModel.switchToProgram(agendaMarker)

        XCTAssertEqual(viewModel.currentProgramItem, activeDeckItem)
        XCTAssertEqual(presentFrontDeckInvocationCount, 1)
        XCTAssertEqual(stopInvocationCount, 0)
    }


    func testInvalidKeynoteDoesNotStopCurrentActiveDeckPresentation() throws {
        let viewModel = makeViewModel()
        let invalidKeynoteURL = try makeEmptyTempFileURL(ext: "key")
        defer { try? FileManager.default.removeItem(at: invalidKeynoteURL) }

        let activeDeckItem = ProgramItem(title: "主持稿", subtitle: "KEY (活动)", sourceURL: nil)
        let invalidKeynoteItem = ProgramItem(title: "空白 Keynote", subtitle: "KEY", sourceURL: invalidKeynoteURL)
        var presentFrontDeckInvocationCount = 0
        var stopInvocationCount = 0
        var invalidDeckURL: URL?
        viewModel.programActivationSideEffects.presentActiveDeck = {
            presentFrontDeckInvocationCount += 1
        }
        viewModel.programActivationSideEffects.stopDeck = {
            stopInvocationCount += 1
        }
        viewModel.programActivationSideEffects.presentInvalidDeckAlert = { url in
            invalidDeckURL = url
        }

        viewModel.switchToProgram(activeDeckItem)
        viewModel.switchToProgram(invalidKeynoteItem)

        XCTAssertEqual(viewModel.currentProgramItem, activeDeckItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertEqual(presentFrontDeckInvocationCount, 1)
        XCTAssertEqual(stopInvocationCount, 0)
        XCTAssertEqual(invalidDeckURL, invalidKeynoteURL)
    }


    func testEmptyKeynotePackageDoesNotStopCurrentActiveDeckPresentation() throws {
        let viewModel = makeViewModel()
        let emptyKeynotePackageURL = try makeTempDirectoryURL(ext: "keynote")
        defer { try? FileManager.default.removeItem(at: emptyKeynotePackageURL) }

        let activeDeckItem = ProgramItem(title: "主持稿", subtitle: "KEY (活动)", sourceURL: nil)
        let emptyPackageItem = ProgramItem(title: "空包 Keynote", subtitle: "KEY", sourceURL: emptyKeynotePackageURL)
        var presentFrontDeckInvocationCount = 0
        var stopInvocationCount = 0
        var invalidDeckURL: URL?
        viewModel.programActivationSideEffects.presentActiveDeck = {
            presentFrontDeckInvocationCount += 1
        }
        viewModel.programActivationSideEffects.stopDeck = {
            stopInvocationCount += 1
        }
        viewModel.programActivationSideEffects.presentInvalidDeckAlert = { url in
            invalidDeckURL = url
        }

        viewModel.switchToProgram(activeDeckItem)
        viewModel.switchToProgram(emptyPackageItem)

        XCTAssertEqual(viewModel.currentProgramItem, activeDeckItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertEqual(presentFrontDeckInvocationCount, 1)
        XCTAssertEqual(stopInvocationCount, 0)
        XCTAssertEqual(invalidDeckURL, emptyKeynotePackageURL)
    }


    func testInvalidPPTXDoesNotStopCurrentActiveDeckPresentation() throws {
        let viewModel = makeViewModel()
        let invalidPPTXURL = try makeEmptyTempFileURL(ext: "pptx")
        defer { try? FileManager.default.removeItem(at: invalidPPTXURL) }

        let activeDeckItem = ProgramItem(title: "主持稿", subtitle: "KEY (活动)", sourceURL: nil)
        let invalidPPTXItem = ProgramItem(title: "空白 PPT", subtitle: "PPTX", sourceURL: invalidPPTXURL)
        var presentFrontDeckInvocationCount = 0
        var stopInvocationCount = 0
        var invalidDeckURL: URL?
        viewModel.programActivationSideEffects.presentActiveDeck = {
            presentFrontDeckInvocationCount += 1
        }
        viewModel.programActivationSideEffects.stopDeck = {
            stopInvocationCount += 1
        }
        viewModel.programActivationSideEffects.presentInvalidDeckAlert = { url in
            invalidDeckURL = url
        }

        viewModel.switchToProgram(activeDeckItem)
        viewModel.switchToProgram(invalidPPTXItem)

        XCTAssertEqual(viewModel.currentProgramItem, activeDeckItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertEqual(presentFrontDeckInvocationCount, 1)
        XCTAssertEqual(stopInvocationCount, 0)
        XCTAssertEqual(invalidDeckURL, invalidPPTXURL)
    }


    func testDirectoryPPTXDoesNotStopCurrentActiveDeckPresentation() throws {
        let viewModel = makeViewModel()
        let directoryPPTXURL = try makeTempDirectoryURL(ext: "pptx")
        defer { try? FileManager.default.removeItem(at: directoryPPTXURL) }

        let activeDeckItem = ProgramItem(title: "主持稿", subtitle: "KEY (活动)", sourceURL: nil)
        let directoryPPTXItem = ProgramItem(title: "误导入目录", subtitle: "PPTX", sourceURL: directoryPPTXURL)
        var presentFrontDeckInvocationCount = 0
        var stopInvocationCount = 0
        var invalidDeckURL: URL?
        viewModel.programActivationSideEffects.presentActiveDeck = {
            presentFrontDeckInvocationCount += 1
        }
        viewModel.programActivationSideEffects.stopDeck = {
            stopInvocationCount += 1
        }
        viewModel.programActivationSideEffects.presentInvalidDeckAlert = { url in
            invalidDeckURL = url
        }

        viewModel.switchToProgram(activeDeckItem)
        viewModel.switchToProgram(directoryPPTXItem)

        XCTAssertEqual(viewModel.currentProgramItem, activeDeckItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertEqual(presentFrontDeckInvocationCount, 1)
        XCTAssertEqual(stopInvocationCount, 0)
        XCTAssertEqual(invalidDeckURL, directoryPPTXURL)
    }


    func testMultiStepProgramSwitchWhileBroadcastingReusesSingleOutputWindowController() throws {
        let viewModel = makeViewModel()
        let outputSpy = SwitcherViewModelSmokeOutputWindowControllerSpy()
        let videoURL = try makeTempFileURL(ext: "mp4")
        let htmlURL = try makeTempFileURL(ext: "html")
        let secondVideoURL = try makeTempFileURL(ext: "mp4")
        defer {
            try? FileManager.default.removeItem(at: videoURL)
            try? FileManager.default.removeItem(at: htmlURL)
            try? FileManager.default.removeItem(at: secondVideoURL)
        }

        var presentFrontDeckInvocationCount = 0
        viewModel.outputWindowControllerFactory = { outputSpy }
        viewModel.programActivationSideEffects.presentActiveDeck = {
            presentFrontDeckInvocationCount += 1
        }

        let openingVideo = ProgramItem(title: "片头", subtitle: "MP4", sourceURL: videoURL)
        let htmlItem = ProgramItem(title: "签到页", subtitle: "HTML", sourceURL: htmlURL)
        let activeDeckItem = ProgramItem(title: "主持稿", subtitle: "KEY (活动)", sourceURL: nil)
        let closingVideo = ProgramItem(title: "片尾", subtitle: "MP4", sourceURL: secondVideoURL)

        viewModel.switchToProgram(openingVideo)
        viewModel.handleBroadcastToggle()
        viewModel.switchToProgram(htmlItem)
        viewModel.switchToProgram(activeDeckItem)
        viewModel.switchToProgram(closingVideo)

        XCTAssertEqual(viewModel.currentProgramItem, closingVideo)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertEqual(viewModel.avCoordinator.currentURL, secondVideoURL)
        XCTAssertTrue(viewModel.avCoordinator.isPlaying)
        XCTAssertTrue(viewModel.isBroadcasting)
        XCTAssertEqual(presentFrontDeckInvocationCount, 1)
        XCTAssertEqual(outputSpy.mountCount, 1)
        XCTAssertEqual(outputSpy.showCount, 1)
        XCTAssertEqual(outputSpy.hideCount, 0)
    }


    func testPlaybackEndedAfterMultiStepProgramSwitchKeepsOutputWindowVisible() throws {
        let viewModel = makeViewModel()
        let outputSpy = SwitcherViewModelSmokeOutputWindowControllerSpy()
        let openingVideoURL = try makeTempFileURL(ext: "mp4")
        let htmlURL = try makeTempFileURL(ext: "html")
        let closingVideoURL = try makeTempFileURL(ext: "mp4")
        let wallpaperURL = try makeWallpaperURL()
        defer {
            try? FileManager.default.removeItem(at: openingVideoURL)
            try? FileManager.default.removeItem(at: htmlURL)
            try? FileManager.default.removeItem(at: closingVideoURL)
            try? FileManager.default.removeItem(at: wallpaperURL)
        }

        viewModel.outputWindowControllerFactory = { outputSpy }
        viewModel.addWallpaper(url: wallpaperURL)
        viewModel.setActiveWallpaper(url: wallpaperURL)

        let openingVideo = ProgramItem(title: "片头", subtitle: "MP4", sourceURL: openingVideoURL)
        let htmlItem = ProgramItem(title: "签到页", subtitle: "HTML", sourceURL: htmlURL)
        let closingVideo = ProgramItem(title: "片尾", subtitle: "MP4", sourceURL: closingVideoURL)

        viewModel.switchToProgram(openingVideo)
        viewModel.handleBroadcastToggle()
        viewModel.switchToProgram(htmlItem)
        viewModel.switchToProgram(closingVideo)

        viewModel.avCoordinator.isPlaying = false
        viewModel.avCoordinator.didPlayToEnd = true
        viewModel.avCoordinator.onPlaybackEnded?()

        XCTAssertNil(viewModel.currentProgramItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertTrue(viewModel.avCoordinator.didPlayToEnd)
        XCTAssertNotNil(viewModel.backgroundImage)
        XCTAssertTrue(viewModel.isBroadcasting)
        XCTAssertEqual(outputSpy.mountCount, 1)
        XCTAssertEqual(outputSpy.showCount, 1)
        XCTAssertEqual(outputSpy.hideCount, 0)
    }


    func testEndingHTMLAfterBroadcastedProgramSwitchKeepsOutputWindowVisible() throws {
        let viewModel = makeViewModel()
        let outputSpy = SwitcherViewModelSmokeOutputWindowControllerSpy()
        let videoURL = try makeTempFileURL(ext: "mp4")
        let htmlURL = try makeTempFileURL(ext: "html")
        let wallpaperURL = try makeWallpaperURL()
        defer {
            try? FileManager.default.removeItem(at: videoURL)
            try? FileManager.default.removeItem(at: htmlURL)
            try? FileManager.default.removeItem(at: wallpaperURL)
        }

        viewModel.outputWindowControllerFactory = { outputSpy }
        viewModel.addWallpaper(url: wallpaperURL)
        viewModel.setActiveWallpaper(url: wallpaperURL)

        let videoItem = ProgramItem(title: "片头", subtitle: "MP4", sourceURL: videoURL)
        let htmlItem = ProgramItem(title: "签到页", subtitle: "HTML", sourceURL: htmlURL)

        viewModel.switchToProgram(videoItem)
        viewModel.handleBroadcastToggle()
        viewModel.switchToProgram(htmlItem)

        viewModel.endHTMLPresentation()

        XCTAssertNil(viewModel.currentProgramItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertNotNil(viewModel.backgroundImage)
        XCTAssertTrue(viewModel.isBroadcasting)
        XCTAssertEqual(outputSpy.mountCount, 1)
        XCTAssertEqual(outputSpy.showCount, 1)
        XCTAssertEqual(outputSpy.hideCount, 0)
    }


    func testRemovingCurrentActiveDeckAfterProgramSwitchKeepsOutputWindowVisible() throws {
        let viewModel = makeViewModel()
        let outputSpy = SwitcherViewModelSmokeOutputWindowControllerSpy()
        let videoURL = try makeTempFileURL(ext: "mp4")
        defer { try? FileManager.default.removeItem(at: videoURL) }

        viewModel.outputWindowControllerFactory = { outputSpy }
        let videoItem = ProgramItem(title: "片头", subtitle: "MP4", sourceURL: videoURL)
        let activeDeckItem = ProgramItem(title: "主持稿", subtitle: "KEY (活动)", sourceURL: nil)
        viewModel.addProgramItem(videoItem)
        viewModel.addProgramItem(activeDeckItem)

        viewModel.switchToProgram(videoItem)
        viewModel.handleBroadcastToggle()
        viewModel.switchToProgram(activeDeckItem)

        viewModel.removeProgramItem(withID: activeDeckItem.id)

        XCTAssertNil(viewModel.currentProgramItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertTrue(viewModel.isBroadcasting)
        XCTAssertEqual(viewModel.programItems, [videoItem])
        XCTAssertEqual(outputSpy.mountCount, 1)
        XCTAssertEqual(outputSpy.showCount, 1)
        XCTAssertEqual(outputSpy.hideCount, 0)
    }

}
