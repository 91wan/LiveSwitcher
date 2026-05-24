import XCTest
@testable import LiveSwitcher

final class SetupAudioDockModelTests: XCTestCase {
    func testDockVisibilityOnlyAppliesToSetupNonAudioTabs() {
        XCTAssertTrue(SetupAudioDockModel.shouldShow(consoleMode: .setup, selectedTab: .preview))
        XCTAssertTrue(SetupAudioDockModel.shouldShow(consoleMode: .setup, selectedTab: .overlays))
        XCTAssertFalse(SetupAudioDockModel.shouldShow(consoleMode: .setup, selectedTab: .audioMixer))
        XCTAssertFalse(SetupAudioDockModel.shouldShow(consoleMode: .live, selectedTab: .preview))
    }

    func testDockModelFormatsUserAndEffectiveOutput() {
        let model = SetupAudioDockModel.make(
            masterVolume: 0.5,
            mediaVolume: 1.0,
            bgmVolume: 0.25,
            effectiveMediaVolume: 0.4,
            effectiveBGMVolume: 0.1,
            isMasterMuted: false,
            isMediaMuted: true,
            isBGMMuted: false
        )

        XCTAssertEqual(model.masterUserText, "50%")
        XCTAssertEqual(model.masterEffectiveText, "50%")
        XCTAssertEqual(model.mediaUserText, "100%")
        XCTAssertEqual(model.bgmUserText, "25%")
        XCTAssertEqual(model.mediaEffectiveText, "40%")
        XCTAssertEqual(model.bgmEffectiveText, "10%")
        XCTAssertEqual(model.mutedChannelCount, 1)
    }

    func testMasterMuteDrivesMasterEffectiveOutputText() {
        let model = SetupAudioDockModel.make(
            masterVolume: 0.5,
            mediaVolume: 1.0,
            bgmVolume: 0.25,
            effectiveMediaVolume: 0,
            effectiveBGMVolume: 0,
            isMasterMuted: true,
            isMediaMuted: false,
            isBGMMuted: false
        )

        XCTAssertEqual(model.masterUserText, "50%")
        XCTAssertEqual(model.masterEffectiveText, "0%")
        XCTAssertEqual(model.mutedChannelCount, 1)
    }

    func testContentViewMountsSetupAudioDockOutsideAudioPage() throws {
        let content = try String(contentsOf: sourceURL("ContentView.swift"), encoding: .utf8)

        XCTAssertTrue(content.contains("SetupAudioDockModel.shouldShow"))
        XCTAssertTrue(content.contains("SetupAudioDock {"))
    }

    private func sourceURL(_ relativePath: String) throws -> URL {
        var directory = URL(fileURLWithPath: #filePath)
        while directory.pathComponents.count > 1 {
            directory.deleteLastPathComponent()
            let candidate = directory
                .appendingPathComponent("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher")
                .appendingPathComponent(relativePath)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        throw XCTSkip("Could not locate \(relativePath) from test source path.")
    }
}
