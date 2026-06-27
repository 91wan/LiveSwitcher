import AppKit
import SwiftUI
import XCTest
@testable import LiveSwitcher

@MainActor
final class SwitcherViewModelProjectionSmokeTests: SwitcherViewModelSmokeTestCase {
    func testBroadcastToggleShowsAndHidesOutputWindowThroughController() {
        let viewModel = makeViewModel()
        let outputSpy = SwitcherViewModelSmokeOutputWindowControllerSpy()

        viewModel.outputWindowControllerFactory = { outputSpy }

        viewModel.handleBroadcastToggle()
        XCTAssertTrue(viewModel.isBroadcasting)
        XCTAssertEqual(outputSpy.mountCount, 1)
        XCTAssertEqual(outputSpy.showCount, 1)
        XCTAssertFalse(outputSpy.lastShowScreenWasNil)

        viewModel.handleBroadcastToggle()
        XCTAssertFalse(viewModel.isBroadcasting)
        XCTAssertEqual(outputSpy.hideCount, 1)
        XCTAssertEqual(outputSpy.mountCount, 1)
    }


    func testExternalDisplayLossStopsBroadcastAndKeepsCurrentProgram() throws {
        let viewModel = makeViewModel()
        let outputSpy = SwitcherViewModelSmokeOutputWindowControllerSpy()
        let videoURL = try makeTempFileURL(ext: "mp4")
        defer { try? FileManager.default.removeItem(at: videoURL) }

        viewModel.outputWindowControllerFactory = { outputSpy }
        let videoItem = ProgramItem(title: "开场视频", subtitle: "MP4", sourceURL: videoURL)
        viewModel.switchToProgram(videoItem)
        viewModel.handleBroadcastToggle()

        viewModel.handleExternalDisplayLost()

        XCTAssertFalse(viewModel.isBroadcasting)
        XCTAssertEqual(viewModel.currentProgramItem, videoItem)
        XCTAssertEqual(viewModel.avCoordinator.currentURL, videoURL)
        XCTAssertTrue(viewModel.avCoordinator.isPlaying)
        XCTAssertEqual(outputSpy.hideCount, 1)
        XCTAssertEqual(viewModel.broadcastSafetyNotice, "副屏已断开，投射已停止")
    }


    func testBroadcastToggleWithoutExternalDisplayFailsClosedBeforeCreatingOutputWindow() {
        let viewModel = makeViewModel()
        var factoryInvocationCount = 0
        viewModel.externalScreenProvider = { nil }
        viewModel.outputWindowControllerFactory = {
            factoryInvocationCount += 1
            return SwitcherViewModelSmokeOutputWindowControllerSpy()
        }

        viewModel.handleBroadcastToggle()

        XCTAssertFalse(viewModel.isBroadcasting)
        XCTAssertEqual(factoryInvocationCount, 0)
        XCTAssertEqual(viewModel.broadcastSafetyNotice, "未检测到外接屏幕，未开始投射")
    }


    func testExternalDisplayUnavailableStopsProjectionThroughRuntime() {
        let viewModel = makeViewModel()
        let outputSpy = SwitcherViewModelSmokeOutputWindowControllerSpy()
        viewModel.outputWindowControllerFactory = { outputSpy }

        viewModel.handleBroadcastToggle()
        XCTAssertTrue(viewModel.isBroadcasting)

        viewModel.externalScreenProvider = { nil }

        XCTAssertFalse(viewModel.isBroadcasting)
        XCTAssertEqual(outputSpy.hideCount, 1)
        XCTAssertEqual(viewModel.broadcastSafetyNotice, "副屏已断开，投射已停止")
    }


    func testSafeBroadcastToggleRecordsStartFailureWhenDisplayDisappearsBeforeShow() {
        let viewModel = makeViewModel()
        var providerCalls = 0
        viewModel.externalScreenProvider = {
            providerCalls += 1
            return providerCalls == 1 ? (NSScreen.main ?? NSScreen.screens.first) : nil
        }

        viewModel.handleSafeBroadcastToggle()

        let kinds = viewModel.supportEvents.map(\.kind)
        XCTAssertFalse(viewModel.isBroadcasting)
        XCTAssertTrue(kinds.contains(.projectionStartFailed))
        XCTAssertFalse(kinds.contains(.projectionLost))
        XCTAssertFalse(kinds.contains(.projectionStarted))
    }


