import AppKit
import SwiftUI
import XCTest
@testable import LiveSwitcher

@MainActor
final class SwitcherViewModelProgramQueueSmokeTests: SwitcherViewModelSmokeTestCase {
    func testMoveProgramItemsDoesNotInterruptCurrentProgramState() throws {
        let viewModel = makeViewModel()
        let firstURL = try makeTempFileURL(ext: "mp4")
        let secondURL = try makeTempFileURL(ext: "mp4")
        let thirdURL = try makeTempFileURL(ext: "mp4")
        defer {
            try? FileManager.default.removeItem(at: firstURL)
            try? FileManager.default.removeItem(at: secondURL)
            try? FileManager.default.removeItem(at: thirdURL)
        }

        let firstItem = ProgramItem(title: "A", subtitle: "MP4", sourceURL: firstURL)
        let secondItem = ProgramItem(title: "B", subtitle: "MP4", sourceURL: secondURL)
        let thirdItem = ProgramItem(title: "C", subtitle: "MP4", sourceURL: thirdURL)
        viewModel.addProgramItem(firstItem)
        viewModel.addProgramItem(secondItem)
        viewModel.addProgramItem(thirdItem)

        viewModel.switchToProgram(secondItem)
        XCTAssertEqual(viewModel.currentProgramItem, secondItem)
        XCTAssertEqual(viewModel.avCoordinator.currentURL, secondURL)
        XCTAssertTrue(viewModel.avCoordinator.isPlaying)

        viewModel.moveProgramItems(from: IndexSet(integer: 2), to: 0)

        XCTAssertEqual(viewModel.currentProgramItem, secondItem)
        XCTAssertEqual(viewModel.avCoordinator.currentURL, secondURL)
        XCTAssertTrue(viewModel.avCoordinator.isPlaying)
        XCTAssertEqual(viewModel.programItems, [thirdItem, firstItem, secondItem])
    }


