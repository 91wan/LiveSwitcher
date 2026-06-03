import AppKit
import XCTest
@testable import LiveSwitcher

@MainActor
final class OutputProjectionConvergenceTests: XCTestCase {
    func testOutputDisplayStateIgnoresHighFrequencyPlaybackProgress() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)
        viewModel.currentHTMLURL = URL(fileURLWithPath: "/tmp/current.html")
        viewModel.isCountdownActive = true
        viewModel.isTickerActive = true
        viewModel.isLowerThirdVisible = true
        viewModel.lowerThirdName = "Presenter"
        viewModel.lowerThirdTitle = "Host"

        let before = OutputDisplayState.make(from: viewModel)
        viewModel.avCoordinator.progress = 0.75
        viewModel.avCoordinator.currentTime = 42
        viewModel.avCoordinator.duration = 120
        let after = OutputDisplayState.make(from: viewModel)

        XCTAssertEqual(before, after)
    }

    func testSwitchingToMediaStartsMutedBeforeRuntimeFadeIn() throws {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)
        viewModel.masterVolume = 1
        viewModel.mediaVolume = 1
        viewModel.bgmVolume = 0
        viewModel.audioStrategy = .followProgram
        viewModel.avCoordinator.volume = 0.5
        let mediaURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        FileManager.default.createFile(atPath: mediaURL.path, contents: Data("stub".utf8))
        defer { try? FileManager.default.removeItem(at: mediaURL) }

        var observedVolumes: [Float] = []
        let observation = viewModel.avCoordinator.player.observe(\.volume, options: [.new]) { _, change in
            if let value = change.newValue {
                observedVolumes.append(value)
            }
        }

        let item = ProgramItem(
            title: "Opening",
            subtitle: "VIDEO",
            sourceURL: mediaURL
        )
        viewModel.switchToProgram(item)
        observation.invalidate()

        XCTAssertEqual(viewModel.currentProgramItem, item)
        XCTAssertTrue(viewModel.avCoordinator.isPlaying)
        XCTAssertTrue(observedVolumes.contains(0), "Media startup should mute before the runtime fade-in.")
        XCTAssertEqual(viewModel.lastAudioRoutingTransition?.reason, .programChanged)
        XCTAssertEqual(viewModel.lastAudioRoutingTransition?.mediaFadeDuration, viewModel.liveAudioFadeDuration)
    }

    func testExternalDisplayAvailabilityIsCachedUntilExplicitRefresh() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)
        var providerCalls = 0
        viewModel.externalScreenProvider = {
            providerCalls += 1
            return nil
        }

        XCTAssertEqual(providerCalls, 1)
        XCTAssertFalse(viewModel.hasExternalDisplay)
        XCTAssertFalse(viewModel.projectionService.hasExternalDisplay)
        XCTAssertFalse(viewModel.livePreflightSnapshot.hasExternalDisplay)
        XCTAssertEqual(providerCalls, 1)

        viewModel.refreshExternalDisplayAvailability()
        XCTAssertEqual(providerCalls, 2)
    }
}
