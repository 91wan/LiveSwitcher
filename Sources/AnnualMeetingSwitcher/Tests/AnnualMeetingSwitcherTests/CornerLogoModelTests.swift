import AppKit
import XCTest
@testable import LiveSwitcher

final class CornerLogoModelTests: XCTestCase {
    @MainActor
    func testCornerLogoDefaultsToOff() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false, userDefaults: isolatedDefaults())

        XCTAssertNil(viewModel.cornerLogoURL)
        XCTAssertEqual(viewModel.cornerLogoPosition, .topRight)
    }

    @MainActor
    func testCornerLogoURLAndPositionPersist() async {
        let defaults = isolatedDefaults()
        let url = temporaryImageURL(named: "company-logo.png")
        let writer = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false, userDefaults: defaults)

        XCTAssertTrue(writer.setCornerLogo(url: url))
        await waitForCornerLogoReady(writer, activeURL: url)
        writer.cornerLogoPosition = .bottomLeft
        writer.saveData()

        let restored = SwitcherViewModel(loadPersistedData: true, enableSystemVolumeObserver: false, userDefaults: defaults)

        XCTAssertEqual(restored.cornerLogoURL, url)
        XCTAssertEqual(restored.cornerLogoPosition, .bottomLeft)
    }

    @MainActor
    func testRemovingCornerLogoClearsPersistedURLWithoutChangingPosition() async {
        let defaults = isolatedDefaults()
        let url = temporaryImageURL(named: "company-logo.png")
        let writer = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false, userDefaults: defaults)

        XCTAssertTrue(writer.setCornerLogo(url: url))
        await waitForCornerLogoReady(writer, activeURL: url)
        writer.cornerLogoPosition = .bottomRight
        writer.removeCornerLogo()

        let restored = SwitcherViewModel(loadPersistedData: true, enableSystemVolumeObserver: false, userDefaults: defaults)

        XCTAssertNil(restored.cornerLogoURL)
        XCTAssertEqual(restored.cornerLogoPosition, .bottomRight)
    }

    @MainActor
    func testRejectsUndecodableCornerLogoImageInsteadOfSavingInvisibleLogo() async throws {
        let defaults = isolatedDefaults()
        let invalidURL = temporaryInvalidImageURL(named: "broken-logo.png")
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false, userDefaults: defaults)

        XCTAssertTrue(viewModel.setCornerLogo(url: invalidURL))
        await waitForCornerLogoFailure(viewModel)

        XCTAssertNil(viewModel.cornerLogoURL)
        XCTAssertNil(viewModel.cornerLogoImage)
        XCTAssertNil(defaults.string(forKey: "cornerLogo_path"))
        XCTAssertEqual(viewModel.cornerLogoLoadPhase, .failed(candidateURL: invalidURL, reason: .decodeFailed))
    }

    @MainActor
    func testLoadDataDropsPersistedUndecodableCornerLogoImage() throws {
        let defaults = isolatedDefaults()
        let invalidURL = temporaryInvalidImageURL(named: "persisted-broken-logo.png")
        defaults.set(invalidURL.path, forKey: "cornerLogo_path")

        let viewModel = SwitcherViewModel(loadPersistedData: true, enableSystemVolumeObserver: false, userDefaults: defaults)

        XCTAssertNil(viewModel.cornerLogoURL)
        XCTAssertNil(viewModel.cornerLogoImage)
    }

    func testCornerLogoPositionsCoverAllFourCorners() {
        XCTAssertEqual(CornerLogoPosition.allCases, [.topLeft, .topRight, .bottomLeft, .bottomRight])
        XCTAssertEqual(CornerLogoPosition.topLeft.displayName, "左上")
        XCTAssertEqual(CornerLogoPosition.topRight.displayName, "右上")
        XCTAssertEqual(CornerLogoPosition.bottomLeft.displayName, "左下")
        XCTAssertEqual(CornerLogoPosition.bottomRight.displayName, "右下")
        XCTAssertEqual(CornerLogoPosition.topLeft.shortLabel, "左上")
    }

    func testOutputLayerPlacesCornerLogoBelowPanicAndAboveOverlays() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Views/ActiveProgramOverlayLayer.swift")

        XCTAssertTrue(source.contains("OutputCornerLogoLayer"))
        XCTAssertTrue(source.contains("OutputLayerZIndex.cornerLogo"))
        XCTAssertTrue(source.contains("OutputLayerZIndex.panic"))
        XCTAssertGreaterThan(OutputLayerZIndex.panic, OutputLayerZIndex.cornerLogo)
        XCTAssertGreaterThan(OutputLayerZIndex.cornerLogo, OutputLayerZIndex.lowerThird)
    }

    func testOutputLogoLayerUsesDecodedCornerLogoImageOnly() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Views/ActiveProgramOverlayLayer.swift")

        XCTAssertTrue(source.contains("let cornerLogoImage: NSImage?"))
        XCTAssertTrue(source.contains("let image: NSImage?"))
        XCTAssertTrue(source.contains("Image(nsImage: image)"))
        XCTAssertFalse(source.contains("OutputCornerLogoLayer(\n                url:"))
        XCTAssertFalse(source.contains("AsyncLocalImage(url: url)"))
        XCTAssertFalse(source.contains("Data(contentsOf:"))
        XCTAssertFalse(source.contains(".equatable()"))
        XCTAssertTrue(source.contains(".accessibilityLabel(\"角标 Logo 输出\")"))
        XCTAssertFalse(source.contains(".accessibilityLabel(\"Corner logo\")"))
    }

    func testSetupRunDeskExposesCornerLogoControls() throws {
        let monitor = try sourceText("Sources/AnnualMeetingSwitcher/Views/ProgramMonitorView.swift")
        let card = try sourceText("Sources/AnnualMeetingSwitcher/Views/CornerLogoCard.swift")

        XCTAssertTrue(monitor.contains("CornerLogoCard"))
        XCTAssertTrue(card.contains("Text(\"角标\")"))
        XCTAssertFalse(card.contains("Text(\"角标 Logo\")"))
        XCTAssertTrue(card.contains("导入 Logo"))
        XCTAssertTrue(card.contains("cornerLogoPosition"))
    }

    func testProgramMonitorPreviewsCornerLogoOverlay() throws {
        let monitor = try sourceText("Sources/AnnualMeetingSwitcher/Views/ProgramMonitorView.swift")

        XCTAssertTrue(monitor.contains("ActiveProgramOverlayLayer("))
        XCTAssertTrue(monitor.contains("cornerLogoImage: viewModel.cornerLogoImage"))
        XCTAssertFalse(monitor.contains("} else if let url = viewModel.cornerLogoURL"))
        XCTAssertFalse(monitor.contains("AsyncLocalImage(url: url)"))
        XCTAssertFalse(monitor.contains("monitorCornerLogoImage(image)"))
        XCTAssertFalse(monitor.contains("viewModel.cornerLogoPosition.monitorAlignment"))
        XCTAssertFalse(monitor.contains("viewModel.cornerLogoPosition.monitorPadding"))
    }

    func testTopMonitorLogoPositionsAvoidInlineChrome() {
        let topRight = CornerLogoPosition.topRight.monitorPadding(chromeVisible: true)
        let bottomRight = CornerLogoPosition.bottomRight.monitorPadding(chromeVisible: true)

        XCTAssertGreaterThan(topRight.top, bottomRight.top)
        XCTAssertEqual(CornerLogoPosition.topRight.monitorPadding(chromeVisible: false).top, bottomRight.top)
    }

    private func isolatedDefaults() -> UserDefaults {
        let suiteName = "LiveSwitcher.CornerLogoModelTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func temporaryImageURL(named fileName: String) -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LiveSwitcherCornerLogoTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(fileName)
        let image = NSImage(size: NSSize(width: 8, height: 8))
        image.lockFocus()
        NSColor.systemBlue.setFill()
        NSRect(x: 0, y: 0, width: 8, height: 8).fill()
        image.unlockFocus()
        let tiffData = image.tiffRepresentation!
        let bitmap = NSBitmapImageRep(data: tiffData)!
        let pngData = bitmap.representation(using: .png, properties: [:])!
        try? pngData.write(to: url)
        return url
    }

    private func temporaryInvalidImageURL(named fileName: String) -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LiveSwitcherCornerLogoTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(fileName)
        try? Data("not an image".utf8).write(to: url)
        return url
    }

    @MainActor
    private func waitForCornerLogoReady(_ viewModel: SwitcherViewModel, activeURL: URL) async {
        for _ in 0..<100 {
            if viewModel.cornerLogoLoadPhase == .ready(activeURL: activeURL) {
                return
            }
            await Task.yield()
        }
        XCTFail("Corner logo did not become ready")
    }

    @MainActor
    private func waitForCornerLogoFailure(_ viewModel: SwitcherViewModel) async {
        for _ in 0..<100 {
            if case .failed = viewModel.cornerLogoLoadPhase {
                return
            }
            await Task.yield()
        }
        XCTFail("Corner logo did not fail")
    }

    private func sourceText(_ relativePath: String) throws -> String {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }
}
