import AppKit
import SwiftUI
import XCTest
@testable import LiveSwitcher

@MainActor
final class SwitcherViewModelProgramIndexSmokeTests: SwitcherViewModelSmokeTestCase {
    func testSwitchToProgramAtUsesIndexedProgramItemAndIgnoresInvalidIndex() throws {
        let viewModel = makeViewModel()
        let firstURL = try makeTempFileURL(ext: "mp4")
        let secondURL = try makeTempFileURL(ext: "mp4")
        defer {
            try? FileManager.default.removeItem(at: firstURL)
            try? FileManager.default.removeItem(at: secondURL)
        }

        let firstItem = ProgramItem(title: "片头", subtitle: "MP4", sourceURL: firstURL)
        let secondItem = ProgramItem(title: "正片", subtitle: "MP4", sourceURL: secondURL)
        viewModel.addProgramItem(firstItem)
        viewModel.addProgramItem(secondItem)

        viewModel.switchToProgram(at: 1)

        XCTAssertEqual(viewModel.currentProgramItem, secondItem)
        XCTAssertEqual(viewModel.avCoordinator.currentURL, secondURL)
        XCTAssertTrue(viewModel.avCoordinator.isPlaying)

        viewModel.switchToProgram(at: 9)
        XCTAssertEqual(viewModel.currentProgramItem, secondItem)
        XCTAssertEqual(viewModel.avCoordinator.currentURL, secondURL)

        viewModel.switchToProgram(at: -1)
        XCTAssertEqual(viewModel.currentProgramItem, secondItem)
        XCTAssertEqual(viewModel.avCoordinator.currentURL, secondURL)
    }


