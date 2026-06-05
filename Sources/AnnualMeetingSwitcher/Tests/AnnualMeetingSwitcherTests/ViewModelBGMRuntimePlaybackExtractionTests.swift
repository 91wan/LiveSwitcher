import XCTest
@testable import LiveSwitcher

@MainActor
final class ViewModelBGMRuntimePlaybackExtractionTests: XCTestCase {
    func testBGMRuntimePlaybackMethodsAreNotDeclaredInMainViewModel() throws {
        let source = try viewModelSource()

        for snippet in [
            "func prepareRuntimeBGM(",
            "func playRuntimeBGM(",
            "func pauseRuntimeBGM(",
            "func stopRuntimeBGM(",
            "func setRuntimeBGMVolume(",
            "func seekRuntimeBGMToBeginning(",
            "func seekRuntimeBGM(toProgress",
            "func setRuntimeBGMPlayMode("
        ] {
            XCTAssertFalse(source.contains(snippet), snippet)
        }
    }

    func testBGMRuntimePlaybackMethodsLiveInBGMRuntimePlaybackExtension() throws {
        let source = try XCTUnwrap(bgmRuntimePlaybackExtensionSource())

        XCTAssertTrue(source.contains("extension SwitcherViewModel"))
        for snippet in [
            "func prepareRuntimeBGM(",
            "func playRuntimeBGM(",
            "func pauseRuntimeBGM(",
            "func stopRuntimeBGM(",
            "func setRuntimeBGMVolume(",
            "func seekRuntimeBGMToBeginning(",
            "func seekRuntimeBGM(toProgress",
            "func setRuntimeBGMPlayMode("
        ] {
            XCTAssertTrue(source.contains(snippet), snippet)
        }
    }

    func testBGMRuntimeFadeHelpersAreNotDeclaredInMainViewModel() throws {
        let source = try viewModelSource()

        for snippet in [
            "func fadeCurrentBGMFallbackVolume(",
            "func fadeCurrentBGMPlayerVolume(",
            "func fadeRetiredBGMPlayerVolume(",
            "func releaseRetiredBGMPlayerAfterFade(",
            "func releaseBGMFallbackAfterFade("
        ] {
            XCTAssertFalse(source.contains(snippet), snippet)
        }
    }

    func testBGMRuntimeTimerMethodsAreNotDeclaredInMainViewModel() throws {
        let source = try viewModelSource()

        for snippet in [
            "func startBGMTimer(",
            "func stopBGMTimer(",
            "func stopActiveBGMTimer(",
            "func updateBGMProgress("
        ] {
            XCTAssertFalse(source.contains(snippet), snippet)
        }
    }

    func testBGMFallbackObserverMethodsAreNotDeclaredInMainViewModel() throws {
        let source = try viewModelSource()

        for snippet in [
            "func installBGMFallbackEndObserver(",
            "func removeBGMFallbackEndObserver("
        ] {
            XCTAssertFalse(source.contains(snippet), snippet)
        }
    }

    private func viewModelSource() throws -> String {
        try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel.swift")
    }

    private func bgmRuntimePlaybackExtensionSource() throws -> String? {
        try optionalRepositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+BGMRuntimePlayback.swift")
    }
}
