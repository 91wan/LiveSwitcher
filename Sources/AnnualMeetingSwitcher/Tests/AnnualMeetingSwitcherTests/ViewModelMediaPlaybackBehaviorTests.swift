import XCTest
@testable import LiveSwitcher

@MainActor
final class ViewModelMediaPlaybackBehaviorTests: XCTestCase {
    func testPlaybackEndedStillDispatchesRuntimeMediaReachedEnd() {
        let viewModel = makeViewModel()
        let item = mediaProgram()
        viewModel.addProgramItem(item)
        viewModel.switchToProgram(item)
        viewModel.runtime.replaceStateForFacadeSync(viewModel.runtime.state, clearActionLog: true)

        viewModel.handlePlaybackEnded()

        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "mediaReachedEnd" })
    }

    func testPlaybackEndedStillRecordsSupportEvent() {
        let viewModel = makeViewModel()
        let item = mediaProgram()
        viewModel.addProgramItem(item)
        viewModel.switchToProgram(item)

        viewModel.handlePlaybackEnded()

        XCTAssertTrue(viewModel.supportEvents.contains { $0.kind == .playbackReachedEnd })
    }

    func testPlaybackEndedStillDoesNotClearProgramDuringPanic() {
        let viewModel = makeViewModel()
        let item = mediaProgram()
        viewModel.addProgramItem(item)
        viewModel.switchToProgram(item)
        viewModel.applyPanicProjectionFromRuntime(isActive: true, snapshot: nil)

        viewModel.handlePlaybackEnded()

        XCTAssertEqual(viewModel.currentProgramItem?.id, item.id)
    }

    func testPlaybackEndedStillAutoPlaysNextVideoWhenEnabled() {
        let viewModel = makeViewModel()
        let first = mediaProgram(title: "First")
        let second = mediaProgram(title: "Second")
        viewModel.addProgramItems([first, second])
        viewModel.switchToProgram(first)
        viewModel.autoPlayNextVideoOnEnd = true

        viewModel.handlePlaybackEnded()

        XCTAssertEqual(viewModel.currentProgramItem?.id, second.id)
    }

    func testPlaybackEndedStillClearsHTMLAndCurrentProgramWhenNoNextVideo() {
        let viewModel = makeViewModel()
        let item = mediaProgram()
        let htmlURL = temporaryURL(ext: "html")
        viewModel.addProgramItem(item)
        viewModel.switchToProgram(item)
        viewModel.currentHTMLURL = htmlURL

        viewModel.handlePlaybackEnded()

        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertNil(viewModel.currentProgramItem)
    }

    func testOpenHTMLInOutputWindowStillSetsCurrentHTMLURL() {
        let viewModel = makeViewModel()
        let htmlURL = temporaryURL(ext: "html")

        viewModel.openHTMLInOutputWindow(url: htmlURL)

        XCTAssertEqual(viewModel.currentHTMLURL, htmlURL)
    }

    func testEndHTMLPresentationStillClearsHTMLAndCurrentProgram() {
        let viewModel = makeViewModel()
        let item = htmlProgram()
        viewModel.applyCurrentProgramProjectionFromRuntime(item, switchedAt: Date())
        viewModel.currentHTMLURL = item.sourceURL

        viewModel.endHTMLPresentation()

        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertNil(viewModel.currentProgramItem)
    }

    func testCurrentProgramIsMediaSourceStillReflectsCurrentProgram() {
        let viewModel = makeViewModel()
        viewModel.applyCurrentProgramProjectionFromRuntime(mediaProgram(), switchedAt: Date())
        XCTAssertTrue(viewModel.currentProgramIsMediaSource)

        viewModel.applyCurrentProgramProjectionFromRuntime(htmlProgram(), switchedAt: Date())
        XCTAssertFalse(viewModel.currentProgramIsMediaSource)
    }

    func testPlayerCoordinatorStillDispatchesMediaPlaybackChangedCallback() {
        let source = try? repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+MediaPlayback.swift")

        XCTAssertTrue(source?.contains(".mediaPlaybackChanged(isPlaying: isPlaying, generation: $0)") == true)
        XCTAssertTrue(source?.contains("avCoordinator.onPlaybackEnded") == true)
        XCTAssertTrue(source?.contains("handlePlaybackEnded()") == true)
    }

    private func makeViewModel() -> SwitcherViewModel {
        SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)
    }

    private func mediaProgram(title: String = "Video") -> ProgramItem {
        ProgramItem(title: title, subtitle: "VIDEO", sourceURL: temporaryURL(ext: "mp4"))
    }

    private func htmlProgram() -> ProgramItem {
        ProgramItem(title: "HTML", subtitle: "HTML", sourceURL: temporaryURL(ext: "html"))
    }

    private func temporaryURL(ext: String) -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(ext)
        try? Data("fixture".utf8).write(to: url)
        return url
    }
}
