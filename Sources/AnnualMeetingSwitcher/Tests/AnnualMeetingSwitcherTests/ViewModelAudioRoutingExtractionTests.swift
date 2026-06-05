import XCTest
@testable import LiveSwitcher

@MainActor
final class ViewModelAudioRoutingExtractionTests: XCTestCase {
    func testAudioRoutingMethodsAreNotDeclaredInMainViewModel() throws {
        let source = try viewModelSource()

        for snippet in [
            "func applyAudioRouting(",
            "func applyAudioRoutingForRuntimeChange(",
            "func applyCurrentRuntimeAudioRouting(",
            "func effectiveMediaOutputVolume(",
            "func effectiveBGMOutputVolume("
        ] {
            XCTAssertFalse(source.contains(snippet), snippet)
        }
    }

    func testAudioRoutingMethodsLiveInAudioRoutingExtension() throws {
        let source = try XCTUnwrap(audioRoutingExtensionSource())

        XCTAssertTrue(source.contains("extension SwitcherViewModel"))
        for snippet in [
            "func applyAudioRouting(",
            "func applyAudioRoutingForRuntimeChange(",
            "func applyCurrentRuntimeAudioRouting(",
            "func effectiveMediaOutputVolume(",
            "func effectiveBGMOutputVolume(",
            "func liveMasterMeterRealtimeDB(",
            "func liveMasterMeterFallbackVolume("
        ] {
            XCTAssertTrue(source.contains(snippet), snippet)
        }
    }

    func testLiveMasterMeterCandidateIsNotDeclaredInMainViewModel() throws {
        let source = try viewModelSource()

        XCTAssertFalse(source.contains("private struct LiveMasterMeterCandidate"))
        XCTAssertFalse(source.contains("struct LiveMasterMeterCandidate"))
    }

    func testSystemVolumeObserverSetupIsNotDeclaredInMainViewModel() throws {
        let source = try viewModelSource()

        XCTAssertFalse(source.contains("func setupSystemVolumeObserver("))
    }

    func testMediaVolumeFadeMethodIsNotDeclaredInMainViewModel() throws {
        let source = try viewModelSource()

        XCTAssertFalse(source.contains("func fadeMediaVolume("))
    }

    private func viewModelSource() throws -> String {
        try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel.swift")
    }

    private func audioRoutingExtensionSource() throws -> String? {
        try optionalRepositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+AudioRouting.swift")
    }
}
