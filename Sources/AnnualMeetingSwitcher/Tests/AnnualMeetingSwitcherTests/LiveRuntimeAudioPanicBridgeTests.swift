import XCTest
@testable import LiveSwitcher

@MainActor
final class LiveRuntimeAudioPanicBridgeTests: XCTestCase {
    func testAudioVolumeActionProducesFaderRoutingEffect() {
        let mutation = LiveRuntimeReducer.reduce(
            state: LiveRuntimeState(),
            action: .operatorChangedMasterVolume(0.82),
            environment: LiveRuntimeEnvironment(now: Date(timeIntervalSince1970: 100))
        )

        XCTAssertEqual(mutation.state.audio.masterVolume, 0.82, accuracy: 0.0001)
        XCTAssertTrue(mutation.effects.contains(.applyAudioRouting(reason: .operatorFaderChanged)))
    }

    func testAudioStrategyActionProducesStrategyRoutingAndPersistenceEffects() {
        let mutation = LiveRuntimeReducer.reduce(
            state: LiveRuntimeState(),
            action: .operatorSelectedAudioStrategy(.bgmOnly),
            environment: LiveRuntimeEnvironment(now: Date(timeIntervalSince1970: 100))
        )

        XCTAssertEqual(mutation.state.audio.strategy, AudioStrategy.bgmOnly)
        XCTAssertTrue(mutation.effects.contains(.applyAudioRouting(reason: .strategyChanged)))
        XCTAssertTrue(mutation.effects.contains(.savePersistentState))
    }

    func testSpeakerActionProducesSpeakerRoutingAndPersistenceEffects() {
        let mutation = LiveRuntimeReducer.reduce(
            state: LiveRuntimeState(),
            action: .operatorSetSpeakerMode(true),
            environment: LiveRuntimeEnvironment(now: Date(timeIntervalSince1970: 100))
        )

        XCTAssertTrue(mutation.state.audio.isSpeakerMode)
        XCTAssertTrue(mutation.effects.contains(.applyAudioRouting(reason: .speakerChanged)))
        XCTAssertTrue(mutation.effects.contains(.savePersistentState))
    }

    func testLimiterActionsProduceLimiterOrFaderRoutingEffects() {
        let muted = LiveRuntimeReducer.reduce(
            state: LiveRuntimeState(),
            action: .operatorChangedMediaMute(true),
            environment: LiveRuntimeEnvironment(now: Date(timeIntervalSince1970: 100))
        )
        let takeover = LiveRuntimeReducer.reduce(
            state: LiveRuntimeState(),
            action: .operatorChangedBGMTakeover(true),
            environment: LiveRuntimeEnvironment(now: Date(timeIntervalSince1970: 100))
        )

        XCTAssertTrue(muted.state.audio.isMediaMuted)
        XCTAssertTrue(muted.effects.contains(.applyAudioRouting(reason: .operatorFaderChanged)))
        XCTAssertTrue(takeover.state.audio.isBGMTakeoverActive)
        XCTAssertTrue(takeover.effects.contains(.applyAudioRouting(reason: .limiterChanged)))
    }

    func testPanicActionProducesPanicRoutingEffect() {
        var state = LiveRuntimeState()
        state.media.isPlaying = true
        state.bgm.isPlaying = true
        state.bgm.currentID = state.bgm.items.first?.id

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .operatorSetPanic(true),
            environment: LiveRuntimeEnvironment(now: Date(timeIntervalSince1970: 100))
        )

        XCTAssertTrue(mutation.state.panic.isActive)
        XCTAssertEqual(mutation.state.audio.effectiveMedia, 0)
        XCTAssertEqual(mutation.state.audio.effectiveBGM, 0)
        XCTAssertTrue(mutation.effects.contains(.applyAudioRouting(reason: .panicChanged)))
    }

    func testViewModelAudioSettersDispatchRuntimeActionsAndKeepLegacyTransition() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)

        viewModel.masterVolume = 0.73

        XCTAssertEqual(viewModel.runtime.state.audio.masterVolume, 0.73, accuracy: 0.0001)
        XCTAssertEqual(viewModel.runtime.actionLog.last?.actionName, "operatorChangedMasterVolume")
        XCTAssertEqual(viewModel.lastAudioRoutingTransition?.reason, .operatorFaderChanged)
    }

    func testViewModelSpeakerToggleDispatchesRuntimeActionAndKeepsLegacyTransition() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)

        viewModel.toggleSpeakerMode()

        XCTAssertTrue(viewModel.runtime.state.audio.isSpeakerMode)
        XCTAssertEqual(viewModel.runtime.actionLog.last?.actionName, "operatorSetSpeakerMode")
        XCTAssertEqual(viewModel.lastAudioRoutingTransition?.reason, .speakerChanged)
    }

    func testViewModelMuteAndTakeoverSettersDispatchRuntimeActions() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)

        viewModel.isMediaAudioMuted = true
        XCTAssertTrue(viewModel.runtime.state.audio.isMediaMuted)
        XCTAssertEqual(viewModel.runtime.actionLog.last?.actionName, "operatorChangedMediaMute")
        XCTAssertEqual(viewModel.lastAudioRoutingTransition?.reason, .operatorFaderChanged)

        viewModel.isBGMAudioTakeoverActive = true
        XCTAssertTrue(viewModel.runtime.state.audio.isBGMTakeoverActive)
        XCTAssertEqual(viewModel.runtime.actionLog.last?.actionName, "operatorChangedBGMTakeover")
        XCTAssertEqual(viewModel.lastAudioRoutingTransition?.reason, .limiterChanged)
    }

    func testViewModelPanicToggleDispatchesRuntimeActionAndKeepsLegacyTransition() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)

        viewModel.togglePanicMode()

        XCTAssertTrue(viewModel.runtime.state.panic.isActive)
        XCTAssertEqual(viewModel.runtime.actionLog.last?.actionName, "operatorSetPanic")
        XCTAssertEqual(viewModel.lastAudioRoutingTransition?.reason, .panicChanged)
    }
}
