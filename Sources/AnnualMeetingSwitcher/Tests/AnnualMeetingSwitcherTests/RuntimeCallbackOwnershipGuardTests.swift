import XCTest
@testable import LiveSwitcher

@MainActor
final class RuntimeCallbackOwnershipGuardTests: XCTestCase {
    func testMediaCallbacksDoNotDispatchAudioInputs() {
        for action in mediaCallbackActions {
            XCTAssertFalse(LiveRuntimeFacadeSyncPolicy.options(for: action).dispatchAudioInputsChanged, action.redactedName)
        }
    }

    func testBGMCallbacksDoNotDispatchAudioInputs() {
        for action in bgmCallbackActions {
            XCTAssertFalse(LiveRuntimeFacadeSyncPolicy.options(for: action).dispatchAudioInputsChanged, action.redactedName)
        }
    }

    func testFacadeCurrentProgramChangedDoesNotDispatchAudioInputs() {
        XCTAssertFalse(LiveRuntimeFacadeSyncPolicy.options(for: .facadeCurrentProgramChanged(UUID())).dispatchAudioInputsChanged)
    }

    func testFacadeCurrentProgramChangedStillSyncsCurrentProgramFacade() {
        XCTAssertTrue(LiveRuntimeFacadeSyncPolicy.options(for: .facadeCurrentProgramChanged(UUID())).syncCurrentProgram)
    }

    func testBGMCallbacksStillSyncBGMFacade() {
        for action in bgmCallbackActions {
            XCTAssertTrue(LiveRuntimeFacadeSyncPolicy.options(for: action).syncBGM, action.redactedName)
        }
    }

    func testProductionViewModelRuntimeBridgeModeRemainsPanicOwned() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)

        XCTAssertEqual(viewModel.runtimeBridgeMode, .panicOwned)
    }

    func testProductionConnectedPortsRemainPanicOwnedSet() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)

        XCTAssertEqual(
            viewModel.runtimeConnectedPortKinds,
            [.media, .bgm, .bgmTimer, .panicDelay, .projection, .ppt, .automationNotice, .support, .automation, .presentationQuery, .programActivation, .audioRouting, .imageAssets, .persistence]
        )
    }

    func testNoCallbackBridgeModeAdded() {
        let forbidden = ["callbackOwned", "mediaCallbackOwned", "bgmCallbackOwned"]

        for mode in forbidden {
            XCTAssertFalse(LiveRuntimeBridgeMode.allCases.contains { $0.rawValue == mode }, mode)
        }
    }

    func testNoCallbackDomainAdded() {
        let forbidden = ["callback", "mediaCallback", "bgmCallback"]

        for domain in forbidden {
            XCTAssertFalse(LiveRuntimeDomain.allCases.contains { $0.rawValue == domain }, domain)
        }
    }

    func testNoCallbackPortAdded() {
        let forbidden = ["callback", "mediaCallback", "bgmCallback"]

        for port in forbidden {
            XCTAssertFalse(LiveRuntimeEffectPortKind.allCases.contains { $0.rawValue == port }, port)
        }
    }

    func testViewModelCallbackWiringDoesNotCheckRuntimeOwnership() throws {
        let mediaSource = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+MediaPlayback.swift")
        let bgmSource = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+BGMRuntimePlayback.swift")
        let bgmControlsSource = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+BGMControls.swift")
        let combined = mediaSource + "\n" + bgmSource + "\n" + bgmControlsSource

        XCTAssertFalse(combined.contains("bridgeMode"))
        XCTAssertFalse(combined.contains("owns(.media"))
        XCTAssertFalse(combined.contains("owns(.bgm"))
    }

    func testViewModelMediaCallbackWiringStillDispatchesRuntimeCallbacks() throws {
        let mediaSource = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+MediaPlayback.swift")

        XCTAssertTrue(mediaSource.contains("dispatchRuntimeMediaCallback"))
        XCTAssertTrue(mediaSource.contains(".mediaPlaybackChanged(isPlaying: isPlaying, generation: $0)"))
        XCTAssertTrue(mediaSource.contains(".mediaReachedEnd(generation: $0)"))
    }

    func testViewModelBGMCallbackWiringStillDispatchesRuntimeCallbacks() throws {
        let bgmRuntimeSource = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+BGMRuntimePlayback.swift")
        let bgmControlsSource = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+BGMControls.swift")

        XCTAssertTrue(bgmRuntimeSource.contains(".bgmProgressUpdated(time: currentTime, duration: duration, generation: generation)"))
        XCTAssertTrue(bgmRuntimeSource.contains(".bgmProgressUpdated(time: fallbackTime, duration: fallbackDuration, generation: generation)"))
        XCTAssertTrue(bgmControlsSource.contains(".bgmReachedEnd(generation: $0)"))
        XCTAssertTrue(bgmControlsSource.contains(".bgmFailed(reason: \"playbackFailed\", generation: $0)"))
    }

    private var mediaCallbackActions: [LiveRuntimeAction] {
        [
            .mediaLoaded(url: URL(fileURLWithPath: "/tmp/video.mp4"), generation: 1),
            .mediaPlaybackChanged(isPlaying: true, generation: 1),
            .mediaReachedEnd(generation: 1),
            .mediaSeekCompleted(time: 1, generation: 1)
        ]
    }

    private var bgmCallbackActions: [LiveRuntimeAction] {
        [
            .bgmPlaybackChanged(isPlaying: true, generation: 1),
            .bgmReachedEnd(generation: 1),
            .bgmFailed(reason: "decode", generation: 1),
            .bgmProgressUpdated(time: 1, duration: 10, generation: 1)
        ]
    }
}
