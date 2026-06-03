import XCTest
@testable import LiveSwitcher

@MainActor
final class BGMPausedRoutingTests: XCTestCase {
    func testPausedSelectedBGMAppliesZeroBGMOutput() {
        let viewModel = SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            userDefaults: isolatedDefaults()
        )
        let item = BGMItem(
            title: "Paused Track",
            url: URL(fileURLWithPath: "/tmp/paused-track.mp3"),
            category: .warmUp
        )
        viewModel.masterVolume = 0.5
        viewModel.bgmVolume = 0.5
        viewModel.audioStrategy = .mixed
        viewModel.currentBGMItem = item
        viewModel.isBGMPlaying = false
        viewModel.bgmFallbackPlayer.volume = 0.25

        viewModel.applyAudioRouting()

        XCTAssertEqual(viewModel.bgmFallbackPlayer.volume, 0, accuracy: 0.0001)
    }

    func testAudioRoutingUsesPlaybackAwareBGMTarget() throws {
        let source = try String(contentsOf: sourceURL("ViewModel.swift"), encoding: .utf8)
        let body = try XCTUnwrap(source.functionBody(named: "applyAudioRouting"))

        XCTAssertTrue(source.contains("appliedBGMOutputVolume"))
        XCTAssertTrue(body.contains("appliedBGMOutputVolume()"))
        XCTAssertFalse(body.contains("let effectiveBGM = effectiveBGMOutputVolume()"))
    }

    func testPausingBGMUsesSingleRoutingFadeBeforePausingPlayers() throws {
        let source = try String(contentsOf: sourceURL("ViewModel.swift"), encoding: .utf8)
        let body = try XCTUnwrap(source.functionBody(named: "toggleBGM"))

        XCTAssertTrue(body.contains("dispatchRuntimeFacadeAction(.operatorStoppedBGM)"))
        XCTAssertTrue(source.contains("applyAudioRoutingForRuntimeChange"))
        XCTAssertFalse(body.contains("fadeBGMPlayerVolume(to: 0, duration: fadeDur)"))
        XCTAssertFalse(body.contains("fadeBGMFallbackVolume(to: 0, duration: fadeDur)"))
        XCTAssertFalse(body.contains("fadeMediaVolume(to: effectiveMediaOutputVolume(), duration: fadeDur)"))
    }

    private func isolatedDefaults() -> UserDefaults {
        let suiteName = "LiveSwitcher.BGMPausedRoutingTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
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