    func testBroadcastToggleRecordsStartFailureWhenDisplayDisappearsBeforeShow() {
        let viewModel = makeViewModel()
        var providerCalls = 0
        viewModel.externalScreenProvider = {
            providerCalls += 1
            return providerCalls == 1 ? (NSScreen.main ?? NSScreen.screens.first) : nil
        }

        viewModel.handleBroadcastToggle()

        let kinds = viewModel.supportEvents.map(\.kind)
        XCTAssertFalse(viewModel.isBroadcasting)
        XCTAssertTrue(kinds.contains(.projectionStartFailed))
        XCTAssertFalse(kinds.contains(.projectionLost))
        XCTAssertFalse(kinds.contains(.projectionStarted))
    }


    func testBroadcastToggleCycleDoesNotClearCurrentHTMLPresentationState() throws {
        let viewModel = makeViewModel()
        let outputSpy = SwitcherViewModelSmokeOutputWindowControllerSpy()
        let htmlURL = try makeTempFileURL(ext: "html")
        defer { try? FileManager.default.removeItem(at: htmlURL) }

        viewModel.outputWindowControllerFactory = { outputSpy }
        let htmlItem = ProgramItem(title: "签到页", subtitle: "HTML", sourceURL: htmlURL)
        viewModel.switchToProgram(htmlItem)

        viewModel.handleBroadcastToggle()
        viewModel.handleBroadcastToggle()

        XCTAssertEqual(viewModel.currentProgramItem, htmlItem)
        XCTAssertEqual(viewModel.currentHTMLURL, htmlURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertFalse(viewModel.isBroadcasting)
        XCTAssertEqual(outputSpy.showCount, 1)
        XCTAssertEqual(outputSpy.hideCount, 1)
    }


    func testBroadcastToggleCycleDoesNotClearCurrentActiveDeckPresentationState() {
        let viewModel = makeViewModel()
        let outputSpy = SwitcherViewModelSmokeOutputWindowControllerSpy()
        let activeDeckItem = ProgramItem(title: "主持稿", subtitle: "KEY (活动)", sourceURL: nil)
        var presentFrontDeckInvocationCount = 0

        viewModel.outputWindowControllerFactory = { outputSpy }
        viewModel.programActivationSideEffects.presentActiveDeck = {
            presentFrontDeckInvocationCount += 1
        }
        viewModel.switchToProgram(activeDeckItem)

        viewModel.handleBroadcastToggle()
        viewModel.handleBroadcastToggle()

        XCTAssertEqual(viewModel.currentProgramItem, activeDeckItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertFalse(viewModel.isBroadcasting)
        XCTAssertEqual(presentFrontDeckInvocationCount, 1)
        XCTAssertEqual(outputSpy.showCount, 1)
        XCTAssertEqual(outputSpy.hideCount, 1)
    }


    func testBroadcastToggleCycleDoesNotInterruptCurrentVideoPlaybackState() throws {
        let viewModel = makeViewModel()
        let outputSpy = SwitcherViewModelSmokeOutputWindowControllerSpy()
        let videoURL = try makeTempFileURL(ext: "mp4")
        defer { try? FileManager.default.removeItem(at: videoURL) }

        viewModel.outputWindowControllerFactory = { outputSpy }
        let videoItem = ProgramItem(title: "片头", subtitle: "MP4", sourceURL: videoURL)
        viewModel.switchToProgram(videoItem)

        viewModel.handleBroadcastToggle()
        viewModel.handleBroadcastToggle()

        XCTAssertEqual(viewModel.currentProgramItem, videoItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertEqual(viewModel.avCoordinator.currentURL, videoURL)
        XCTAssertTrue(viewModel.avCoordinator.isPlaying)
        XCTAssertFalse(viewModel.isBroadcasting)
        XCTAssertEqual(outputSpy.showCount, 1)
        XCTAssertEqual(outputSpy.hideCount, 1)
    }


    func testProjectionRuntimeStartReusesExistingControllerAcrossMultipleStarts() {
        let viewModel = makeViewModel()
        let outputSpy = SwitcherViewModelSmokeOutputWindowControllerSpy()
        var factoryInvocationCount = 0

        viewModel.outputWindowControllerFactory = {
            factoryInvocationCount += 1
            return outputSpy
        }

        viewModel.handleBroadcastToggle()
        viewModel.handleBroadcastToggle()
        viewModel.handleBroadcastToggle()

        XCTAssertEqual(factoryInvocationCount, 1)
        XCTAssertEqual(outputSpy.mountCount, 1)
        XCTAssertEqual(outputSpy.showCount, 2)
        XCTAssertEqual(outputSpy.hideCount, 1)
    }


    func testSwitchingToKeynoteStopsPreviousVideoAndInvokesPresentationHandler() throws {
        let viewModel = makeViewModel()
        let videoURL = try makeTempFileURL(ext: "mp4")
        let keynoteURL = try makeTempFileURL(ext: "key")
        let htmlURL = try makeTempFileURL(ext: "html")
        defer {
            try? FileManager.default.removeItem(at: videoURL)
            try? FileManager.default.removeItem(at: keynoteURL)
            try? FileManager.default.removeItem(at: htmlURL)
        }

        var presentedURL: URL?
        viewModel.programActivationSideEffects.presentKeynote = { url in
            presentedURL = url
        }

        let videoItem = ProgramItem(title: "开场视频", subtitle: "MP4", sourceURL: videoURL)
        let keynoteItem = ProgramItem(title: "主持稿", subtitle: "KEY", sourceURL: keynoteURL)

        viewModel.currentHTMLURL = htmlURL
        viewModel.switchToProgram(videoItem)
        XCTAssertEqual(viewModel.avCoordinator.currentURL, videoURL)
        XCTAssertTrue(viewModel.avCoordinator.isPlaying)

        viewModel.switchToProgram(keynoteItem)

        XCTAssertEqual(viewModel.currentProgramItem, keynoteItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertEqual(presentedURL, keynoteURL)
    }


    func testSwitchingToInvalidKeynoteDoesNotInterruptCurrentPlayback() throws {
        let viewModel = makeViewModel()
        let videoURL = try makeTempFileURL(ext: "mp4")
        let invalidKeynoteURL = try makeEmptyTempFileURL(ext: "key")
        defer {
            try? FileManager.default.removeItem(at: videoURL)
            try? FileManager.default.removeItem(at: invalidKeynoteURL)
        }

        var presentedURL: URL?
        var invalidDeckAlertURL: URL?
        viewModel.programActivationSideEffects.presentKeynote = { url in
            presentedURL = url
        }
        viewModel.programActivationSideEffects.presentInvalidDeckAlert = { url in
            invalidDeckAlertURL = url
        }

        let videoItem = ProgramItem(title: "开场视频", subtitle: "MP4", sourceURL: videoURL)
        let invalidKeynoteItem = ProgramItem(title: "损坏主持稿", subtitle: "KEY", sourceURL: invalidKeynoteURL)

        viewModel.switchToProgram(videoItem)
        XCTAssertEqual(viewModel.currentProgramItem, videoItem)
        XCTAssertEqual(viewModel.avCoordinator.currentURL, videoURL)
        XCTAssertTrue(viewModel.avCoordinator.isPlaying)

        viewModel.switchToProgram(invalidKeynoteItem)

        XCTAssertEqual(viewModel.currentProgramItem, videoItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertEqual(viewModel.avCoordinator.currentURL, videoURL)
        XCTAssertTrue(viewModel.avCoordinator.isPlaying)
        XCTAssertNil(presentedURL)
        XCTAssertEqual(invalidDeckAlertURL, invalidKeynoteURL)
    }


    func testSwitchingToEmptyKeynotePackageDoesNotInterruptCurrentPlayback() throws {
        let viewModel = makeViewModel()
        let videoURL = try makeTempFileURL(ext: "mp4")
        let emptyKeynotePackageURL = try makeTempDirectoryURL(ext: "keynote")
        defer {
            try? FileManager.default.removeItem(at: videoURL)
            try? FileManager.default.removeItem(at: emptyKeynotePackageURL)
        }

        var presentedURL: URL?
        var invalidDeckAlertURL: URL?
        viewModel.programActivationSideEffects.presentKeynote = { url in
            presentedURL = url
        }
        viewModel.programActivationSideEffects.presentInvalidDeckAlert = { url in
            invalidDeckAlertURL = url
        }

        let videoItem = ProgramItem(title: "开场视频", subtitle: "MP4", sourceURL: videoURL)
        let emptyPackageItem = ProgramItem(title: "空包 Keynote", subtitle: "KEY", sourceURL: emptyKeynotePackageURL)

        viewModel.switchToProgram(videoItem)
        XCTAssertEqual(viewModel.currentProgramItem, videoItem)
        XCTAssertEqual(viewModel.avCoordinator.currentURL, videoURL)
        XCTAssertTrue(viewModel.avCoordinator.isPlaying)

        viewModel.switchToProgram(emptyPackageItem)

        XCTAssertEqual(viewModel.currentProgramItem, videoItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertEqual(viewModel.avCoordinator.currentURL, videoURL)
        XCTAssertTrue(viewModel.avCoordinator.isPlaying)
        XCTAssertNil(presentedURL)
        XCTAssertEqual(invalidDeckAlertURL, emptyKeynotePackageURL)
    }


    func testSwitchingToInvalidPPTXDoesNotInterruptCurrentPlayback() throws {
        let viewModel = makeViewModel()
        let videoURL = try makeTempFileURL(ext: "mp4")
        let invalidPPTXURL = try makeEmptyTempFileURL(ext: "pptx")
        defer {
            try? FileManager.default.removeItem(at: videoURL)
            try? FileManager.default.removeItem(at: invalidPPTXURL)
        }

        var openedURL: URL?
        var invalidDeckAlertURL: URL?
        viewModel.programActivationSideEffects.openPPTX = { url in
            openedURL = url
        }
        viewModel.programActivationSideEffects.presentInvalidDeckAlert = { url in
            invalidDeckAlertURL = url
        }

        let videoItem = ProgramItem(title: "开场视频", subtitle: "MP4", sourceURL: videoURL)
        let invalidPPTXItem = ProgramItem(title: "损坏流程稿", subtitle: "PPTX", sourceURL: invalidPPTXURL)

        viewModel.switchToProgram(videoItem)
        XCTAssertEqual(viewModel.currentProgramItem, videoItem)
        XCTAssertEqual(viewModel.avCoordinator.currentURL, videoURL)
        XCTAssertTrue(viewModel.avCoordinator.isPlaying)

        viewModel.switchToProgram(invalidPPTXItem)

        XCTAssertEqual(viewModel.currentProgramItem, videoItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertEqual(viewModel.avCoordinator.currentURL, videoURL)
        XCTAssertTrue(viewModel.avCoordinator.isPlaying)
        XCTAssertNil(openedURL)
        XCTAssertEqual(invalidDeckAlertURL, invalidPPTXURL)
    }


    func testSwitchingToDirectoryPPTXDoesNotInterruptCurrentPlayback() throws {
        let viewModel = makeViewModel()
        let videoURL = try makeTempFileURL(ext: "mp4")
        let directoryPPTXURL = try makeTempDirectoryURL(ext: "pptx")
        defer {
            try? FileManager.default.removeItem(at: videoURL)
            try? FileManager.default.removeItem(at: directoryPPTXURL)
        }

        var openedURL: URL?
        var invalidDeckAlertURL: URL?
        viewModel.programActivationSideEffects.openPPTX = { url in
            openedURL = url
        }
        viewModel.programActivationSideEffects.presentInvalidDeckAlert = { url in
            invalidDeckAlertURL = url
        }

        let videoItem = ProgramItem(title: "开场视频", subtitle: "MP4", sourceURL: videoURL)
        let directoryPPTXItem = ProgramItem(title: "误导入目录", subtitle: "PPTX", sourceURL: directoryPPTXURL)

        viewModel.switchToProgram(videoItem)
        XCTAssertEqual(viewModel.currentProgramItem, videoItem)
        XCTAssertEqual(viewModel.avCoordinator.currentURL, videoURL)
        XCTAssertTrue(viewModel.avCoordinator.isPlaying)

        viewModel.switchToProgram(directoryPPTXItem)

        XCTAssertEqual(viewModel.currentProgramItem, videoItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertEqual(viewModel.avCoordinator.currentURL, videoURL)
        XCTAssertTrue(viewModel.avCoordinator.isPlaying)
        XCTAssertNil(openedURL)
        XCTAssertEqual(invalidDeckAlertURL, directoryPPTXURL)
    }


    func testSwitchingToPPTXStopsPreviousVideoAndInvokesOpenHandler() throws {
        let viewModel = makeViewModel()
        let videoURL = try makeTempFileURL(ext: "mp4")
        let pptxURL = try makeTempFileURL(ext: "pptx")
        let htmlURL = try makeTempFileURL(ext: "html")
        defer {
            try? FileManager.default.removeItem(at: videoURL)
            try? FileManager.default.removeItem(at: pptxURL)
            try? FileManager.default.removeItem(at: htmlURL)
        }

        var openedURL: URL?
        viewModel.programActivationSideEffects.openPPTX = { url in
            openedURL = url
        }

        let videoItem = ProgramItem(title: "宣传片", subtitle: "MP4", sourceURL: videoURL)
        let pptxItem = ProgramItem(title: "流程稿", subtitle: "PPTX", sourceURL: pptxURL)

        viewModel.currentHTMLURL = htmlURL
        viewModel.switchToProgram(videoItem)
        XCTAssertEqual(viewModel.avCoordinator.currentURL, videoURL)
        XCTAssertTrue(viewModel.avCoordinator.isPlaying)

        viewModel.switchToProgram(pptxItem)

        XCTAssertEqual(viewModel.currentProgramItem, pptxItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertEqual(openedURL, pptxURL)
    }

}
