import XCTest
@testable import LiveSwitcher

@MainActor
final class BGMProgressStoreTests: XCTestCase {
    func testTimerIntervalIsOperatorFriendlyTenFPS() {
        XCTAssertEqual(BGMProgressStore.updateInterval, 0.1, accuracy: 0.0001)
    }

    func testUpdateCalculatesProgressAndDuration() {
        let store = BGMProgressStore()

        store.update(currentTime: 25, duration: 100)

        XCTAssertEqual(store.currentTime, 25)
        XCTAssertEqual(store.duration, 100)
        XCTAssertEqual(store.progress, 0.25, accuracy: 0.0001)
    }

    func testUpdateClampsProgressAndHandlesUnknownDuration() {
        let store = BGMProgressStore()

        store.update(currentTime: 125, duration: 100)
        XCTAssertEqual(store.currentTime, 100)
        XCTAssertEqual(store.progress, 1, accuracy: 0.0001)

        store.update(currentTime: 8, duration: 0)
        XCTAssertEqual(store.currentTime, 8)
        XCTAssertNil(store.duration)
        XCTAssertEqual(store.progress, 0)
    }

    func testResetClearsProgressState() {
        let store = BGMProgressStore()
        store.update(currentTime: 12, duration: 60)

        store.reset()

        XCTAssertEqual(store.progress, 0)
        XCTAssertEqual(store.currentTime, 0)
        XCTAssertNil(store.duration)
    }

    func testViewModelNoLongerPublishesBGMProgressTriplet() throws {
        let source = try sourceText("ViewModel.swift")

        XCTAssertFalse(source.contains("@Published var bgmProgress: Double"))
        XCTAssertFalse(source.contains("@Published var bgmCurrentTime: Double"))
        XCTAssertFalse(source.contains("@Published var bgmDuration: Double?"))
        XCTAssertFalse(source.contains("@Published var bgmRealtimeLevelDB"))
        XCTAssertFalse(source.contains("withTimeInterval: 1.0 / 30.0"))
        XCTAssertTrue(source.contains("let bgmProgressStore = BGMProgressStore()"))
        XCTAssertTrue(source.contains("withTimeInterval: BGMProgressStore.updateInterval"))
    }

    func testBGMPlaylistProgressBarObservesDedicatedStore() throws {
        let source = try sourceText("Views/BGMPlaylistPanel.swift")

        XCTAssertTrue(source.contains("BGMProgressBar(progressStore: viewModel.bgmProgressStore"))
        XCTAssertTrue(source.contains("@ObservedObject var progressStore: BGMProgressStore"))
        XCTAssertFalse(source.contains("get: { viewModel.bgmProgress }"))
    }

    func testBGMSwitchingUsesOwnedFadeTransitionInsteadOfImmediateHardStop() throws {
        let viewModel = try sourceText("ViewModel.swift")
        let controls = try sourceText("ViewModel+BGMControls.swift")

        XCTAssertTrue(viewModel.contains("bgmTransitionTasks"))
        XCTAssertTrue(viewModel.contains("bgmTransitionTasks.values.forEach"))
        XCTAssertTrue(viewModel.contains("releaseBGMPlayerAfterFade"))
        XCTAssertFalse(controls.contains("bgmAudioPlayer?.stop()"))
    }

    func testRemovingCurrentBGMUsesFadeReleaseInsteadOfImmediateHardStop() throws {
        let source = try sourceText("ViewModel.swift")
        let removeBody = try XCTUnwrap(source.functionBody(named: "removeBGMItem"))

        XCTAssertFalse(removeBody.contains("bgmAudioPlayer?.stop()"))
        XCTAssertTrue(removeBody.contains("releaseBGMPlayerAfterFade"))
    }

    func testFallbackBGMProgressTimerSamplesFallbackPlayerTime() throws {
        let source = try sourceText("ViewModel.swift")
        let updateBody = try XCTUnwrap(source.functionBody(named: "updateBGMProgress"))

        XCTAssertTrue(updateBody.contains("bgmFallbackPlayer.currentTime()"))
        XCTAssertTrue(updateBody.contains("bgmProgressStore.update"))
    }

    func testStoppingBGMUsesSingleRoutingFadeBeforePausing() throws {
        let source = try sourceText("ViewModel.swift")
        let toggleBody = try XCTUnwrap(source.functionBody(named: "toggleBGM"))

        XCTAssertTrue(source.contains("fadeBGMPlayerVolume"))
        XCTAssertTrue(toggleBody.contains("applyAudioRoutingForRuntimeChange(reason: .bgmPlaybackChanged)"))
        XCTAssertFalse(toggleBody.contains("fadeBGMPlayerVolume(to: 0, duration: fadeDur)"))
        XCTAssertFalse(toggleBody.contains("bgmAudioPlayer?.setVolume(0, fadeDuration: fadeDur)"))
    }

    private func sourceText(_ relativePath: String) throws -> String {
        try String(contentsOf: sourceURL(relativePath), encoding: .utf8)
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

private extension String {
    func functionBody(named functionName: String) -> String? {
        guard let nameRange = range(of: "func \(functionName)") else { return nil }
        guard let openingBrace = self[nameRange.lowerBound...].firstIndex(of: "{") else { return nil }

        var depth = 0
        var index = openingBrace
        while index < endIndex {
            let character = self[index]
            if character == "{" {
                depth += 1
            } else if character == "}" {
                depth -= 1
                if depth == 0 {
                    return String(self[openingBrace...index])
                }
            }
            index = self.index(after: index)
        }
        return nil
    }
}