    func testSwitchToProgramAtInvalidIndexDoesNotInterruptCurrentHTMLPresentation() throws {
        let viewModel = makeViewModel()
        let htmlURL = try makeTempFileURL(ext: "html")
        defer { try? FileManager.default.removeItem(at: htmlURL) }

        let htmlItem = ProgramItem(title: "签到页", subtitle: "HTML", sourceURL: htmlURL)
        viewModel.addProgramItem(htmlItem)
        viewModel.isBroadcasting = true
        viewModel.switchToProgram(htmlItem)

        viewModel.switchToProgram(at: 9)

        XCTAssertEqual(viewModel.currentProgramItem, htmlItem)
        XCTAssertEqual(viewModel.currentHTMLURL, htmlURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertTrue(viewModel.isBroadcasting)
    }


    func testSwitchToProgramAtInvalidIndexDoesNotInterruptCurrentActiveDeckPresentation() {
        let viewModel = makeViewModel()
        let activeDeckItem = ProgramItem(title: "主持稿", subtitle: "KEY (活动)", sourceURL: nil)
        var presentFrontDeckInvocationCount = 0
        viewModel.programActivationSideEffects.presentActiveDeck = {
            presentFrontDeckInvocationCount += 1
        }

        viewModel.addProgramItem(activeDeckItem)
        viewModel.switchToProgram(activeDeckItem)
        XCTAssertEqual(presentFrontDeckInvocationCount, 1)

        viewModel.switchToProgram(at: 2)

        XCTAssertEqual(viewModel.currentProgramItem, activeDeckItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertEqual(presentFrontDeckInvocationCount, 1)
    }


    func testSwitchToProgramAtInvalidIndexIsNoOpWhenProgramListIsEmpty() {
        let viewModel = makeViewModel()

        XCTAssertTrue(viewModel.programItems.isEmpty)
        XCTAssertNil(viewModel.currentProgramItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)

        viewModel.switchToProgram(at: 0)

        XCTAssertTrue(viewModel.programItems.isEmpty)
        XCTAssertNil(viewModel.currentProgramItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
    }


    func testSeekProgramItemToStartOnlyTargetsCurrentProgram() throws {
        let viewModel = makeViewModel()
        let currentURL = try makeTempFileURL(ext: "mp4")
        let otherURL = try makeTempFileURL(ext: "mp4")
        defer {
            try? FileManager.default.removeItem(at: currentURL)
            try? FileManager.default.removeItem(at: otherURL)
        }

        let currentItem = ProgramItem(title: "当前节目", subtitle: "MP4", sourceURL: currentURL)
        let otherItem = ProgramItem(title: "其他节目", subtitle: "MP4", sourceURL: otherURL)
        let actionLogCount = viewModel.runtime.actionLog.count

        viewModel.switchToProgram(currentItem)
        viewModel.seekProgramItemToStart(otherItem)

        viewModel.seekProgramItemToStart(currentItem)
        XCTAssertTrue(
            viewModel.runtime.actionLog.dropFirst(actionLogCount).contains {
                $0.actionName == "operatorSeekedCurrentMediaToStart"
            }
        )
        XCTAssertEqual(viewModel.currentProgramItem, currentItem)
    }


    func testSeekProgramItemToEndOnlyTargetsCurrentProgram() throws {
        let viewModel = makeViewModel()
        let currentURL = try makeTempFileURL(ext: "mp4")
        let otherURL = try makeTempFileURL(ext: "mp4")
        defer {
            try? FileManager.default.removeItem(at: currentURL)
            try? FileManager.default.removeItem(at: otherURL)
        }

        let currentItem = ProgramItem(title: "当前节目", subtitle: "MP4", sourceURL: currentURL)
        let otherItem = ProgramItem(title: "其他节目", subtitle: "MP4", sourceURL: otherURL)
        let actionLogCount = viewModel.runtime.actionLog.count

        viewModel.switchToProgram(currentItem)
        viewModel.seekProgramItemToEnd(otherItem)

        viewModel.seekProgramItemToEnd(currentItem)
        XCTAssertTrue(
            viewModel.runtime.actionLog.dropFirst(actionLogCount).contains {
                $0.actionName == "operatorSeekedCurrentMediaToEnd"
            }
        )
        XCTAssertEqual(viewModel.currentProgramItem, currentItem)
    }


    func testSeekProgramItemToStartIsNoOpForCurrentHTMLProgram() throws {
        let viewModel = makeViewModel()
        let htmlURL = try makeTempFileURL(ext: "html")
        defer { try? FileManager.default.removeItem(at: htmlURL) }

        let htmlItem = ProgramItem(title: "签到页", subtitle: "HTML", sourceURL: htmlURL)

        viewModel.switchToProgram(htmlItem)
        viewModel.seekProgramItemToStart(htmlItem)

        XCTAssertEqual(viewModel.currentProgramItem, htmlItem)
        XCTAssertEqual(viewModel.currentHTMLURL, htmlURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
    }


    func testSeekProgramItemToEndIsNoOpForCurrentDeckProgram() throws {
        let viewModel = makeViewModel()
        let keynoteURL = try makeTempFileURL(ext: "key")
        defer { try? FileManager.default.removeItem(at: keynoteURL) }

        let keynoteItem = ProgramItem(title: "主持稿", subtitle: "KEY", sourceURL: keynoteURL)
        viewModel.programActivationSideEffects.presentKeynote = { _ in }

        viewModel.switchToProgram(keynoteItem)
        viewModel.seekProgramItemToEnd(keynoteItem)

        XCTAssertEqual(viewModel.currentProgramItem, keynoteItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
    }


    func testRemovingNonCurrentProgramDoesNotInterruptCurrentPlayback() throws {
        let viewModel = makeViewModel()
        let currentURL = try makeTempFileURL(ext: "mp4")
        let otherURL = try makeTempFileURL(ext: "mp4")
        defer {
            try? FileManager.default.removeItem(at: currentURL)
            try? FileManager.default.removeItem(at: otherURL)
        }

        let currentItem = ProgramItem(title: "当前节目", subtitle: "MP4", sourceURL: currentURL)
        let otherItem = ProgramItem(title: "待删节目", subtitle: "MP4", sourceURL: otherURL)
        viewModel.addProgramItem(currentItem)
        viewModel.addProgramItem(otherItem)
        viewModel.switchToProgram(currentItem)

        viewModel.removeProgramItem(withID: otherItem.id)

        XCTAssertEqual(viewModel.currentProgramItem, currentItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertEqual(viewModel.avCoordinator.currentURL, currentURL)
        XCTAssertTrue(viewModel.avCoordinator.isPlaying)
        XCTAssertEqual(viewModel.programItems, [currentItem])
    }


    func testRemovingUnknownProgramIDDoesNotInterruptCurrentHTMLPresentation() throws {
        let viewModel = makeViewModel()
        let htmlURL = try makeTempFileURL(ext: "html")
        defer { try? FileManager.default.removeItem(at: htmlURL) }

        let htmlItem = ProgramItem(title: "签到页", subtitle: "HTML", sourceURL: htmlURL)
        viewModel.addProgramItem(htmlItem)
        viewModel.isBroadcasting = true
        viewModel.switchToProgram(htmlItem)

        viewModel.removeProgramItem(withID: UUID())

        XCTAssertEqual(viewModel.currentProgramItem, htmlItem)
        XCTAssertEqual(viewModel.currentHTMLURL, htmlURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertEqual(viewModel.programItems, [htmlItem])
        XCTAssertTrue(viewModel.isBroadcasting)
    }


    func testRemovingNonCurrentHTMLProgramDoesNotInterruptCurrentVideoPlayback() throws {
        let viewModel = makeViewModel()
        let videoURL = try makeTempFileURL(ext: "mp4")
        let htmlURL = try makeTempFileURL(ext: "html")
        defer {
            try? FileManager.default.removeItem(at: videoURL)
            try? FileManager.default.removeItem(at: htmlURL)
        }

        let currentItem = ProgramItem(title: "当前节目", subtitle: "MP4", sourceURL: videoURL)
        let htmlItem = ProgramItem(title: "签到页", subtitle: "HTML", sourceURL: htmlURL)
        viewModel.addProgramItem(currentItem)
        viewModel.addProgramItem(htmlItem)
        viewModel.switchToProgram(currentItem)

        viewModel.removeProgramItem(withID: htmlItem.id)

        XCTAssertEqual(viewModel.currentProgramItem, currentItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertEqual(viewModel.avCoordinator.currentURL, videoURL)
        XCTAssertTrue(viewModel.avCoordinator.isPlaying)
        XCTAssertEqual(viewModel.programItems, [currentItem])
    }


    func testRemovingNonCurrentDeckProgramDoesNotInterruptCurrentHTMLPresentation() throws {
        let viewModel = makeViewModel()
        let htmlURL = try makeTempFileURL(ext: "html")
        let keynoteURL = try makeTempFileURL(ext: "key")
        defer {
            try? FileManager.default.removeItem(at: htmlURL)
            try? FileManager.default.removeItem(at: keynoteURL)
        }

        let currentItem = ProgramItem(title: "签到页", subtitle: "HTML", sourceURL: htmlURL)
        let deckItem = ProgramItem(title: "主持稿", subtitle: "KEY", sourceURL: keynoteURL)
        viewModel.addProgramItem(currentItem)
        viewModel.addProgramItem(deckItem)
        viewModel.isBroadcasting = true
        viewModel.switchToProgram(currentItem)

        viewModel.removeProgramItem(withID: deckItem.id)

        XCTAssertEqual(viewModel.currentProgramItem, currentItem)
        XCTAssertEqual(viewModel.currentHTMLURL, htmlURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertEqual(viewModel.programItems, [currentItem])
        XCTAssertTrue(viewModel.isBroadcasting)
    }


    func testRemovingCurrentActiveDeckItemReturnsToIdleState() throws {
        let viewModel = makeViewModel()
        let videoURL = try makeTempFileURL(ext: "mp4")
        defer { try? FileManager.default.removeItem(at: videoURL) }

        let videoItem = ProgramItem(title: "片头", subtitle: "MP4", sourceURL: videoURL)
        let activeDeckItem = ProgramItem(title: "主持稿", subtitle: "KEY (活动)", sourceURL: nil)
        viewModel.addProgramItem(activeDeckItem)
        viewModel.addProgramItem(videoItem)

        viewModel.switchToProgram(activeDeckItem)
        XCTAssertEqual(viewModel.currentProgramItem, activeDeckItem)
        XCTAssertNil(viewModel.avCoordinator.currentURL)

        viewModel.removeProgramItem(withID: activeDeckItem.id)

        XCTAssertNil(viewModel.currentProgramItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertEqual(viewModel.programItems, [videoItem])
    }


    func testRemovingCurrentActiveDeckStopsDeckPresentation() throws {
        let viewModel = makeViewModel()
        let activeDeckItem = ProgramItem(title: "主持稿", subtitle: "KEY (活动)", sourceURL: nil)
        var presentFrontDeckInvocationCount = 0
        var stopInvocationCount = 0
        viewModel.programActivationSideEffects.presentActiveDeck = {
            presentFrontDeckInvocationCount += 1
        }
        viewModel.programActivationSideEffects.stopDeck = {
            stopInvocationCount += 1
        }
        viewModel.addProgramItem(activeDeckItem)
        viewModel.switchToProgram(activeDeckItem)

        viewModel.removeProgramItem(withID: activeDeckItem.id)

        XCTAssertNil(viewModel.currentProgramItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertEqual(presentFrontDeckInvocationCount, 1)
        XCTAssertEqual(stopInvocationCount, 1)
    }


    func testRemovingCurrentActiveDeckWhileBroadcastingDoesNotHideOutputWindow() throws {
        let viewModel = makeViewModel()
        let outputSpy = SwitcherViewModelSmokeOutputWindowControllerSpy()
        let videoURL = try makeTempFileURL(ext: "mp4")
        defer { try? FileManager.default.removeItem(at: videoURL) }

        viewModel.outputWindowControllerFactory = { outputSpy }
        let activeDeckItem = ProgramItem(title: "主持稿", subtitle: "KEY (活动)", sourceURL: nil)
        let standbyVideoItem = ProgramItem(title: "片头", subtitle: "MP4", sourceURL: videoURL)
        viewModel.addProgramItem(activeDeckItem)
        viewModel.addProgramItem(standbyVideoItem)
        viewModel.switchToProgram(activeDeckItem)
        viewModel.handleBroadcastToggle()

        viewModel.removeProgramItem(withID: activeDeckItem.id)

        XCTAssertNil(viewModel.currentProgramItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertTrue(viewModel.isBroadcasting)
        XCTAssertEqual(viewModel.programItems, [standbyVideoItem])
        XCTAssertEqual(outputSpy.showCount, 1)
        XCTAssertEqual(outputSpy.hideCount, 0)
    }


    func testRemovingCurrentVideoThenInvalidIndexKeepsIdleState() throws {
        let viewModel = makeViewModel()
        let videoURL = try makeTempFileURL(ext: "mp4")
        defer { try? FileManager.default.removeItem(at: videoURL) }

        let videoItem = ProgramItem(title: "片头", subtitle: "MP4", sourceURL: videoURL)
        viewModel.addProgramItem(videoItem)
        viewModel.switchToProgram(videoItem)

        viewModel.removeProgramItem(withID: videoItem.id)
        viewModel.switchToProgram(at: 0)

        XCTAssertTrue(viewModel.programItems.isEmpty)
        XCTAssertNil(viewModel.currentProgramItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
    }


    func testRemovingCurrentHTMLThenInvalidIndexKeepsWallpaperFallbackState() throws {
        let viewModel = makeViewModel()
        let htmlURL = try makeTempFileURL(ext: "html")
        let wallpaperURL = try makeWallpaperURL()
        defer {
            try? FileManager.default.removeItem(at: htmlURL)
            try? FileManager.default.removeItem(at: wallpaperURL)
        }

        viewModel.addWallpaper(url: wallpaperURL)
        viewModel.setActiveWallpaper(url: wallpaperURL)

        let htmlItem = ProgramItem(title: "签到页", subtitle: "HTML", sourceURL: htmlURL)
        viewModel.addProgramItem(htmlItem)
        viewModel.isBroadcasting = true
        viewModel.switchToProgram(htmlItem)

        viewModel.removeProgramItem(withID: htmlItem.id)
        viewModel.switchToProgram(at: 0)

        XCTAssertTrue(viewModel.programItems.isEmpty)
        XCTAssertNil(viewModel.currentProgramItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertNotNil(viewModel.backgroundImage)
        XCTAssertTrue(viewModel.isBroadcasting)
    }

}
