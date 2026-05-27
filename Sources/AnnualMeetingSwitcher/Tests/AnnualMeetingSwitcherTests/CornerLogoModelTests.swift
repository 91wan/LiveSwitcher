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
    func testCornerLogoURLAndPositionPersist() {
        let defaults = isolatedDefaults()
        let url = temporaryImageURL(named: "company-logo.png")
        let writer = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false, userDefaults: defaults)

        XCTAssertTrue(writer.setCornerLogo(url: url))
        writer.cornerLogoPosition = .bottomLeft
        writer.saveData()

        let restored = SwitcherViewModel(loadPersistedData: true, enableSystemVolumeObserver: false, userDefaults: defaults)

        XCTAssertEqual(restored.cornerLogoURL, url)
        XCTAssertEqual(restored.cornerLogoPosition, .bottomLeft)
    }

    @MainActor
    func testRemovingCornerLogoClearsPersistedURLWithoutChangingPosition() {
        let defaults = isolatedDefaults()
        let url = temporaryImageURL(named: "company-logo.png")
        let writer = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false, userDefaults: defaults)

        XCTAssertTrue(writer.setCornerLogo(url: url))
        writer.cornerLogoPosition = .bottomRight
        writer.removeCornerLogo()

        let restored = SwitcherViewModel(loadPersistedData: true, enableSystemVolumeObserver: false, userDefaults: defaults)

        XCTAssertNil(restored.cornerLogoURL)
        XCTAssertEqual(restored.cornerLogoPosition, .bottomRight)
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
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Output/OutputWindowController.swift")

        XCTAssertTrue(source.contains("OutputCornerLogoLayer"))
        XCTAssertTrue(source.contains("OutputLayerZIndex.cornerLogo"))
        XCTAssertTrue(source.contains("OutputLayerZIndex.panic"))
        XCTAssertGreaterThan(OutputLayerZIndex.panic, OutputLayerZIndex.cornerLogo)
        XCTAssertGreaterThan(OutputLayerZIndex.cornerLogo, OutputLayerZIndex.lowerThird)
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

        XCTAssertTrue(monitor.contains("monitorCornerLogoOverlay"))
        XCTAssertTrue(monitor.contains("if let image = viewModel.cornerLogoImage"))
        XCTAssertTrue(monitor.contains("} else if let url = viewModel.cornerLogoURL"))
        XCTAssertTrue(monitor.contains("AsyncLocalImage(url: url)"))
        XCTAssertTrue(monitor.contains("monitorCornerLogoImage(image)"))
        XCTAssertTrue(monitor.contains("viewModel.cornerLogoPosition.monitorAlignment"))
        XCTAssertTrue(monitor.contains("viewModel.cornerLogoPosition.monitorPadding"))
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
        FileManager.default.createFile(atPath: url.path, contents: Data("fixture".utf8))
        return url
    }

    private func sourceText(_ relativePath: String) throws -> String {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }
}
