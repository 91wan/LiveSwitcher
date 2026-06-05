import XCTest
@testable import LiveSwitcher

@MainActor
final class ViewModelAudioRoutingBehaviorTests: XCTestCase {
    func testEffectiveMediaOutputVolumeStillReadsRuntimeState() {
        let viewModel = makeViewModel()

        viewModel.mediaVolume = 0.37

        XCTAssertEqual(viewModel.effectiveMediaOutputVolume(), viewModel.runtime.state.audio.effectiveMedia, accuracy: 0.0001)
    }

    func testEffectiveBGMOutputVolumeStillReadsRuntimeState() {
        let viewModel = makeViewModel()

        viewModel.bgmVolume = 0.42

        XCTAssertEqual(viewModel.effectiveBGMOutputVolume(), viewModel.runtime.state.audio.effectiveBGM, accuracy: 0.0001)
    }

    func testApplyCurrentRuntimeAudioRoutingStillSyncsAudioInputs() {
        let viewModel = makeViewModel()

        viewModel.masterVolume = 0.8
        viewModel.mediaVolume = 0.25

        XCTAssertEqual(viewModel.runtime.state.audio.masterVolume, 0.8, accuracy: 0.0001)
        XCTAssertEqual(viewModel.runtime.state.audio.mediaVolume, 0.25, accuracy: 0.0001)
    }

    func testApplyAudioRoutingStillFadesMediaWhenDurationProvided() {
        let viewModel = makeViewModel()

        viewModel.applyAudioRouting(mediaFadeDuration: 1.25, effectiveMedia: 0.2, effectiveBGM: 0)

        XCTAssertNotNil(viewModel.cleanupBag.mediaVolumeFadeTask)
    }

    func testApplyAudioRoutingStillFadesBGMWhenDurationProvided() {
        let viewModel = makeViewModel()
        let item = BGMItem(title: "Walk-in", url: URL(fileURLWithPath: "/tmp/\(UUID().uuidString).mp3"))
        viewModel.bgmItems = [item]
        viewModel.toggleBGM(item)

        viewModel.applyAudioRouting(bgmFadeDuration: 1.25, effectiveMedia: 0, effectiveBGM: 0.2)

        XCTAssertNotNil(viewModel.cleanupBag.bgmFallbackVolumeFadeTask)
    }

    func testSystemVolumeObserverStillRecordsSupportEvent() throws {
        let source = try XCTUnwrap(audioRoutingExtensionSource() ?? viewModelSource())

        XCTAssertTrue(source.contains("recordSupportEvent("))
        XCTAssertTrue(source.contains(".systemVolumeSynced"))
    }

    func testLiveMasterMeterFallbackStillUsesMaxRuntimeOutput() {
        let viewModel = makeViewModel()

        viewModel.masterVolume = 0.8
        viewModel.mediaVolume = 0.25
        viewModel.bgmVolume = 0.75

        XCTAssertEqual(viewModel.liveMasterMeterFallbackVolume(), max(viewModel.effectiveMediaOutputVolume(), viewModel.effectiveBGMOutputVolume()), accuracy: 0.0001)
    }

    private func makeViewModel() -> SwitcherViewModel {
        let suiteName = "ViewModelAudioRoutingBehaviorTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false, userDefaults: defaults)
    }

    private func viewModelSource() throws -> String {
        try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel.swift")
    }

    private func audioRoutingExtensionSource() throws -> String? {
        try optionalRepositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+AudioRouting.swift")
    }
}
