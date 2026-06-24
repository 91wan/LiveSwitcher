import AppKit
import XCTest
@testable import LiveSwitcher

@MainActor
final class MonitorWallpaperParityTests: XCTestCase {
    func testActiveWallpaperSwitchingUpdatesSingleDecodedBackgroundImageSource() {
        let viewModel = makeViewModel()
        let first = temporaryImageURL(named: "first-wallpaper.png")
        let second = temporaryImageURL(named: "second-wallpaper.png")

        viewModel.backgroundWallpapers = [first, second]

        viewModel.setActiveWallpaper(url: first)
        let firstImage = viewModel.backgroundImage

        viewModel.setActiveWallpaper(url: second)
        let secondImage = viewModel.backgroundImage

        XCTAssertEqual(viewModel.activeWallpaperURL, second)
        XCTAssertNotNil(firstImage)
        XCTAssertNotNil(secondImage)
        XCTAssertFalse(firstImage === secondImage)
    }

    func testRemovingActiveWallpaperAdvancesMonitorImageToNextWallpaperAndFallsBackAfterLastRemoval() {
        let viewModel = makeViewModel()
        let first = temporaryImageURL(named: "remove-first.png")
        let second = temporaryImageURL(named: "remove-second.png")
        viewModel.backgroundWallpapers = [first, second]
        viewModel.setActiveWallpaper(url: first)
        let firstImage = viewModel.backgroundImage

        viewModel.removeWallpaper(url: first)
        let secondImage = viewModel.backgroundImage

        XCTAssertEqual(viewModel.backgroundWallpapers, [second])
        XCTAssertEqual(viewModel.activeWallpaperURL, second)
        XCTAssertNotNil(secondImage)
        XCTAssertFalse(firstImage === secondImage)

        viewModel.removeWallpaper(url: second)

        XCTAssertTrue(viewModel.backgroundWallpapers.isEmpty)
        XCTAssertNil(viewModel.activeWallpaperURL)
        XCTAssertNil(viewModel.backgroundImage)
    }

    func testOutputAndMonitorConsumeSharedStandbyWallpaperLayer() throws {
        let layer = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/StandbyWallpaperLayer.swift")
        let output = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Output/OutputWindowController.swift")
        let monitor = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/ProgramMonitorView.swift")

        XCTAssertTrue(layer.contains("struct StandbyWallpaperLayer"))
        XCTAssertTrue(layer.contains("let image: NSImage?"))
        XCTAssertTrue(layer.contains("Image(nsImage: wallpaper)"))
        XCTAssertTrue(layer.contains(".resizable()"))
        XCTAssertTrue(layer.contains(".scaledToFill()"))
        XCTAssertTrue(layer.contains(".clipped()"))
        XCTAssertTrue(layer.contains("Color.black"))
        XCTAssertTrue(output.contains("StandbyWallpaperLayer(image: viewModel.backgroundImage)"))
        XCTAssertTrue(monitor.contains("StandbyWallpaperLayer(image: viewModel.backgroundImage)"))
    }

    func testProgramMonitorKeepsWallpaperBehindMediaLogoAndChromeWithoutURLDecoding() throws {
        let monitor = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/ProgramMonitorView.swift")

        XCTAssertFalse(monitor.contains("Data(contentsOf:"))
        XCTAssertFalse(monitor.contains("NSImage(contentsOf:"))
        XCTAssertFalse(monitor.contains("AsyncLocalImage"))
        XCTAssertLessThan(
            try XCTUnwrap(monitor.range(of: "StandbyWallpaperLayer(image: viewModel.backgroundImage)")?.lowerBound),
            try XCTUnwrap(monitor.range(of: "mediaLayer")?.lowerBound)
        )
        XCTAssertLessThan(
            try XCTUnwrap(monitor.range(of: "mediaLayer")?.lowerBound),
            try XCTUnwrap(monitor.range(of: "monitorCornerLogoOverlay")?.lowerBound)
        )
        XCTAssertLessThan(
            try XCTUnwrap(monitor.range(of: "monitorCornerLogoOverlay")?.lowerBound),
            try XCTUnwrap(monitor.range(of: "monitorTopChrome")?.lowerBound)
        )
    }

    func testVideoPlaybackAndPauseVisibilityContractStaysAboveWallpaper() throws {
        let monitor = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/ProgramMonitorView.swift")
        let output = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Output/OutputWindowController.swift")
        let outputBodyStart = try XCTUnwrap(output.range(of: "ZStack {")).lowerBound
        let outputBodyEnd = try XCTUnwrap(output.range(of: "OutputOverlayLayer(")).lowerBound
        let outputBody = outputBodyStart..<outputBodyEnd
        let outputBodySource = String(output[outputBody])

        XCTAssertTrue(monitor.contains("VideoLayerVisibilityModel.shouldShowMonitorVideoLayer"))
        XCTAssertTrue(monitor.contains("VideoPlayerView(coordinator: avCoordinator)"))
        XCTAssertTrue(monitor.contains("Text(\"暂停\")"))
        XCTAssertTrue(output.contains("OutputVideoPlayerView("))
        XCTAssertTrue(output.contains("sourceKind: viewModel.currentProgramItem?.sourceKind"))
        XCTAssertLessThan(
            try XCTUnwrap(outputBodySource.range(of: "backgroundLayer")?.lowerBound),
            try XCTUnwrap(outputBodySource.range(of: "mediaContentLayer(displayState: displayState)")?.lowerBound)
        )
    }

    private func makeViewModel() -> SwitcherViewModel {
        let suiteName = "MonitorWallpaperParityTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            userDefaults: defaults
        )
    }

    private func temporaryImageURL(named name: String) -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LiveSwitcherMonitorWallpaperParityTests", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("\(UUID().uuidString)-\(name)")
        let image = NSImage(size: NSSize(width: 12, height: 8))
        image.lockFocus()
        NSColor.systemGreen.setFill()
        NSRect(x: 0, y: 0, width: 12, height: 8).fill()
        image.unlockFocus()
        guard let data = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: data),
              let png = bitmap.representation(using: .png, properties: [:]) else {
            XCTFail("Could not create image fixture")
            return url
        }
        try? png.write(to: url)
        return url
    }
}