    func testMoveProgramItemsDoesNotInterruptCurrentHTMLPresentationState() throws {
        let viewModel = makeViewModel()
        let htmlURL = try makeTempFileURL(ext: "html")
        let videoURL = try makeTempFileURL(ext: "mp4")
        let secondHTMLURL = try makeTempFileURL(ext: "html")
        defer {
            try? FileManager.default.removeItem(at: htmlURL)
            try? FileManager.default.removeItem(at: videoURL)
            try? FileManager.default.removeItem(at: secondHTMLURL)
        }

        let currentItem = ProgramItem(title: "签到页", subtitle: "HTML", sourceURL: htmlURL)
        let middleItem = ProgramItem(title: "片头", subtitle: "MP4", sourceURL: videoURL)
        let lastItem = ProgramItem(title: "主视觉", subtitle: "HTML", sourceURL: secondHTMLURL)
        viewModel.addProgramItem(currentItem)
        viewModel.addProgramItem(middleItem)
        viewModel.addProgramItem(lastItem)
        viewModel.isBroadcasting = true
        viewModel.switchToProgram(currentItem)

        viewModel.moveProgramItems(from: IndexSet(integer: 2), to: 0)

        XCTAssertEqual(viewModel.currentProgramItem, currentItem)
        XCTAssertEqual(viewModel.currentHTMLURL, htmlURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertTrue(viewModel.isBroadcasting)
        XCTAssertEqual(viewModel.programItems, [lastItem, currentItem, middleItem])
    }


    func testMoveProgramItemsDoesNotInterruptCurrentActiveDeckPresentationState() throws {
        let viewModel = makeViewModel()
        let videoURL = try makeTempFileURL(ext: "mp4")
        defer { try? FileManager.default.removeItem(at: videoURL) }

        var presentFrontDeckInvocationCount = 0
        viewModel.programActivationSideEffects.presentActiveDeck = {
            presentFrontDeckInvocationCount += 1
        }

        let activeDeckItem = ProgramItem(title: "主持稿", subtitle: "KEY (活动)", sourceURL: nil)
        let videoItem = ProgramItem(title: "片头", subtitle: "MP4", sourceURL: videoURL)
        let standbyDeckItem = ProgramItem(title: "副主持稿", subtitle: "KEY (活动)", sourceURL: nil)
        viewModel.addProgramItem(activeDeckItem)
        viewModel.addProgramItem(videoItem)
        viewModel.addProgramItem(standbyDeckItem)
        viewModel.isBroadcasting = true
        viewModel.switchToProgram(activeDeckItem)

        viewModel.moveProgramItems(from: IndexSet(integer: 2), to: 0)

        XCTAssertEqual(viewModel.currentProgramItem, activeDeckItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertTrue(viewModel.isBroadcasting)
        XCTAssertEqual(presentFrontDeckInvocationCount, 1)
        XCTAssertEqual(viewModel.programItems, [standbyDeckItem, activeDeckItem, videoItem])
    }


    func testSwitchToProgramAtSupportsHTMLBranch() throws {
        let viewModel = makeViewModel()
        let videoURL = try makeTempFileURL(ext: "mp4")
        let htmlURL = try makeTempFileURL(ext: "html")
        defer {
            try? FileManager.default.removeItem(at: videoURL)
            try? FileManager.default.removeItem(at: htmlURL)
        }

        let videoItem = ProgramItem(title: "片头", subtitle: "MP4", sourceURL: videoURL)
        let htmlItem = ProgramItem(title: "签到页", subtitle: "HTML", sourceURL: htmlURL)
        viewModel.addProgramItem(videoItem)
        viewModel.addProgramItem(htmlItem)

        viewModel.switchToProgram(at: 0)
        XCTAssertEqual(viewModel.currentProgramItem, videoItem)
        XCTAssertEqual(viewModel.avCoordinator.currentURL, videoURL)
        XCTAssertTrue(viewModel.avCoordinator.isPlaying)

        viewModel.switchToProgram(at: 1)

        XCTAssertEqual(viewModel.currentProgramItem, htmlItem)
        XCTAssertEqual(viewModel.currentHTMLURL, htmlURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
    }


    func testSwitchToProgramAtSupportsDeckBranch() throws {
        let viewModel = makeViewModel()
        let videoURL = try makeTempFileURL(ext: "mp4")
        let keynoteURL = try makeTempFileURL(ext: "key")
        defer {
            try? FileManager.default.removeItem(at: videoURL)
            try? FileManager.default.removeItem(at: keynoteURL)
        }

        var presentedURL: URL?
        viewModel.programActivationSideEffects.presentKeynote = { url in
            presentedURL = url
        }

        let videoItem = ProgramItem(title: "片头", subtitle: "MP4", sourceURL: videoURL)
        let keynoteItem = ProgramItem(title: "主持稿", subtitle: "KEY", sourceURL: keynoteURL)
        viewModel.addProgramItem(videoItem)
        viewModel.addProgramItem(keynoteItem)

        viewModel.switchToProgram(at: 0)
        XCTAssertEqual(viewModel.currentProgramItem, videoItem)
        XCTAssertEqual(viewModel.avCoordinator.currentURL, videoURL)
        XCTAssertTrue(viewModel.avCoordinator.isPlaying)

        viewModel.switchToProgram(at: 1)

        XCTAssertEqual(viewModel.currentProgramItem, keynoteItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertEqual(presentedURL, keynoteURL)
    }


    func testSwitchToProgramAtSupportsActiveDeckBranchWithoutSourceURL() throws {
        let viewModel = makeViewModel()
        let videoURL = try makeTempFileURL(ext: "mp4")
        defer { try? FileManager.default.removeItem(at: videoURL) }

        var presentFrontDeckInvocationCount = 0
        viewModel.programActivationSideEffects.presentActiveDeck = {
            presentFrontDeckInvocationCount += 1
        }

        let videoItem = ProgramItem(title: "片头", subtitle: "MP4", sourceURL: videoURL)
        let activeDeckItem = ProgramItem(title: "主持稿", subtitle: "KEY (活动)", sourceURL: nil)
        viewModel.addProgramItem(videoItem)
        viewModel.addProgramItem(activeDeckItem)

        viewModel.switchToProgram(at: 0)
        XCTAssertEqual(viewModel.currentProgramItem, videoItem)
        XCTAssertEqual(viewModel.avCoordinator.currentURL, videoURL)
        XCTAssertTrue(viewModel.avCoordinator.isPlaying)

        viewModel.switchToProgram(at: 1)

        XCTAssertEqual(viewModel.currentProgramItem, activeDeckItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertEqual(presentFrontDeckInvocationCount, 1)
    }


    func testSwitchToProgramAtWhileBroadcastingDoesNotReopenOutputWindowForHTMLBranch() throws {
        let viewModel = makeViewModel()
        let outputSpy = SwitcherViewModelSmokeOutputWindowControllerSpy()
        let videoURL = try makeTempFileURL(ext: "mp4")
        let htmlURL = try makeTempFileURL(ext: "html")
        defer {
            try? FileManager.default.removeItem(at: videoURL)
            try? FileManager.default.removeItem(at: htmlURL)
        }

        viewModel.outputWindowControllerFactory = { outputSpy }
        let videoItem = ProgramItem(title: "片头", subtitle: "MP4", sourceURL: videoURL)
        let htmlItem = ProgramItem(title: "签到页", subtitle: "HTML", sourceURL: htmlURL)
        viewModel.addProgramItem(videoItem)
        viewModel.addProgramItem(htmlItem)

        viewModel.switchToProgram(at: 0)
        viewModel.handleBroadcastToggle()
        XCTAssertEqual(outputSpy.mountCount, 1)
        XCTAssertEqual(outputSpy.showCount, 1)

        viewModel.switchToProgram(at: 1)

        XCTAssertEqual(viewModel.currentProgramItem, htmlItem)
        XCTAssertEqual(viewModel.currentHTMLURL, htmlURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertTrue(viewModel.isBroadcasting)
        XCTAssertEqual(outputSpy.mountCount, 1)
        XCTAssertEqual(outputSpy.showCount, 1)
        XCTAssertEqual(outputSpy.hideCount, 0)
    }


    func testSwitchToProgramAtWhileBroadcastingDoesNotReopenOutputWindowForActiveDeckBranch() throws {
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
        viewModel.addProgramItem(videoItem)
        viewModel.addProgramItem(activeDeckItem)

        viewModel.switchToProgram(at: 0)
        viewModel.handleBroadcastToggle()
        XCTAssertEqual(outputSpy.mountCount, 1)
        XCTAssertEqual(outputSpy.showCount, 1)

        viewModel.switchToProgram(at: 1)

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

}
