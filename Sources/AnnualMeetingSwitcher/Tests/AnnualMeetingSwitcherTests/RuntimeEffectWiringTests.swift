import XCTest
@testable import LiveSwitcher

@MainActor
final class RuntimeEffectWiringTests: XCTestCase {
    func testProductionConnectedPortsMatchContract() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)

        XCTAssertEqual(
            viewModel.runtimeConnectedPortKinds,
            [
                .media,
                .bgm,
                .bgmTimer,
                .panicDelay,
                .projection,
                .ppt,
                .automation,
                .automationNotice,
                .support,
                .presentationQuery,
                .programActivation,
                .audioRouting,
                .imageAssets,
                .persistence
            ]
        )
    }

    func testProductionViewModelRuntimeBridgeModeIsPanicOwned() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)

        XCTAssertEqual(viewModel.runtimeBridgeMode, .panicOwned)
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
    func saveCompanyDisplayName(_ displayName: String) {}
    func saveAudioStrategy(_ strategy: AudioStrategy) {}
    func saveSpeakerMode(_ isEnabled: Bool) {}
    func saveBGMPlayMode(_ playMode: BGMPlayMode) {}
    func saveAutoPlayNextVideoOnEnd(_ isEnabled: Bool) {}
    func saveAutoAdvanceAtScheduledTime(_ isEnabled: Bool) {}
    func saveShowAgendaTimeline(_ isEnabled: Bool) {}
    func saveCornerLogoVisible(_ isVisible: Bool) {}
    func saveCornerLogoPosition(_ position: CornerLogoPosition) {}
}
