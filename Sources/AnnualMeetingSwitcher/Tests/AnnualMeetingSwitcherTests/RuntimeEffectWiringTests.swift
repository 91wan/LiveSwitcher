import XCTest
@testable import LiveSwitcher

@MainActor
final class RuntimeEffectWiringTests: XCTestCase {
    func testProductionConnectedPortsRemainAutomationCommandOwnedSet() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)

        XCTAssertEqual(
            viewModel.runtimeConnectedPortKinds,
            [.media, .bgm, .bgmTimer, .projection, .ppt, .automation, .automationNotice, .support, .audioRouting, .imageAssets, .persistence]
        )
    }

    func testProductionViewModelRuntimeBridgeModeRemainsAutomationCommandOwned() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)

        XCTAssertEqual(viewModel.runtimeBridgeMode, .automationCommandOwned)
    }

    func testNoProductionPortLostDuringBridgeSlimming() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)
        let expected: Set<LiveRuntimeEffectPortKind> = [.media, .bgm, .bgmTimer, .projection, .ppt, .automation, .automationNotice, .support, .audioRouting, .imageAssets, .persistence]

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

    func testProductionRuntimeKeepsBGMFadeOutBehindBGMPort() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)

        XCTAssertTrue(viewModel.runtimeConnectedPortKinds.contains(.bgm))
        XCTAssertTrue(viewModel.runtimeConnectedPortKinds.contains(.audioRouting))
    }

    func testProductionRuntimeWiresSupportAutomationNoticeAndAutomationCommandPort() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)
        let connected = viewModel.runtimeConnectedPortKinds

        XCTAssertTrue(connected.contains(.automationNotice))
        XCTAssertTrue(connected.contains(.support))
        XCTAssertTrue(connected.contains(.automation))
    }

    func testAutomationCommandMigrationKeepsPriorRuntimePortsConnected() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)
        let connected = viewModel.runtimeConnectedPortKinds

        XCTAssertTrue(connected.contains(.projection))
        XCTAssertTrue(connected.contains(.ppt))
        XCTAssertTrue(connected.contains(.support))
        XCTAssertTrue(connected.contains(.automation))
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
}
