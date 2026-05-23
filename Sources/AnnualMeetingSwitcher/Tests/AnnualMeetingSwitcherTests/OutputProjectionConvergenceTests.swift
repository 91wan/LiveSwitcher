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

    func testSwitchingToMediaDoesNotRouteFollowProgramThroughZeroBeforePlaybackStarts() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)
        viewModel.masterVolume = 1
        viewModel.mediaVolume = 1
        viewModel.bgmVolume = 0
        viewModel.audioStrategy = .followProgram
        viewModel.avCoordinator.volume = 0.5

        var observedVolumes: [Float] = []
        let observation = viewModel.avCoordinator.player.observe(\.volume, options: [.new]) { _, change in
            if let value = change.newValue {
                observedVolumes.append(value)
            }
        }

        let item = ProgramItem(
            title: "Opening",
            subtitle: "VIDEO",
            sourceURL: URL(fileURLWithPath: "/tmp/opening.mp4")
        )
        viewModel.switchToProgram(item)
        observation.invalidate()

        XCTAssertEqual(viewModel.currentProgramItem, item)
        XCTAssertTrue(viewModel.avCoordinator.isPlaying)
        XCTAssertEqual(viewModel.avCoordinator.volume, 1, accuracy: 0.001)
        XCTAssertFalse(observedVolumes.contains(0), "Media route should not be muted during media startup.")
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
