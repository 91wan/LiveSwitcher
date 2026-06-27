import AppKit
import SwiftUI
import XCTest
@testable import LiveSwitcher

@MainActor
final class SwitcherViewModelMediaSmokeTests: SwitcherViewModelSmokeTestCase {
    func testSwitchingToVideoClearsHTMLAndStartsPlayback() throws {
        let viewModel = makeViewModel()
        let videoURL = try makeTempFileURL(ext: "mp4")
        let htmlURL = try makeTempFileURL(ext: "html")
        defer {
            try? FileManager.default.removeItem(at: videoURL)
            try? FileManager.default.removeItem(at: htmlURL)
        }

        viewModel.isBroadcasting = true
        viewModel.currentHTMLURL = htmlURL

        let videoItem = ProgramItem(title: "开场片头", subtitle: "MP4", sourceURL: videoURL)
        viewModel.switchToProgram(videoItem)

        XCTAssertEqual(viewModel.currentProgramItem, videoItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertEqual(viewModel.avCoordinator.currentURL, videoURL)
        XCTAssertTrue(viewModel.avCoordinator.isPlaying)
        XCTAssertTrue(viewModel.isBroadcasting)
    }


    func testSwitchingToHTMLStopsVideoAndPromotesHTMLAsCurrentProgram() throws {
        let viewModel = makeViewModel()
        let videoURL = try makeTempFileURL(ext: "mp4")
        let htmlURL = try makeTempFileURL(ext: "html")
        defer {
            try? FileManager.default.removeItem(at: videoURL)
            try? FileManager.default.removeItem(at: htmlURL)
        }

        let videoItem = ProgramItem(title: "宣传片", subtitle: "MP4", sourceURL: videoURL)
        let htmlItem = ProgramItem(title: "签到页", subtitle: "HTML", sourceURL: htmlURL)

        viewModel.isBroadcasting = true
        viewModel.switchToProgram(videoItem)
        XCTAssertTrue(viewModel.avCoordinator.isPlaying)

        viewModel.switchToProgram(htmlItem)

        XCTAssertEqual(viewModel.currentProgramItem, htmlItem)
        XCTAssertEqual(viewModel.currentHTMLURL, htmlURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertTrue(viewModel.isBroadcasting)
    }


    func testSwitchingToUnsupportedProgramDoesNotMutateCurrentOutputState() throws {
        let viewModel = makeViewModel()
        let htmlURL = try makeTempFileURL(ext: "html")
        let unsupportedURL = try makeTempFileURL(ext: "txt")
        defer {
            try? FileManager.default.removeItem(at: htmlURL)
            try? FileManager.default.removeItem(at: unsupportedURL)
        }

        let currentItem = ProgramItem(title: "签到页", subtitle: "HTML", sourceURL: htmlURL)
        viewModel.switchToProgram(currentItem)
        XCTAssertEqual(viewModel.currentProgramItem, currentItem)
        XCTAssertEqual(viewModel.currentHTMLURL, htmlURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)

        let unsupportedItem = ProgramItem(title: "说明文档", subtitle: "TXT", sourceURL: unsupportedURL)
        viewModel.switchToProgram(unsupportedItem)

        XCTAssertEqual(viewModel.currentProgramItem, currentItem)
        XCTAssertEqual(viewModel.currentHTMLURL, htmlURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
    }


    func testSwitchingToMissingMediaFileDoesNotReplaceCurrentProgram() throws {
        let viewModel = makeViewModel()
        let currentURL = try makeTempFileURL(ext: "mp4")
        let missingURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        defer { try? FileManager.default.removeItem(at: currentURL) }

        let currentItem = ProgramItem(title: "当前片头", subtitle: "MP4", sourceURL: currentURL)
        let missingItem = ProgramItem(title: "已移动文件", subtitle: "MP4", sourceURL: missingURL)

        viewModel.switchToProgram(currentItem)
        XCTAssertEqual(viewModel.currentProgramItem, currentItem)
        XCTAssertEqual(viewModel.avCoordinator.currentURL, currentURL)
        XCTAssertTrue(viewModel.avCoordinator.isPlaying)

        viewModel.switchToProgram(missingItem)

        XCTAssertEqual(viewModel.currentProgramItem, currentItem)
        XCTAssertEqual(viewModel.avCoordinator.currentURL, currentURL)
        XCTAssertTrue(viewModel.avCoordinator.isPlaying)
        XCTAssertEqual(viewModel.supportEvents.last?.kind, .programItemFileMissing)
        XCTAssertTrue(viewModel.supportEvents.last?.detail.contains("sourceKind=media") == true)
        XCTAssertFalse(viewModel.supportEvents.last?.detail.contains(missingURL.lastPathComponent) == true)
        XCTAssertEqual(viewModel.automationRuntimeNotice?.title, "节目文件不存在")
    }


    func testSwitchingToMissingHTMLFileDoesNotPromoteCurrentHTML() throws {
        let viewModel = makeViewModel()
        let missingURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("html")
        let missingItem = ProgramItem(title: "已删除签到页", subtitle: "HTML", sourceURL: missingURL)

        viewModel.switchToProgram(missingItem)

        XCTAssertNil(viewModel.currentProgramItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertEqual(viewModel.supportEvents.last?.kind, .programItemFileMissing)
        XCTAssertTrue(viewModel.supportEvents.last?.detail.contains("sourceKind=html") == true)
        XCTAssertEqual(viewModel.automationRuntimeNotice?.title, "节目文件不存在")
    }


    func testSwitchingToMissingPPTXFileDoesNotInvokeOpenHandler() throws {
        let viewModel = makeViewModel()
        let missingURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("pptx")
        let missingItem = ProgramItem(title: "已删除流程稿", subtitle: "PPTX", sourceURL: missingURL)
        var openedURL: URL?
        viewModel.programActivationSideEffects.openPPTX = { openedURL = $0 }

        viewModel.switchToProgram(missingItem)

        XCTAssertNil(viewModel.currentProgramItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertNil(openedURL)
        XCTAssertEqual(viewModel.supportEvents.last?.kind, .programItemFileMissing)
        XCTAssertTrue(viewModel.supportEvents.last?.detail.contains("sourceKind=pptx") == true)
        XCTAssertEqual(viewModel.automationRuntimeNotice?.title, "节目文件不存在")
    }


    func testSwitchingFromVideoToHTMLWhileBroadcastingDoesNotReopenOutputWindow() throws {
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

        viewModel.switchToProgram(videoItem)
        viewModel.handleBroadcastToggle()
        XCTAssertEqual(outputSpy.mountCount, 1)
        XCTAssertEqual(outputSpy.showCount, 1)

        viewModel.switchToProgram(htmlItem)

        XCTAssertEqual(viewModel.currentProgramItem, htmlItem)
        XCTAssertEqual(viewModel.currentHTMLURL, htmlURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertTrue(viewModel.isBroadcasting)
        XCTAssertEqual(outputSpy.mountCount, 1)
        XCTAssertEqual(outputSpy.showCount, 1)
        XCTAssertEqual(outputSpy.hideCount, 0)
    }


    func testSwitchingFromHTMLToVideoWhileBroadcastingDoesNotReopenOutputWindow() throws {
        let viewModel = makeViewModel()
        let outputSpy = SwitcherViewModelSmokeOutputWindowControllerSpy()
        let htmlURL = try makeTempFileURL(ext: "html")
        let videoURL = try makeTempFileURL(ext: "mp4")
        defer {
            try? FileManager.default.removeItem(at: htmlURL)
            try? FileManager.default.removeItem(at: videoURL)
        }

        viewModel.outputWindowControllerFactory = { outputSpy }
        let htmlItem = ProgramItem(title: "签到页", subtitle: "HTML", sourceURL: htmlURL)
        let videoItem = ProgramItem(title: "片头", subtitle: "MP4", sourceURL: videoURL)

        viewModel.switchToProgram(htmlItem)
        viewModel.handleBroadcastToggle()
        XCTAssertEqual(outputSpy.mountCount, 1)
        XCTAssertEqual(outputSpy.showCount, 1)

        viewModel.switchToProgram(videoItem)

        XCTAssertEqual(viewModel.currentProgramItem, videoItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertEqual(viewModel.avCoordinator.currentURL, videoURL)
        XCTAssertTrue(viewModel.avCoordinator.isPlaying)
        XCTAssertTrue(viewModel.isBroadcasting)
        XCTAssertEqual(outputSpy.mountCount, 1)
        XCTAssertEqual(outputSpy.showCount, 1)
        XCTAssertEqual(outputSpy.hideCount, 0)
    }


    func testEndingHTMLClearsProgramAndFallsBackToWallpaperState() throws {
        let viewModel = makeViewModel()
        let htmlURL = try makeTempFileURL(ext: "html")
        let wallpaperURL = try makeWallpaperURL()
        defer {
            try? FileManager.default.removeItem(at: htmlURL)
            try? FileManager.default.removeItem(at: wallpaperURL)
        }

        viewModel.addWallpaper(url: wallpaperURL)
        viewModel.setActiveWallpaper(url: wallpaperURL)
        let htmlItem = ProgramItem(title: "主视觉", subtitle: "HTML", sourceURL: htmlURL)

        viewModel.isBroadcasting = true
        viewModel.switchToProgram(htmlItem)
        XCTAssertEqual(viewModel.currentHTMLURL, htmlURL)
        XCTAssertNotNil(viewModel.backgroundImage)

        viewModel.endHTMLPresentation()

        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertNil(viewModel.currentProgramItem)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertNotNil(viewModel.backgroundImage)
        XCTAssertTrue(viewModel.isBroadcasting)
    }


    func testEndingHTMLWhileBroadcastingDoesNotHideOutputWindow() throws {
        let viewModel = makeViewModel()
        let outputSpy = SwitcherViewModelSmokeOutputWindowControllerSpy()
        let htmlURL = try makeTempFileURL(ext: "html")
        let wallpaperURL = try makeWallpaperURL()
        defer {
            try? FileManager.default.removeItem(at: htmlURL)
            try? FileManager.default.removeItem(at: wallpaperURL)
        }

        viewModel.outputWindowControllerFactory = { outputSpy }
        viewModel.addWallpaper(url: wallpaperURL)
        viewModel.setActiveWallpaper(url: wallpaperURL)
        let htmlItem = ProgramItem(title: "签到页", subtitle: "HTML", sourceURL: htmlURL)

        viewModel.switchToProgram(htmlItem)
        viewModel.handleBroadcastToggle()

        viewModel.endHTMLPresentation()

        XCTAssertNil(viewModel.currentProgramItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertNotNil(viewModel.backgroundImage)
        XCTAssertTrue(viewModel.isBroadcasting)
        XCTAssertEqual(outputSpy.showCount, 1)
        XCTAssertEqual(outputSpy.hideCount, 0)
    }


    func testRepeatedEndingHTMLWhileBroadcastingIsIdempotent() throws {
        let viewModel = makeViewModel()
        let outputSpy = SwitcherViewModelSmokeOutputWindowControllerSpy()
        let htmlURL = try makeTempFileURL(ext: "html")
        let wallpaperURL = try makeWallpaperURL()
        defer {
            try? FileManager.default.removeItem(at: htmlURL)
            try? FileManager.default.removeItem(at: wallpaperURL)
        }

        viewModel.outputWindowControllerFactory = { outputSpy }
        viewModel.addWallpaper(url: wallpaperURL)
        viewModel.setActiveWallpaper(url: wallpaperURL)
        let htmlItem = ProgramItem(title: "签到页", subtitle: "HTML", sourceURL: htmlURL)

        viewModel.switchToProgram(htmlItem)
        viewModel.handleBroadcastToggle()

        viewModel.endHTMLPresentation()
        viewModel.endHTMLPresentation()

        XCTAssertNil(viewModel.currentProgramItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertNotNil(viewModel.backgroundImage)
        XCTAssertTrue(viewModel.isBroadcasting)
        XCTAssertEqual(outputSpy.showCount, 1)
        XCTAssertEqual(outputSpy.hideCount, 0)
    }


    func testRemovingCurrentProgramClearsPlaybackAndListState() throws {
        let viewModel = makeViewModel()
        let currentVideoURL = try makeTempFileURL(ext: "mp4")
        let standbyVideoURL = try makeTempFileURL(ext: "mp4")
        defer {
            try? FileManager.default.removeItem(at: currentVideoURL)
            try? FileManager.default.removeItem(at: standbyVideoURL)
        }

        let currentItem = ProgramItem(title: "当前节目", subtitle: "MP4", sourceURL: currentVideoURL)
        let standbyItem = ProgramItem(title: "备用节目", subtitle: "MP4", sourceURL: standbyVideoURL)
        viewModel.addProgramItem(currentItem)
        viewModel.addProgramItem(standbyItem)
        viewModel.switchToProgram(currentItem)

        viewModel.removeProgramItem(withID: currentItem.id)

        XCTAssertNil(viewModel.currentProgramItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertEqual(viewModel.programItems.count, 1)
        XCTAssertEqual(viewModel.programItems.first, standbyItem)
    }


    func testRemovingCurrentHTMLProgramClearsHTMLAndReturnsToIdleState() throws {
        let viewModel = makeViewModel()
        let htmlURL = try makeTempFileURL(ext: "html")
        let standbyVideoURL = try makeTempFileURL(ext: "mp4")
        let wallpaperURL = try makeWallpaperURL()
        defer {
            try? FileManager.default.removeItem(at: htmlURL)
            try? FileManager.default.removeItem(at: standbyVideoURL)
            try? FileManager.default.removeItem(at: wallpaperURL)
        }

        viewModel.addWallpaper(url: wallpaperURL)
        viewModel.setActiveWallpaper(url: wallpaperURL)

        let htmlItem = ProgramItem(title: "签到页", subtitle: "HTML", sourceURL: htmlURL)
        let standbyItem = ProgramItem(title: "备用片头", subtitle: "MP4", sourceURL: standbyVideoURL)
        viewModel.addProgramItem(htmlItem)
        viewModel.addProgramItem(standbyItem)
        viewModel.isBroadcasting = true
        viewModel.switchToProgram(htmlItem)

        XCTAssertEqual(viewModel.currentProgramItem, htmlItem)
        XCTAssertEqual(viewModel.currentHTMLURL, htmlURL)

        viewModel.removeProgramItem(withID: htmlItem.id)

        XCTAssertNil(viewModel.currentProgramItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertNotNil(viewModel.backgroundImage)
        XCTAssertEqual(viewModel.programItems, [standbyItem])
        XCTAssertTrue(viewModel.isBroadcasting)
    }


    func testRemovingCurrentVideoWhileBroadcastingDoesNotHideOutputWindow() throws {
        let viewModel = makeViewModel()
        let outputSpy = SwitcherViewModelSmokeOutputWindowControllerSpy()
        let videoURL = try makeTempFileURL(ext: "mp4")
        defer { try? FileManager.default.removeItem(at: videoURL) }

        viewModel.outputWindowControllerFactory = { outputSpy }
        let videoItem = ProgramItem(title: "当前节目", subtitle: "MP4", sourceURL: videoURL)
        viewModel.addProgramItem(videoItem)
        viewModel.switchToProgram(videoItem)
        viewModel.handleBroadcastToggle()

        viewModel.removeProgramItem(withID: videoItem.id)

        XCTAssertNil(viewModel.currentProgramItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertTrue(viewModel.isBroadcasting)
        XCTAssertEqual(outputSpy.showCount, 1)
        XCTAssertEqual(outputSpy.hideCount, 0)
    }


    func testRemovingCurrentHTMLWhileBroadcastingDoesNotHideOutputWindow() throws {
        let viewModel = makeViewModel()
        let outputSpy = SwitcherViewModelSmokeOutputWindowControllerSpy()
        let htmlURL = try makeTempFileURL(ext: "html")
        defer { try? FileManager.default.removeItem(at: htmlURL) }

        viewModel.outputWindowControllerFactory = { outputSpy }
        let htmlItem = ProgramItem(title: "签到页", subtitle: "HTML", sourceURL: htmlURL)
        viewModel.addProgramItem(htmlItem)
        viewModel.switchToProgram(htmlItem)
        viewModel.handleBroadcastToggle()

        viewModel.removeProgramItem(withID: htmlItem.id)

        XCTAssertNil(viewModel.currentProgramItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertTrue(viewModel.isBroadcasting)
        XCTAssertEqual(outputSpy.showCount, 1)
        XCTAssertEqual(outputSpy.hideCount, 0)
    }


    func testRepeatedRemovalOfCurrentHTMLWhileBroadcastingIsIdempotent() throws {
        let viewModel = makeViewModel()
        let outputSpy = SwitcherViewModelSmokeOutputWindowControllerSpy()
        let htmlURL = try makeTempFileURL(ext: "html")
        defer { try? FileManager.default.removeItem(at: htmlURL) }

        viewModel.outputWindowControllerFactory = { outputSpy }
        let htmlItem = ProgramItem(title: "签到页", subtitle: "HTML", sourceURL: htmlURL)
        viewModel.addProgramItem(htmlItem)
        viewModel.switchToProgram(htmlItem)
        viewModel.handleBroadcastToggle()

        viewModel.removeProgramItem(withID: htmlItem.id)
        viewModel.removeProgramItem(withID: htmlItem.id)

        XCTAssertTrue(viewModel.programItems.isEmpty)
        XCTAssertNil(viewModel.currentProgramItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertTrue(viewModel.isBroadcasting)
        XCTAssertEqual(outputSpy.showCount, 1)
        XCTAssertEqual(outputSpy.hideCount, 0)
    }

}
