import XCTest

final class ViewModelMediaPlaybackExtractionTests: XCTestCase {
    func testMediaPlaybackMethodsAreNotDeclaredInMainViewModel() throws {
        let source = try viewModelSource()

        [
            "func setupPlayerCoordinator(",
            "func openHTMLInOutputWindow(",
            "func endHTMLPresentation(",
            "func handlePlaybackEnded(",
            "func autoPlayNextVideoIfPossible(",
            "var currentProgramIsMediaSource"
        ].forEach { snippet in
            XCTAssertFalse(source.contains(snippet), snippet)
        }
    }

    func testMediaPlaybackMethodsLiveInMediaPlaybackExtension() throws {
        let source = try mediaPlaybackSource()

        [
            "func setupPlayerCoordinator(",
            "func openHTMLInOutputWindow(",
            "func endHTMLPresentation(",
            "func handlePlaybackEnded(",
            "func autoPlayNextVideoIfPossible(",
            "var currentProgramIsMediaSource"
        ].forEach { snippet in
            XCTAssertTrue(source.contains(snippet), snippet)
        }
    }

    func testPlayerCoordinatorSetupIsNotDeclaredInMainViewModel() throws {
        XCTAssertFalse(try viewModelSource().contains("func setupPlayerCoordinator("))
    }

    func testPlaybackEndedHandlingIsNotDeclaredInMainViewModel() throws {
        let source = try viewModelSource()

        XCTAssertFalse(source.contains("func handlePlaybackEnded("))
        XCTAssertFalse(source.contains("func autoPlayNextVideoIfPossible("))
    }

    func testHTMLPresentationMethodsAreNotDeclaredInMainViewModel() throws {
        let source = try viewModelSource()

        XCTAssertFalse(source.contains("func openHTMLInOutputWindow("))
        XCTAssertFalse(source.contains("func endHTMLPresentation("))
    }

    private func viewModelSource() throws -> String {
        try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel.swift")
    }

    private func mediaPlaybackSource() throws -> String {
        try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+MediaPlayback.swift")
    }
}
