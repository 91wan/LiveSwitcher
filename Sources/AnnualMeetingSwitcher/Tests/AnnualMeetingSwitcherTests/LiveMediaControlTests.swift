import XCTest
import AppKit
@testable import LiveSwitcher

@MainActor
final class LiveMediaControlTests: XCTestCase {
    private func makeViewModel() -> SwitcherViewModel {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)
        viewModel.externalScreenProvider = { NSScreen.main ?? NSScreen.screens.first }
        viewModel.keynotePresentationHandler = { _ in }
        viewModel.pptxOpenHandler = { _ in }
        viewModel.activeDeckPresentationHandler = {}
        viewModel.invalidDeckHandler = { _ in }
        viewModel.deckStopHandler = {}
        return viewModel
    }

    private func makeTempURL(ext: String) throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(ext)
        FileManager.default.createFile(atPath: url.path, contents: Data("stub".utf8))
        return url
    }

    func testRestartCurrentMediaRoutesThroughRuntimeAndPlays() throws {
        let viewModel = makeViewModel()
        viewModel.liveAudioFadeDuration = 1.0
        let videoURL = try makeTempURL(ext: "mp4")
        defer { try? FileManager.default.removeItem(at: videoURL) }
        var didRestartFromBeginning = false
        var didUseStandaloneSeek = false
        viewModel.programSeekToStartHandler = { didUseStandaloneSeek = true }
        viewModel.programRestartFromBeginningHandler = { onReadyToPlay in
            didRestartFromBeginning = true
            onReadyToPlay()
        }

        viewModel.switchToProgram(ProgramItem(title: "Opening", subtitle: "MP4", sourceURL: videoURL))
        viewModel.avCoordinator.pause()
        viewModel.resetLastAudioRoutingTransitionForTesting()

        viewModel.restartCurrentMediaFromBeginning()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        XCTAssertFalse(didRestartFromBeginning)
        XCTAssertFalse(didUseStandaloneSeek)
        XCTAssertTrue(viewModel.avCoordinator.isPlaying)
        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "operatorRestartedCurrentMedia" })
        XCTAssertEqual(viewModel.lastAudioRoutingTransition?.reason, .mediaPlaybackChanged)
        XCTAssertEqual(viewModel.lastAudioRoutingTransition?.mediaFadeDuration, 1.0)
        XCTAssertEqual(viewModel.lastAudioRoutingTransition?.bgmFadeDuration, 1.0)
    }

    func testRestartCurrentMediaNoopsForHTML() throws {
        let viewModel = makeViewModel()
        let htmlURL = try makeTempURL(ext: "html")
        defer { try? FileManager.default.removeItem(at: htmlURL) }
        var didSeekToBeginning = false
        viewModel.programSeekToStartHandler = { didSeekToBeginning = true }
        viewModel.currentProgramItem = ProgramItem(title: "Agenda", subtitle: "HTML", sourceURL: htmlURL)
        viewModel.resetLastAudioRoutingTransitionForTesting()

        viewModel.restartCurrentMediaFromBeginning()

        XCTAssertFalse(didSeekToBeginning)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertNil(viewModel.lastAudioRoutingTransition)
    }

    func testRestartControlModelIsEnabledOnlyForSeekableCurrentMedia() throws {
        let mediaURL = URL(fileURLWithPath: "/tmp/opening.mp4")
        let htmlURL = URL(fileURLWithPath: "/tmp/agenda.html")

        XCTAssertTrue(
            LiveMediaRestartControlModel.make(
                currentItem: ProgramItem(title: "Opening", subtitle: "MP4", sourceURL: mediaURL)
            ).isEnabled
        )
        XCTAssertFalse(
            LiveMediaRestartControlModel.make(
                currentItem: ProgramItem(title: "Agenda", subtitle: "HTML", sourceURL: htmlURL)
            ).isEnabled
        )
        let disabled = LiveMediaRestartControlModel.make(currentItem: nil)
        XCTAssertFalse(disabled.isEnabled)
        XCTAssertNil(disabled.help)
    }

    func testLiveModeContainsRestartCurrentAction() throws {
        let source = try String(contentsOf: sourceURL("Views/LiveModeView.swift"), encoding: .utf8)

        XCTAssertTrue(source.contains("restartCurrentMediaFromBeginning"))
        XCTAssertTrue(source.contains("LiveMediaRestartControlModel"))
        XCTAssertTrue(source.contains("if restart.isEnabled"))
        XCTAssertFalse(source.contains(".disabled(!restart.isEnabled)"))
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
