import XCTest
@testable import LiveSwitcher

@MainActor
final class BGMRuntimePanicBridgeTests: XCTestCase {
    func testPanicActivatePausesBGMThroughRuntimePort() {
        let viewModel = makeViewModel()
        let item = bgmItem(title: "Walk-in")
        viewModel.liveAudioFadeDuration = 0
        viewModel.bgmItems = [item]
        viewModel.toggleBGM(item)

        viewModel.togglePanicMode()

        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "operatorPausedBGMForPanic" })
        XCTAssertFalse(viewModel.isBGMPlaying)
    }

    func testPanicDeactivateResumesBGMThroughRuntimePortWhenSnapshotMatches() {
        let viewModel = makeViewModel()
        let item = bgmItem(title: "Walk-in")
        viewModel.liveAudioFadeDuration = 0
        viewModel.bgmItems = [item]
        viewModel.toggleBGM(item)
        viewModel.togglePanicMode()

        viewModel.togglePanicMode()

        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "operatorResumedBGMAfterPanic" })
        XCTAssertTrue(viewModel.isBGMPlaying)
    }

    func testPanicDeactivateDoesNotResumeBGMWhenTrackChanged() {
        let viewModel = makeViewModel()
        let first = bgmItem(title: "First")
        let second = bgmItem(title: "Second")
        viewModel.liveAudioFadeDuration = 0
        viewModel.bgmItems = [first, second]
        viewModel.toggleBGM(first)
        viewModel.togglePanicMode()
        viewModel.currentBGMItem = second

        viewModel.togglePanicMode()

        XCTAssertFalse(viewModel.runtime.actionLog.contains { $0.actionName == "operatorResumedBGMAfterPanic" })
    }

    func testPanicDoesNotDirectlyCallBGMPlayers() throws {
        let source = try sourceText("ViewModel+Panic.swift")

        XCTAssertFalse(source.contains("bgmAudioPlayer?.pause()"))
        XCTAssertFalse(source.contains("bgmFallbackPlayer.pause()"))
        XCTAssertFalse(source.contains("bgmFallbackPlayer.play()"))
        XCTAssertFalse(source.contains("bgmAudioPlayer?.play()"))
        XCTAssertFalse(source.contains("startBGMTimer()"))
        XCTAssertFalse(source.contains("stopBGMTimer()"))
    }

    private func makeViewModel() -> SwitcherViewModel {
        let suiteName = "BGMRuntimePanicBridgeTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false, userDefaults: defaults)
    }

    private func bgmItem(title: String) -> BGMItem {
        BGMItem(title: title, url: URL(fileURLWithPath: "/tmp/\(UUID().uuidString).mp3"))
    }

    private func sourceText(_ relativePath: String) throws -> String {
        try String(contentsOf: sourceURL(relativePath), encoding: .utf8)
    }

    private func sourceURL(_ relativePath: String) throws -> URL {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let candidates = [
            packageRoot.appendingPathComponent("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher").appendingPathComponent(relativePath),
            packageRoot.appendingPathComponent("Sources/AnnualMeetingSwitcher").appendingPathComponent(relativePath),
            packageRoot.appendingPathComponent(relativePath)
        ]
        if let url = candidates.first(where: { FileManager.default.fileExists(atPath: $0.path) }) {
            return url
        }
        return candidates[0]
    }
}
