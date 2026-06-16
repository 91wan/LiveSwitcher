import XCTest
@testable import LiveSwitcher

@MainActor
final class RuntimeEffectWiringTests: XCTestCase {
    func testProductionConnectedPortsIncludePanicDelaySet() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)

        XCTAssertEqual(
            viewModel.runtimeConnectedPortKinds,
            [.media, .bgm, .bgmTimer, .panicDelay, .projection, .ppt, .automation, .automationNotice, .support, .presentationQuery, .programActivation, .audioRouting, .imageAssets, .persistence]
        )
    }

    func testProductionViewModelRuntimeBridgeModeIsPanicOwned() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)

        XCTAssertEqual(viewModel.runtimeBridgeMode, .panicOwned)
    }

    func testNoProductionPortLostDuringBridgeSlimming() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)
        let expected: Set<LiveRuntimeEffectPortKind> = [.media, .bgm, .bgmTimer, .panicDelay, .projection, .ppt, .automation, .automationNotice, .support, .presentationQuery, .programActivation, .audioRouting, .imageAssets, .persistence]

        XCTAssertEqual(Set(viewModel.runtimeConnectedPortKinds), expected)
        XCTAssertEqual(viewModel.runtimeConnectedPortKinds.count, expected.count)
    }

    func testRuntimeRecordedEffectsStillRedactAutomationScripts() {
        let runtime = LiveRuntimeStore(
            effectRunner: .recording(),
            environment: .productionAutomationCommandOwning(now: Date(timeIntervalSince1970: 100))
        )
        let script = "tell application \"Keynote\" to open POSIX file \"/Users/operator/private-show.key\""

        runtime.dispatch(.automationScriptRequested(script: script, action: "keynote.open.present"))

        XCTAssertEqual(runtime.recordedEffects, [.runAppleScript(script: "<redacted>", action: "keynote.open.present")])
        XCTAssertFalse(String(describing: runtime.recordedEffects).localizedStandardContains("private-show.key"))
    }

    func testSupportEventRecordedStillDoesNotPolluteActionLog() {
        let runtime = LiveRuntimeStore(
            effectRunner: .recording(),
            environment: LiveRuntimeEnvironment(bridgeMode: .supportOwned)
        )
        let event = LiveSupportEvent(
            timestamp: Date(timeIntervalSince1970: 100),
            kind: .projectionStarted,
            detail: "source=runtime-effect-wiring"
        )

        runtime.dispatch(.supportEventRecorded(event))

        XCTAssertFalse(runtime.actionLog.contains { $0.actionName == "supportEventRecorded" })
    }

    func testProductionRuntimeWiresPPTProjectionMediaBGMAndAudioPorts() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)

        XCTAssertTrue(viewModel.runtimeConnectedPortKinds.contains(.ppt))
        XCTAssertTrue(viewModel.runtimeConnectedPortKinds.contains(.projection))
        XCTAssertTrue(viewModel.runtimeConnectedPortKinds.contains(.media))
        XCTAssertTrue(viewModel.runtimeConnectedPortKinds.contains(.bgm))
        XCTAssertTrue(viewModel.runtimeConnectedPortKinds.contains(.audioRouting))
    }

    func testProductionRuntimeWiresBGMTimerPort() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)

        XCTAssertTrue(viewModel.runtimeConnectedPortKinds.contains(.bgmTimer))
    }

    func testProductionRuntimeWiresPanicDelayPort() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)

        XCTAssertTrue(viewModel.runtimeConnectedPortKinds.contains(.panicDelay))
    }

    func testProductionRuntimeKeepsBGMFadeOutBehindBGMPort() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)

        XCTAssertTrue(viewModel.runtimeConnectedPortKinds.contains(.bgm))
        XCTAssertTrue(viewModel.runtimeConnectedPortKinds.contains(.audioRouting))
    }

    func testProductionRuntimeWiresSupportAutomationNoticeAutomationCommandAndPresentationQueryPorts() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)
        let connected = viewModel.runtimeConnectedPortKinds

        XCTAssertTrue(connected.contains(.automationNotice))
        XCTAssertTrue(connected.contains(.support))
        XCTAssertTrue(connected.contains(.automation))
        XCTAssertTrue(connected.contains(.presentationQuery))
        XCTAssertTrue(connected.contains(.programActivation))
    }

    func testProductionRuntimeStillWiresImageAssetsPort() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)

        XCTAssertTrue(viewModel.runtimeConnectedPortKinds.contains(.imageAssets))
    }

    func testProductionRuntimeStillWiresPersistencePort() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)

        XCTAssertTrue(viewModel.runtimeConnectedPortKinds.contains(.persistence))
    }

    func testNoPreferencesPortAdded() {
        XCTAssertFalse(LiveRuntimeEffectPortKind.allCases.contains { $0.rawValue == "preferences" })
        XCTAssertFalse(LiveRuntimeEffectPortKind.allCases.contains { $0.rawValue == "preferencesOwned" })
    }

    func testNoCallbackPortAdded() {
        for rawValue in ["callback", "mediaCallback", "bgmCallback"] {
            XCTAssertFalse(LiveRuntimeEffectPortKind.allCases.contains { $0.rawValue == rawValue }, rawValue)
        }
    }

    func testNoProgramQueueReducerPortAdded() {
        for rawValue in ["programQueueReducer", "programCompatibility"] {
            XCTAssertFalse(LiveRuntimeEffectPortKind.allCases.contains { $0.rawValue == rawValue }, rawValue)
        }
    }

    func testNoPresentationQueryReducerPortAdded() {
        for rawValue in ["presentationQueryReducer", "presentationResult"] {
            XCTAssertFalse(LiveRuntimeEffectPortKind.allCases.contains { $0.rawValue == rawValue }, rawValue)
        }
    }

    func testNoProgramActivationReducerPortAdded() {
        for rawValue in ["programActivationReducer", "programActivationSideEffects"] {
            XCTAssertFalse(LiveRuntimeEffectPortKind.allCases.contains { $0.rawValue == rawValue }, rawValue)
        }
    }

    func testProductionRuntimeStillWiresAutomationCommandPort() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)

        XCTAssertTrue(viewModel.runtimeConnectedPortKinds.contains(.automation))
    }

    func testProductionRuntimeStillDoesNotWireAutomationQueryPort() {
        XCTAssertFalse(LiveRuntimeEffectPortKind.allCases.contains { $0.rawValue == "automationQuery" })
    }

    func testPresentationQueryMigrationKeepsPriorRuntimePortsConnected() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)
        let connected = viewModel.runtimeConnectedPortKinds

        XCTAssertTrue(connected.contains(.projection))
        XCTAssertTrue(connected.contains(.ppt))
        XCTAssertTrue(connected.contains(.support))
        XCTAssertTrue(connected.contains(.automation))
        XCTAssertTrue(connected.contains(.presentationQuery))
    }

    func testCustomEffectRunnerReportsInjectedPorts() {
        let runner = LiveRuntimeEffectRunner(
            recordsOnly: false,
            audioRouting: RuntimeEffectWiringAudioPort(),
            persistence: RuntimeEffectWiringPersistencePort()
        )

        XCTAssertEqual(runner.connectedPortKinds, [.audioRouting, .persistence])
    }

    func testPersistencePortDoesNotImplyBGMOwningBridgeMode() {
        let runner = LiveRuntimeEffectRunner(
            recordsOnly: false,
            persistence: RuntimeEffectWiringPersistencePort()
        )
        let store = LiveRuntimeStore(
            effectRunner: runner,
            environment: .productionAudioOwned()
        )

        XCTAssertEqual(store.connectedPortKinds, [.persistence])
        XCTAssertEqual(store.bridgeMode, .audioOwned)
    }
}

private final class RuntimeEffectWiringAudioPort: AudioRoutingPort {
    func apply(reason: AudioRoutingRuntimeChangeReason, state: LiveRuntimeState) {}
}

private final class RuntimeEffectWiringPersistencePort: PersistencePort {
    func save() {}
    func saveConsoleMode(_ mode: ConsoleMode) {}
    func saveThemeOverride(_ theme: ThemeOverride) {}
    func saveAudioStrategy(_ strategy: AudioStrategy) {}
    func saveSpeakerMode(_ isEnabled: Bool) {}
    func saveBGMPlayMode(_ playMode: BGMPlayMode) {}
    func saveAutoPlayNextVideoOnEnd(_ isEnabled: Bool) {}
    func saveAutoAdvanceAtScheduledTime(_ isEnabled: Bool) {}
    func saveShowAgendaTimeline(_ isEnabled: Bool) {}
    func saveCornerLogoPosition(_ position: CornerLogoPosition) {}
}
